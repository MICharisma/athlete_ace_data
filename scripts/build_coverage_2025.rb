#!/usr/bin/env ruby
require "date"
require "fileutils"
require "json"
require "net/http"
require "nokogiri"
require "yaml"
require_relative "lib/seed_catalog"

class Coverage2025
  ROOT = File.expand_path("..", __dir__)
  CAPTURE = File.join(ROOT, "sources/coverage_2025.json")
  OUTPUT = File.join(ROOT, "yaml/coverage_2025")
  LEAGUES = {
    "NBA" => { sport: "BKT", season: "2025_2026", count: 30, full: "NYK" },
    "NFL" => { sport: "FTB", season: "2025", count: 32, full: "SF" },
    "NHL" => { sport: "HCK", season: "2025_2026", count: 32, full: "STL" },
    "EPL" => { sport: "SOC", season: "2025_2026", count: 20, full: nil }
  }.freeze
  # The NHL source's place name for the two New York clubs is "NY <club>".
  NHL_PLACES = { "NYI" => "New York", "NYR" => "New York" }.freeze
  EPL_ABBREVIATIONS = {
    "AFC Bournemouth" => "BOU", "Arsenal" => "ARS", "Aston Villa" => "AVL",
    "Brentford" => "BRE", "Brighton & Hove Albion" => "BHA", "Burnley" => "BUR",
    "Chelsea" => "CHE", "Crystal Palace" => "CRY", "Everton" => "EVE",
    "Fulham" => "FUL", "Leeds United" => "LEE", "Liverpool" => "LIV",
    "Manchester City" => "MCI", "Manchester United" => "MUN", "Newcastle United" => "NEW",
    "Nottingham Forest" => "NFO", "Sunderland" => "SUN", "Tottenham Hotspur" => "TOT",
    "West Ham United" => "WHU", "Wolverhampton Wanderers" => "WOL"
  }.freeze
  NBA_NAMES = {
    "Philadelphia Sixers" => "Philadelphia 76ers", "OKC Thunder" => "Oklahoma City Thunder",
    "Portland Trailblazers" => "Portland Trail Blazers"
  }.freeze

  def fetch(url)
    3.times do |attempt|
      begin
        response = Net::HTTP.start(URI(url).host, URI(url).port, use_ssl: true,
          open_timeout: 15, read_timeout: 30) do |http|
          http.request(Net::HTTP::Get.new(URI(url), "User-Agent" => "Mozilla/5.0 AthleteAce seed capture"))
        end
        if response.is_a?(Net::HTTPRedirection)
          return fetch(URI.join(url, response.fetch("location")).to_s)
        end
        raise "HTTP #{response.code}: #{url}" unless response.is_a?(Net::HTTPSuccess)
        return response.body.force_encoding("UTF-8")
      rescue StandardError
        raise if attempt == 2
      end
    end
  end

  def html(url)
    Nokogiri::HTML(fetch(url))
  end

  def abbreviations(path)
    JSON.parse(File.read(File.join(ROOT, "sports", path, "teams.json"))).fetch("teams").to_h do |team|
      territory = team.fetch("abbreviation") == "LAC" ? "Los Angeles" : team.fetch("territory")
      ["#{territory} #{team.fetch('mascot')}", team.fetch("abbreviation")]
    end
  end

  def split_name(name)
    first, last = name.strip.split(/\s+/, 2)
    raise "Incomplete player name: #{name}" unless last
    { "first_name" => first, "last_name" => last }
  end

  def capture
    teams = []
    nba_url = "https://pdfroster.nba.com/nba/"
    nba_codes = abbreviations("basketball/USA/NBA")
    html(nba_url).css("a").each do |link|
      name = NBA_NAMES.fetch(link.text.strip, link.text.strip)
      next unless nba_codes.key?(name)
      teams << { "league" => "NBA", "name" => name, "abbreviation" => nba_codes.fetch(name),
        "url" => link["href"], "index_url" => nba_url }
    end
    nfl_url = "https://www.nfl.com/sitemap/html/rosters/2025/"
    nfl_codes = abbreviations("football/USA/NFL")
    html(nfl_url).css("a").each do |link|
      name = link.text.strip
      next unless link["href"]&.start_with?("/sitemap/html/rosters/2025/") && nfl_codes.key?(name)
      teams << { "league" => "NFL", "name" => name, "abbreviation" => nfl_codes.fetch(name),
        "url" => URI.join(nfl_url, link["href"]).to_s, "index_url" => nfl_url }
    end
    nhl_url = "https://api-web.nhle.com/v1/standings/2026-04-17"
    JSON.parse(fetch(nhl_url)).fetch("standings").each do |team|
      abbreviation = team.fetch("teamAbbrev").fetch("default")
      teams << { "league" => "NHL", "name" => team.fetch("teamName").fetch("default"),
        "territory" => team.fetch("placeName").fetch("default"),
        "mascot" => team.fetch("teamCommonName").fetch("default"), "abbreviation" => abbreviation,
        "url" => "https://api-web.nhle.com/v1/club-stats/#{abbreviation}/20252026/2", "index_url" => nhl_url }
    end
    epl_url = "https://www.premierleague.com/en/news/4407896"
    html(epl_url).css("h5").each do |heading|
      name = heading.text.tr("\u00a0", " ").strip
      name = "Tottenham Hotspur" if name == "Tottenham Hostspur"
      next unless EPL_ABBREVIATIONS.key?(name)
      paragraph = heading.next_element
      raise "Missing senior squad for #{name}" unless paragraph&.text&.include?("Squad players")
      players = paragraph.inner_html.split(/<br\s*\/?\s*>/i).drop(1).filter_map do |fragment|
        value = Nokogiri::HTML.fragment(fragment).text.strip.delete_suffix("*")
        next if value.empty?
        last, first = value.split(",", 2).map(&:strip)
        raise "Unexpected squad name #{value}" unless first && last
        { "first_name" => first, "last_name" => last, "source_key" => value }
      end
      teams << { "league" => "EPL", "name" => name, "abbreviation" => EPL_ABBREVIATIONS.fetch(name),
        "url" => epl_url, "index_url" => epl_url, "players" => players,
        "roster_meaning" => "Registered senior squad after the summer 2025 window; excludes the separate U21 list." }
    end
    teams = teams.uniq { |team| [team.fetch("league"), team.fetch("abbreviation")] }
    LEAGUES.each do |league, config|
      raise "Incomplete #{league} team index" unless teams.count { |team| team.fetch("league") == league } == config.fetch(:count)
    end
    queue = Queue.new
    teams.reject { |team| team.key?("players") }.each { |team| queue << team }
    errors = Queue.new
    finished = 0
    mutex = Mutex.new
    6.times.map do
      Thread.new do
        loop do
          team = queue.pop(true)
          begin
            roster(team)
            mutex.synchronize do
              finished += 1
              puts "Captured #{finished}/94 rosters" if (finished % 12).zero? || finished == 94
            end
          rescue StandardError => error
            errors << "#{team.fetch('league')}/#{team.fetch('abbreviation')}: #{error.message}"
          end
        rescue ThreadError
          break
        end
      end
    end.each(&:join)
    raise Array.new(errors.size) { errors.pop }.join("\n") unless errors.empty?
    teams.each do |team|
      team["season"] = LEAGUES.fetch(team.fetch("league")).fetch(:season)
      raise "Too few source players: #{team.fetch('name')}" if team.fetch("players").size < 2
    end
    document = { "captured_on" => Date.today.iso8601, "selection" => "Full source rosters for NYK/SF/STL; first two source-listed players for other teams.",
      "teams" => teams.sort_by { |team| [team.fetch("league"), team.fetch("abbreviation")] } }
    FileUtils.mkdir_p(File.dirname(CAPTURE))
    File.write(CAPTURE, JSON.pretty_generate(document) + "\n")
  end

  def roster(team)
    case team.fetch("league")
    when "NBA"
      document = html(team.fetch("url"))
      raise "Unexpected NBA source season" unless document.text.include?("Displaying roster data for 2025 season.")
      team["players"] = document.css("div.player").reject { |node| node.ancestors.any? { |parent| parent["class"].to_s.split.include?("coaches") } }.map do |node|
        name = node.at_css("h3").text.sub(/\s*#.*\z/, "").strip
        id = node.at_css("img")["src"][%r{/([0-9]+)\.png}, 1]
        raise "Missing NBA player ID: #{name}" unless id
        split_name(name).merge("source_key" => id)
      end
      team["roster_meaning"] = "All names on the NBA director face sheet labeled 2025 season; a roster listing captured on the stated date, not a complete season appearance union."
    when "NFL"
      team["players"] = html(team.fetch("url")).css("table a[href^='/players/']").map do |node|
        split_name(node.text.strip).merge("source_key" => node["href"], "profile_url" => URI.join(team.fetch("url"), node["href"]).to_s)
      end
      team["roster_meaning"] = "All names on NFL.com's 2025 roster sitemap, including its reserve/offseason listings where present; no active-game status or appearances are asserted."
    when "NHL"
      statistics = JSON.parse(fetch(team.fetch("url")))
      raise "Unexpected NHL season" unless statistics.fetch("season").to_s == "20252026" && statistics.fetch("gameType") == 2
      team["players"] = statistics.fetch("skaters").concat(statistics.fetch("goalies")).map do |player|
        { "first_name" => player.fetch("firstName").fetch("default"), "last_name" => player.fetch("lastName").fetch("default"),
          "source_key" => player.fetch("playerId").to_s }
      end
      team["roster_meaning"] = "All skaters and goalies with 2025_2026 regular-season appearances in the NHL's archived club statistics; no contract or exact membership dates are asserted."
    end
    team["players"] = team.fetch("players").uniq { |player| player.fetch("source_key") }
  end

  def token(value)
    value.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").tr("øØłŁæÆœŒ", "oOlLaAoO").upcase.gsub(/[^A-Z0-9]+/, "_").gsub(/\A_|_\z/, "")
  end

  def run
    capture if ARGV.include?("--refresh")
    document = JSON.parse(File.read(CAPTURE))
    photo_capture = JSON.parse(File.read(File.join(ROOT, "sources/nba_player_photos.json")))
    photos = photo_capture.fetch("players").to_h { |player| [player.fetch("source_key"), player] }
    # The catalog holds every identity, including the pilot's preferred codes and aliases.
    existing = Dir.glob(File.join(SeedCatalog::LIBRARY, SeedCatalog::CATALOG, "**/*.yml")).flat_map { |path| YAML.safe_load_file(path).fetch("records") }
    writer = SeedCatalog::Writer.new(check: ARGV.include?("--check"))
    known = existing.each_with_object({}) { |row, memo| ([row.fetch("code")] + row.fetch("aliases", [])).each { |code| memo[code] = row.fetch("code") } }
    identities = {}
    summaries = {}
    FileUtils.mkdir_p(OUTPUT)
    LEAGUES.each do |league, config|
      prefix = "#{config.fetch(:sport)}-#{league}"
      selected_teams = document.fetch("teams").select { |team| team.fetch("league") == league }
      raise "Incomplete #{league} capture" unless selected_teams.size == config.fetch(:count)
      groups = selected_teams.map do |team|
        abbreviation = team.fetch("abbreviation")
        team_code = known.fetch("#{prefix}-TEAM-#{abbreviation}", "#{prefix}-TEAM-#{abbreviation}")
        campaign_code = "#{prefix}-SEASON_#{config.fetch(:season)}-TEAM-#{team_code.split('-TEAM-').last}"
        complete = abbreviation == config.fetch(:full)
        players = complete ? team.fetch("players") : team.fetch("players").first(2)
        raise "Too few selected players" unless players.size >= 2
        records = []
        unless known.key?(team_code)
          territory, mascot = team.fetch("name").split(/\s+(?=\S+\z)/, 2)
          if league == "NBA" && abbreviation == "POR"
            territory, mascot = "Portland", "Trail Blazers"
          end
          territory = league == "NHL" ? NHL_PLACES.fetch(abbreviation, team.fetch("territory")) : team.fetch("territory", territory)
          mascot = team.fetch("mascot", mascot)
          # Clubs are known by their full name, without a separate place.
          territory, mascot = nil, team.fetch("name") if league == "EPL"
          records << { "type" => "Team", "code" => team_code,
            "attributes" => { "territory" => territory, "mascot" => mascot, "abbreviation" => abbreviation }.compact, "references" => {} }
          known[team_code] = team_code
        end
        records << { "type" => "Campaign", "code" => campaign_code,
          "attributes" => { "display_name" => team.fetch("name"), "abbreviation" => abbreviation,
            "details" => { "roster_coverage" => complete ? "complete_source_listing" : "two_player_sample", "source_player_count" => team.fetch("players").size, "selected_player_count" => players.size } }, "references" => {} }
        players.each do |player|
          alias_code = "#{prefix}-PLAYER-#{token(player.fetch('last_name'))}_#{token(player.fetch('first_name'))}"
          identity = [league, player.fetch("source_key")]
          raise "Ambiguous player code #{alias_code}" if identities.key?(alias_code) && identities.fetch(alias_code) != identity
          identities[alias_code] = identity
          player_code = known.fetch(alias_code, alias_code)
          unless known.key?(alias_code)
            record = { "type" => "Player", "code" => player_code,
              "attributes" => player.slice("first_name", "last_name", "birthdate"), "references" => { "sport" => "SPORT-#{config.fetch(:sport)}" } }
            if league == "NBA" && (photo = photos[player.fetch("source_key")])
              record.fetch("attributes")["photo_urls"] = [photo.fetch("photo_url")]
              record["source"] = {"url" => photo.fetch("profile_url"), "captured_on" => photo_capture.fetch("captured_on"),
                "note" => "Official NBA photo URL verified as an image response. Player identity comes from the recorded NBA source_key."}
            end
            records << record
            known[alias_code] = player_code
          end
          records << { "type" => "Activation", "code" => "#{campaign_code}-PLAYER-#{alias_code.split('-PLAYER-').last}",
            "attributes" => {}, "references" => { "player" => player_code } }
        end
        { "scope" => { "team" => team_code }, "source" => { "url" => team.fetch("url"),
          "captured_on" => document.fetch("captured_on"), "note" => "#{team.fetch('roster_meaning')} #{complete ? 'Every source-listed player is selected.' : 'Only the first two source-listed players are selected.'}" }, "records" => records }
      end
      manifest = { "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA",
        "scope" => { "sport" => "SPORT-#{config.fetch(:sport)}", "league" => "#{config.fetch(:sport)}-LEAGUE-#{league}", "year" => "YEAR-2025" }, "groups" => groups }
      writer.write_batch(File.join(OUTPUT, "#{league.downcase}.yaml"), manifest) # Identities go to the catalog.
      summaries[league] = { teams: groups.size, memberships: groups.sum { |group| group.fetch("records").count { |row| row.fetch("type") == "Activation" } },
        full_roster: config.fetch(:full), full_roster_players: selected_teams.find { |team| team.fetch("abbreviation") == config.fetch(:full) }&.fetch("players")&.size }
    end
    writer.finish(codes_path: File.join(ROOT, "sources/coverage_2025/catalog_codes.json"))
    puts JSON.pretty_generate(summaries)
  end
end

Coverage2025.new.run
