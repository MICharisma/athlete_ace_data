require "date"
require "digest"
require "fileutils"
require "json"
require "net/http"
require "nokogiri"
require "optparse"

class Sports2026Capture
  ROOT = File.expand_path("..", __dir__)
  ESPN = {
    "nba" => [ "basketball/nba", 2027, "2026_2027", 30 ],
    "nfl" => [ "football/nfl", 2026, "2026", 32 ],
    "mls" => [ "soccer/usa.1", 2026, "2026", 30 ],
    "epl" => [ "soccer/eng.1", 2026, "2026_2027", 20 ],
    "ucl" => [ "soccer/uefa.champions", 2026, "2026_2027", 36 ]
  }.freeze

  def initialize(as_of:, refresh: false)
    @as_of = Date.iso8601(as_of).iso8601
    @refresh = refresh
    @cache = File.join(ROOT, "sources/.http-cache")
    FileUtils.mkdir_p(@cache)
  end

  def fetch(url)
    path = File.join(@cache, Digest::SHA256.hexdigest(url))
    return File.read(path) if File.file?(path) && !@refresh

    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
      http.get(uri.request_uri, "User-Agent" => "Mozilla/5.0", "Referer" => "https://www.nba.com/")
    end
    raise "HTTP #{response.code}: #{url}" unless response.is_a?(Net::HTTPSuccess)

    File.write(path, response.body)
    response.body
  end

  def json(url)
    JSON.parse(fetch(url))
  end

  def parallel(items, &block)
    queue = Queue.new
    items.each { |item| queue << item }
    errors = Queue.new
    6.times.map do
      Thread.new do
        loop do
          item = queue.pop(true)
          begin
            block.call(item)
          rescue StandardError => error
            errors << error
          end
        rescue ThreadError
          break
        end
      end
    end.each(&:join)
    raise errors.pop unless errors.empty?
  end

  def save(name, document)
    directory = File.join(ROOT, "sources/coverage_2026")
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, "#{name}.json"), JSON.pretty_generate(document) + "\n")
    puts "#{name}: #{document.fetch('teams').size} teams, #{document.fetch('teams').sum { |team| team.fetch('players').size }} player memberships"
  end

  def espn(name)
    path, year, label, count = ESPN.fetch(name)
    base = "https://site.api.espn.com/apis/site/v2/sports/#{path}"
    index_url = "#{base}/teams?limit=100&season=#{year}"
    league = json(index_url).fetch("sports").first.fetch("leagues").first
    raise "Wrong #{name} source season" unless league.fetch("season").fetch("year") == year
    teams = league.fetch("teams").map { |entry| entry.fetch("team") }
    raise "Incomplete #{name} team list: #{teams.size}/#{count}" unless teams.size == count
    parallel(teams) do |team|
      url = "#{base}/teams/#{team.fetch('id')}/roster?season=#{year}"
      roster = json(url)
      raise "Wrong #{name} roster season: #{url}" unless roster.fetch("season").fetch("year") == year
      players = roster.fetch("athletes").flat_map { |entry| entry.key?("items") ? entry.fetch("items") : [ entry ] }
      raise "Empty roster: #{url}" if players.empty?
      team["normalized"] = {
        "source_id" => team.fetch("id"), "abbreviation" => team.fetch("abbreviation"),
        "name" => team.fetch("displayName"), "territory" => team.fetch("location", team.fetch("displayName")),
        "mascot" => team.fetch("name", ""), "url" => url,
        "logos" => team.fetch("logos", []).map { |logo| logo.slice("href", "rel") },
        "players" => players.map do |player|
          { "source_id" => player.fetch("id"), "first_name" => player.fetch("firstName"),
            "last_name" => player.fetch("lastName", ""), "birthdate" => player["dateOfBirth"]&.slice(0, 10),
            "display_name" => player.fetch("displayName"),
            "number" => player["jersey"], "position" => player.dig("position", "abbreviation"),
            "photo_url" => player.dig("headshot", "href") }.compact
        end.uniq { |player| player.fetch("source_id") }
      }
    end
    save(name, { "provider" => "espn", "league" => name.upcase, "season" => label, "as_of" => @as_of,
      "source_url" => index_url, "roster_meaning" => "Complete source-listed season roster captured on #{@as_of}; not a complete historical season union or a competition registration certification.",
      "teams" => teams.map { |team| team.fetch("normalized") }.sort_by { |team| team.fetch("source_id").to_i } })
  end

  def nhl
    url = "https://api-web.nhle.com/v1/standings/#{@as_of}"
    teams = json(url).fetch("standings").map do |team|
      { "source_id" => team.fetch("teamAbbrev").fetch("default"), "abbreviation" => team.fetch("teamAbbrev").fetch("default"),
        "name" => team.fetch("teamName").fetch("default"), "territory" => team.fetch("placeName").fetch("default"),
        "mascot" => team.fetch("teamCommonName").fetch("default"), "logos" => [ { "href" => team.fetch("teamLogo"), "rel" => [ "default" ] } ] }
    end
    raise "Incomplete NHL team list" unless teams.size == 32
    schedules = {}
    mutex = Mutex.new
    parallel(teams) do |team|
      code = team.fetch("abbreviation")
      roster_url = "https://api-web.nhle.com/v1/roster/#{code}/20262027"
      roster = json(roster_url)
      team["url"] = roster_url
      team["players"] = %w[forwards defensemen goalies].flat_map { |key| roster.fetch(key) }.map do |player|
        { "source_id" => player.fetch("id").to_s, "first_name" => player.fetch("firstName").fetch("default"),
          "last_name" => player.fetch("lastName").fetch("default"), "birthdate" => player["birthDate"],
          "number" => player["sweaterNumber"]&.to_s, "position" => player["positionCode"], "photo_url" => player["headshot"] }.compact
      end
      raise "Empty NHL roster: #{code}" if team["players"].empty?
      schedule_url = "https://api-web.nhle.com/v1/club-schedule-season/#{code}/20262027"
      schedule = json(schedule_url)
      raise "Wrong NHL season" unless schedule.fetch("currentSeason") == 20262027
      games = schedule.fetch("games").select { |game| game.fetch("gameType") == 2 }
      raise "Incomplete NHL team schedule: #{code}/#{games.size}" unless games.size == 84
      mutex.synchronize { schedules[code] = games }
    end
    appearances = schedules.values.flatten.group_by { |game| game.fetch("id") }
    raise "Incomplete NHL schedule" unless appearances.size == 1344 && appearances.values.all? { |copies| copies.size == 2 }
    games = appearances.sort.map do |id, copies|
      normalized = copies.map do |game|
        { "source_id" => id.to_s, "date" => game.fetch("gameDate"), "start_time_utc" => game["startTimeUTC"],
          "venue" => game.fetch("venue").fetch("default"), "state" => game.fetch("gameState"),
          "home" => game.fetch("homeTeam").fetch("abbrev"), "away" => game.fetch("awayTeam").fetch("abbrev"),
          "source_url" => "https://api-web.nhle.com/v1/gamecenter/#{id}/landing" }.compact
      end
      raise "NHL schedule copies disagree for #{id}" unless normalized.uniq.one?
      normalized.first
    end
    save("nhl", { "provider" => "nhl", "league" => "NHL", "season" => "2026_2027", "as_of" => @as_of,
      "source_url" => url, "roster_meaning" => "Complete official season roster listing captured on #{@as_of}; not an appearance union.",
      "teams" => teams.sort_by { |team| team.fetch("abbreviation") }, "games" => games })
  end

  def mlb
    url = "https://statsapi.mlb.com/api/v1/teams?sportId=1&season=2026"
    teams = json(url).fetch("teams")
    raise "Incomplete MLB team list" unless teams.size == 30
    parallel(teams) do |team|
      roster_url = "https://statsapi.mlb.com/api/v1/teams/#{team.fetch('id')}/roster?rosterType=fullSeason&season=2026&hydrate=person"
      players = json(roster_url).fetch("roster")
      raise "Empty MLB roster" if players.empty?
      team["normalized"] = { "source_id" => team.fetch("id").to_s, "abbreviation" => team.fetch("abbreviation"),
        "name" => team.fetch("name"), "territory" => team.fetch("locationName"), "mascot" => team.fetch("teamName"),
        "url" => roster_url, "logos" => [], "players" => players.map do |entry|
          player = entry.fetch("person")
          { "source_id" => player.fetch("id").to_s, "first_name" => player.fetch("firstName"),
            "last_name" => player.fetch("lastName"), "birthdate" => player["birthDate"],
            "number" => entry["jerseyNumber"], "position" => entry.fetch("position").fetch("abbreviation") }.compact
        end.uniq { |player| player.fetch("source_id") } }
    end
    save("mlb", { "provider" => "mlb", "league" => "MLB", "season" => "2026", "as_of" => @as_of,
      "source_url" => url, "roster_meaning" => "Complete official fullSeason roster inventory, including departed players. Does not assert current active-roster status or dates of number assignments.",
      "teams" => teams.map { |team| team.fetch("normalized") }.sort_by { |team| team.fetch("source_id").to_i } })
  end

  def nba_history(year)
    teams = {}
    url = "https://www.basketball-reference.com/leagues/NBA_#{year}_per_game.html"
    document = Nokogiri::HTML(fetch(url))
    tables = document.css("#per_game_stats, #per_game_stats_post")
    raise "Missing NBA regular-season or playoff table" unless tables.size == 2
    rows = tables.css("tbody tr").select { |row| row.at_css("[data-stat=name_display] a, [data-stat=player] a") }
    raise "Missing NBA historical rows: #{url}" if rows.empty?
    rows.each do |row|
      cell = row.at_css("[data-stat=team_name_abbr], [data-stat=team_id]")
      abbreviation = cell&.text&.strip
      next unless abbreviation&.match?(/\A[A-Z]{3}\z/) && !%w[TOT 2TM 3TM 4TM].include?(abbreviation)
      link = row.at_css("[data-stat=name_display] a, [data-stat=player] a")
      source_id = File.basename(link["href"], ".html")
      name = link.text.strip
      first, last = name.split(/\s+/, 2)
      raise "Incomplete NBA name: #{name}" unless last
      team = teams[abbreviation] ||= { "source_id" => abbreviation, "abbreviation" => abbreviation, "name" => abbreviation,
        "url" => url, "logos" => [], "players" => [] }
      team["players"] << { "source_id" => source_id, "first_name" => first, "last_name" => last,
        "profile_url" => "https://www.basketball-reference.com#{link['href']}" }
    end
    raise "Incomplete NBA #{year} team coverage: #{teams.size}" unless teams.size == 30
    teams.each_value { |team| team["players"].uniq! { |player| player.fetch("source_id") } }
    save("nba_#{year - 1}", { "provider" => "basketball_reference", "league" => "NBA", "season" => "#{year - 1}_#{year}", "as_of" => @as_of,
      "source_url" => "https://www.basketball-reference.com/leagues/NBA_#{year}_per_game.html",
      "roster_meaning" => "Complete regular-season and playoff appearance union by team, retaining trade-side memberships. Excludes roster members with no recorded appearances and does not establish jersey-number periods.",
      "teams" => teams.values.sort_by { |team| team.fetch("abbreviation") } })
  end
end

if $PROGRAM_NAME == __FILE__
  options = { as_of: nil, leagues: %w[nba nfl mlb nhl mls epl ucl nba_2023 nba_2024 nba_2025], refresh: false }
  OptionParser.new do |parser|
    parser.on("--as-of DATE") { |value| options[:as_of] = value }
    parser.on("--leagues LIST") { |value| options[:leagues] = value.split(",") }
    parser.on("--refresh") { options[:refresh] = true }
  end.parse!
  abort "Unexpected arguments" unless ARGV.empty?
  abort "Pass --as-of YYYY-MM-DD with the actual observation date" unless options[:as_of]
  capture = Sports2026Capture.new(as_of: options.fetch(:as_of), refresh: options.fetch(:refresh))
  options.fetch(:leagues).each do |league|
    if Sports2026Capture::ESPN.key?(league)
      capture.espn(league)
    elsif league.match?(/\Anba_202[3-5]\z/)
      capture.nba_history(league.delete_prefix("nba_").to_i + 1)
    elsif %w[nhl mlb].include?(league)
      capture.public_send(league)
    else
      abort "Unknown league: #{league}"
    end
  end
end
