require "optparse"
require_relative "capture_2026"

class Geography2026Capture < Sports2026Capture
  PATHS = { "nba" => "basketball/nba", "nfl" => "football/nfl", "nhl" => "hockey/nhl", "mls" => "soccer/usa.1", "epl" => "soccer/eng.1" }.freeze

  def call
    rows = []
    PATHS.each do |league, path|
      capture = JSON.parse(File.read(File.join(ROOT, "sources/coverage_2026/#{league}.json")))
      teams = capture.fetch("teams")
      if league == "nhl"
        url = "https://site.api.espn.com/apis/site/v2/sports/#{path}/teams?limit=100&season=2027"
        index = json(url).fetch("sports").first.fetch("leagues").first.fetch("teams").map { |entry| entry.fetch("team") }
      end
      parallel(teams) do |team|
        id = team.fetch("source_id")
        if league == "nhl"
          matches = index.select { |candidate| normalize(candidate.fetch("displayName")) == normalize(team.fetch("name")) }
          raise "No unique ESPN NHL match for #{team.fetch('name')}" unless matches.one?
          id = matches.first.fetch("id")
        end
        year = %w[nba nhl].include?(league) ? 2027 : 2026
        url = "https://site.api.espn.com/apis/site/v2/sports/#{path}/teams/#{id}/schedule?season=#{year}"
        url += "&seasontype=2" unless %w[mls epl].include?(league)
        response = json(url)
        raise "Wrong season: #{url}" unless response.fetch("season").fetch("year") == year
        raise "Wrong team ID: #{url}" unless response.fetch("team").fetch("id") == id
        observations = response.fetch("events").flat_map do |event|
          event.fetch("competitions").filter_map do |competition|
            home = competition.fetch("competitors").any? { |entry| entry["homeAway"] == "home" && entry.fetch("team").fetch("id") == id }
            next unless home && !competition.fetch("neutralSite")
            venue = competition.fetch("venue")
            { "event_id" => event.fetch("id"), "date" => event.fetch("date"), "venue" => venue }
          end
        end
        raise "No home venue observations: #{url}" if observations.empty?
        venues = observations.group_by { |entry| entry.fetch("venue") }.map do |venue, entries|
          { "venue" => venue, "observations" => entries.map { |entry| entry.except("venue") } }
        end
        rows << { "league" => league.upcase, "season" => capture.fetch("season"), "team_id" => team.fetch("source_id"),
          "team" => team.fetch("name"), "url" => url, "venues" => venues }
      end
      puts "#{league}: #{teams.size} home venue listings"
    end
    url = "https://statsapi.mlb.com/api/v1/teams?sportId=1&season=2026&hydrate=venue(location,fieldInfo)"
    teams = json(url).fetch("teams")
    capture = JSON.parse(File.read(File.join(ROOT, "sources/coverage_2026/mlb.json")))
    raise "MLB team set changed" unless teams.map { |team| team.fetch("id").to_s }.sort == capture.fetch("teams").map { |team| team.fetch("source_id").to_s }.sort
    teams.each do |team|
      raise "Wrong MLB season" unless team.fetch("season") == 2026
      rows << { "league" => "MLB", "season" => "2026", "team_id" => team.fetch("id").to_s,
        "team" => team.fetch("name"), "url" => url, "venues" => [ { "venue" => team.fetch("venue") } ] }
    end
    document = { "as_of" => @as_of, "meaning" => "Non-neutral home venues observed in the selected ESPN season schedules, plus MLB season team venue listings. Schedule observations are not a certification of every venue used during a season.",
      "teams" => rows.sort_by { |row| [ row.fetch("league"), row.fetch("team_id").to_i, row.fetch("team_id") ] } }
    path = File.join(ROOT, "sources/geography_2026/home_venues.json")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(document) + "\n")
    puts "Saved #{rows.size} team listings to #{path}"
  end

  def normalize(value)
    value.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.gsub(/[^a-z0-9]/, "")
  end
end

if $PROGRAM_NAME == __FILE__
  options = { as_of: nil, refresh: false }
  OptionParser.new do |parser|
    parser.on("--as-of DATE") { |value| options[:as_of] = value }
    parser.on("--refresh") { options[:refresh] = true }
  end.parse!
  abort "Pass --as-of YYYY-MM-DD with the actual observation date" unless options[:as_of] && ARGV.empty?
  Geography2026Capture.new(**options).call
end
