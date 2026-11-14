require "date"
require "digest"
require "fileutils"
require "json"
require "net/http"
require "nokogiri"
require "optparse"

# Captures the 2026-27 Ivy League men's and women's basketball rosters from
# ESPN and checks each listing against the school's official roster page.
class NcaaIvy2026Capture
  ROOT = File.expand_path("..", __dir__)
  OUTPUT = File.join(ROOT, "sources/ncaa_ivy_2026")
  SEASON_YEAR = 2027 # ESPN labels college seasons by their ending year.
  SEASON_LABEL = "2026_2027"
  TEAM_COUNT = 8
  GENDERS = { "mens" => "men", "womens" => "women" }.freeze
  # Official athletics sites keyed by ESPN team ID, which ESPN shares across
  # its men's and women's feeds.
  OFFICIAL_SITES = {
    "43" => "yalebulldogs.com", "108" => "gocrimson.com", "159" => "dartmouthsports.com",
    "163" => "goprincetontigers.com", "171" => "gocolumbialions.com", "172" => "cornellbigred.com",
    "219" => "pennathletics.com", "225" => "brownbears.com"
  }.freeze
  HEADERS = {
    "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36",
    "Accept-Language" => "en-US,en;q=0.9"
  }.freeze
  BOT_WALLS = [ "_Incapsula_Resource", "cf-challenge", "challenge-platform" ].freeze

  def initialize(as_of:, refresh: false)
    @as_of = Date.iso8601(as_of).iso8601
    @refresh = refresh
    @cache = File.join(ROOT, "sources/.http-cache")
    FileUtils.mkdir_p(@cache)
  end

  def fetch(url, limit: 5)
    path = File.join(@cache, Digest::SHA256.hexdigest(url))
    return File.read(path, encoding: "UTF-8") if File.file?(path) && !@refresh

    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
      http.get(uri.request_uri, HEADERS)
    end
    if response.is_a?(Net::HTTPRedirection) && limit.positive?
      return fetch(URI.join(url, response["location"]).to_s, limit: limit - 1)
    end
    raise "HTTP #{response.code}: #{url}" unless response.is_a?(Net::HTTPSuccess)

    body = response.body.force_encoding(Encoding::UTF_8)
    File.write(path, body)
    body
  end

  def json(url)
    JSON.parse(fetch(url))
  end

  def name_key(name)
    name.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.gsub(/[^a-z0-9]+/, " ").strip
  end

  def capture(feed)
    base = "https://site.api.espn.com/apis/site/v2/sports/basketball/#{feed}-college-basketball"
    groups_url = "#{base}/groups"
    division = json(groups_url).fetch("groups").find { |group| group.fetch("name") == "NCAA Division I" }
    raise "Missing NCAA Division I group: #{groups_url}" unless division
    ivy = division.fetch("children").find { |group| group.fetch("name") == "Ivy League" }
    raise "Missing Ivy League group: #{groups_url}" unless ivy
    teams = ivy.fetch("teams")
    raise "Incomplete Ivy team list: #{teams.size}/#{TEAM_COUNT}" unless teams.size == TEAM_COUNT
    raise "Unexpected Ivy teams" unless teams.map { |team| team.fetch("id") }.sort == OFFICIAL_SITES.keys.sort

    normalized = teams.map { |team| capture_team(feed, base, team) }.sort_by { |team| team.fetch("source_id").to_i }
    document = {
      "provider" => "espn", "league" => "NCAA_D1_#{GENDERS.fetch(feed).upcase}", "gender" => GENDERS.fetch(feed),
      "conference" => "Ivy League", "season" => SEASON_LABEL, "as_of" => @as_of, "source_url" => groups_url,
      "roster_meaning" => "Complete ESPN season roster listing captured on #{@as_of}, checked against the school's official 2026-27 roster page. Not an appearance union or an NCAA eligibility certification.",
      "teams" => normalized
    }
    FileUtils.mkdir_p(OUTPUT)
    File.write(File.join(OUTPUT, "#{feed}.json"), JSON.pretty_generate(document) + "\n")
    unconfirmed = normalized.sum { |team| team.fetch("official_check").fetch("espn_only", []).size }
    puts "#{feed}: #{normalized.size} teams, #{normalized.sum { |team| team.fetch('players').size }} players, #{unconfirmed} not on an available official roster"
  end

  def capture_team(feed, base, team)
    id = team.fetch("id")
    url = "#{base}/teams/#{id}/roster?season=#{SEASON_YEAR}"
    roster = json(url)
    raise "Wrong roster season: #{url}" unless roster.fetch("season").fetch("year") == SEASON_YEAR
    raise "Wrong roster team: #{url}" unless roster.fetch("team").fetch("id") == id
    players = roster.fetch("athletes").flat_map { |entry| entry.key?("items") ? entry.fetch("items") : [ entry ] }
    raise "Empty roster: #{url}" if players.empty?

    detail = json("#{base}/teams/#{id}").fetch("team")
    raise "Team is not in the Ivy League conference: #{id}" unless detail.dig("groups", "isConference")

    players = players.map do |player|
      { "source_id" => player.fetch("id"), "first_name" => player.fetch("firstName"),
        "last_name" => player.fetch("lastName", ""), "display_name" => player.fetch("displayName"),
        "number" => player["jersey"], "position" => player.dig("position", "abbreviation"),
        "experience" => player.dig("experience", "displayValue"),
        "photo_url" => player.dig("headshot", "href") }.compact
    end.uniq { |player| player.fetch("source_id") }

    { "source_id" => id, "abbreviation" => team.fetch("abbreviation"), "name" => detail.fetch("displayName"),
      "territory" => detail.fetch("shortDisplayName"), "mascot" => detail.fetch("name"),
      "espn_location" => detail.fetch("location"), "color" => detail["color"], "alternate_color" => detail["alternateColor"],
      "url" => url, "logos" => detail.fetch("logos", []).map { |logo| logo.slice("href", "rel") },
      "official_check" => official_check(feed, id, players), "players" => players }
  end

  # Confirms ESPN's listing against the official page. Classic Sidearm pages
  # publish the roster as schema.org Person data, which allows a check in both
  # directions; newer pages only allow confirming that each name appears.
  def official_check(feed, id, players)
    url = "https://#{OFFICIAL_SITES.fetch(id)}/sports/#{feed}-basketball/roster/2026-27"
    begin
      body = fetch(url)
    rescue StandardError => error
      return { "url" => url, "status" => "unavailable", "reason" => error.message }
    end
    if BOT_WALLS.any? { |marker| body.include?(marker) } && body.size < 5_000
      return { "url" => url, "status" => "unavailable", "reason" => "Bot protection page returned; not bypassed." }
    end

    document = Nokogiri::HTML(body)
    title = document.at("title")&.text.to_s.strip
    raise "Official page is not a basketball roster: #{url}" unless title.match?(/basketball roster/i)

    page_text = name_key(document.text)
    espn_names = players.map { |player| player.fetch("display_name") }
    espn_only = espn_names.reject { |name| page_text.include?(name_key(name)) }
    official = document.css('script[type="application/ld+json"]').flat_map do |script|
      data = JSON.parse(script.text) rescue nil
      next [] unless data.is_a?(Hash) && data["item"].is_a?(Array)
      data["item"].select { |item| item["@type"] == "Person" }.map { |item| item.fetch("name").strip }
    end.uniq
    check = { "url" => url, "title" => title, "status" => official.any? ? "compared_both_directions" : "espn_names_on_page",
      "espn_only" => espn_only }
    if official.any?
      espn_keys = espn_names.map { |name| name_key(name) }
      check["official_count"] = official.size
      check["official_only"] = official.reject { |name| espn_keys.include?(name_key(name)) }
    end
    check
  end
end

if $PROGRAM_NAME == __FILE__
  options = { as_of: nil, feeds: %w[mens womens], refresh: false }
  OptionParser.new do |parser|
    parser.on("--as-of DATE") { |value| options[:as_of] = value }
    parser.on("--feeds LIST") { |value| options[:feeds] = value.split(",") }
    parser.on("--refresh") { options[:refresh] = true }
  end.parse!
  abort "Unexpected arguments" unless ARGV.empty?
  abort "Pass --as-of YYYY-MM-DD with the actual observation date" unless options[:as_of]
  capture = NcaaIvy2026Capture.new(as_of: options.fetch(:as_of), refresh: options.fetch(:refresh))
  options.fetch(:feeds).each do |feed|
    abort "Unknown feed: #{feed}" unless NcaaIvy2026Capture::GENDERS.key?(feed)
    capture.capture(feed)
  end
end
