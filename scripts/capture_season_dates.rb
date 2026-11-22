require "date"
require "digest"
require "fileutils"
require "json"
require "net/http"
require "optparse"
require "time"
require "yaml"

# Captures the first and last regular-season game dates for every NBA, NFL,
# NHL and MLB season in the library. MLB's come from the official Stats API
# season record. For the other leagues ESPN's season-type window (core API
# types/2) starts a search: it often begins the day before the first game. The
# dates recorded are the first and last scoreboard days (US Eastern, as ESPN's
# dates parameter reads them) listing a completed regular-season game. A season
# still in progress on the observation date has no last date.
class SeasonDatesCapture
  ROOT = File.expand_path("..", __dir__)
  LEAGUES = {
    "NBA" => { sport: "BKT", path: "basketball/nba", core: "basketball/leagues/nba", split: true },
    "NFL" => { sport: "FTB", path: "football/nfl", core: "football/leagues/nfl", split: false },
    "NHL" => { sport: "HCK", path: "hockey/nhl", core: "hockey/leagues/nhl", split: true },
    "MLB" => { sport: "BSB", split: false, mlb: true }
  }.freeze
  SCAN_DAYS = 180
  GAP_DAYS = 21

  def initialize(as_of:, refresh: false, output: File.join(ROOT, "sources/season_dates/season_dates.json"))
    @as_of = Date.iso8601(as_of)
    @refresh, @output = refresh, output
    @cache = File.join(ROOT, "sources/.http-cache")
    FileUtils.mkdir_p(@cache)
  end

  def call
    seasons = LEAGUES.flat_map do |league, config|
      labels(config.fetch(:sport), league).map { |label| [ league, config, label ] }
    end
    captured = seasons.map { |league, config, label| capture(league, config, label) }
    FileUtils.mkdir_p(File.dirname(@output))
    File.write(@output, JSON.pretty_generate({
      "as_of" => @as_of.iso8601,
      "meaning" => "First and last regular-season game dates. MLB: the Stats API season record's regular-season start and end dates. " \
        "NBA, NFL and NHL: the first and last US Eastern ESPN scoreboard days listing a completed regular-season (season type 2) game, " \
        "searched from ESPN's season-type window; the last day extends past the window while completed regular-season games appear within 21 days. " \
        "A season in progress on the observation date has no last date.",
      "seasons" => captured
    }) + "\n")
    puts({ seasons: captured.size, without_end: captured.count { !it["last_game_date"] } }.to_json)
  end

  private

  def labels(sport, league)
    YAML.safe_load(File.read(File.join(ROOT, "yaml/catalog/#{sport}/#{league}/seasons.yml"), encoding: "UTF-8"))
      .fetch("records").select { it["type"] == "Season" }.map { it.dig("attributes", "label") }.sort
  end

  def capture(league, config, label)
    return capture_mlb(config, label) if config[:mlb]

    year = config.fetch(:split) ? label.split("_").last.to_i : label.to_i
    window_url = "https://sports.core.api.espn.com/v2/sports/#{config.fetch(:core)}/seasons/#{year}/types/2?lang=en&region=us"
    window = json(window_url)
    raise "#{league} #{label}: ESPN returned season #{window['year']}" unless window["year"] == year && window["name"] == "Regular Season"

    window_start = Date.parse(window.fetch("startDate")) - 1
    window_end = Date.parse(window.fetch("endDate"))
    first = scan(config, window_start, 1) or raise "#{league} #{label}: no regular-season games within #{SCAN_DAYS} days of #{window_start}"
    last = window_end > @as_of ? nil : scan(config, window_end + 1, -1)
    raise "#{league} #{label}: no last regular-season day before #{window_end}" if window_end <= @as_of && !last
    last &&= extend_run(config, last, 1)

    { "league" => league, "season" => "#{config.fetch(:sport)}-#{league}-SEASON_#{label}", "label" => label, "provider" => "espn", "espn_year" => year,
      "window" => { "url" => window_url, "start" => window.fetch("startDate"), "end" => window.fetch("endDate") },
      "first_game_date" => first.fetch(:date), "first_games" => first.fetch(:games), "first_url" => first.fetch(:url),
      "last_game_date" => last&.fetch(:date), "last_games" => last&.fetch(:games), "last_url" => last&.fetch(:url) }.compact
  end

  # ESPN labels some MLB exhibitions and spring games as regular season
  # (2016-04-01, 2017-03-09), so MLB uses its own official season record.
  def capture_mlb(config, label)
    url = "https://statsapi.mlb.com/api/v1/seasons/#{label}?sportId=1"
    seasons = json(url).fetch("seasons")
    season = seasons.first
    raise "MLB #{label}: Stats API returned #{seasons.map { it['seasonId'] }}" unless seasons.one? && season.fetch("seasonId") == label

    last = season.fetch("regularSeasonEndDate")
    { "league" => "MLB", "season" => "#{config.fetch(:sport)}-MLB-SEASON_#{label}", "label" => label, "provider" => "mlb", "url" => url,
      "first_game_date" => season.fetch("regularSeasonStartDate"), "last_game_date" => (last if Date.iso8601(last) <= @as_of) }.compact
  end

  def scan(config, from, step, days: SCAN_DAYS)
    days.times do |offset|
      day = from + offset * step
      next if day > @as_of

      found = games_on(config, day)
      return found if found
    end
    nil
  end

  # Late makeup games can fall after ESPN's window (NHL, May 2021). Keep
  # stepping past the last found day while completed regular-season games
  # appear within GAP_DAYS of it.
  def extend_run(config, found, step)
    while (further = scan(config, Date.iso8601(found.fetch(:date)) + step, step, days: GAP_DAYS))
      found = further
    end
    found
  end

  # A day counts only when a regular-season game on it was completed:
  # ESPN keeps postponed and cancelled games (NHL, March 2020) in the season.
  def games_on(config, day)
    url = "https://site.api.espn.com/apis/site/v2/sports/#{config.fetch(:path)}/scoreboard?dates=#{day.strftime('%Y%m%d')}"
    games = json(url).fetch("events", []).select { it.dig("season", "type") == 2 && it.dig("status", "type", "completed") }
    return if games.empty?

    { date: day.iso8601, url: url, games: games.map { { "id" => it.fetch("id"), "name" => it.fetch("shortName"), "date" => it.fetch("date") } }.sort_by { it["id"] } }
  end

  def json(url)
    path = File.join(@cache, Digest::SHA256.hexdigest(url))
    unless File.file?(path) && !@refresh
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
        http.get(uri.request_uri, "User-Agent" => "Mozilla/5.0", "Accept" => "application/json")
      end
      raise "HTTP #{response.code}: #{url}" unless response.is_a?(Net::HTTPSuccess)

      File.write(path, response.body)
      sleep 0.2
    end
    JSON.parse(File.read(path, encoding: "UTF-8"))
  end
end

if $PROGRAM_NAME == __FILE__
  options = { refresh: false }
  OptionParser.new do |parser|
    parser.on("--as-of DATE") { |value| options[:as_of] = value }
    parser.on("--refresh") { options[:refresh] = true }
  end.parse!
  abort "Usage: ruby scripts/capture_season_dates.rb --as-of YYYY-MM-DD [--refresh]" unless options[:as_of]
  SeasonDatesCapture.new(**options).call
end
