require "date"
require "fileutils"
require "json"
require "net/http"
require "optparse"

class ChampionshipAlignmentCapture
  ROOT = File.expand_path("..", __dir__)

  def initialize(as_of:, leagues: %w[NBA NFL NHL MLB])
    @as_of = Date.iso8601(as_of).iso8601
    @output = File.join(ROOT, "sources/championship_history")
    @leagues = leagues
  end

  def call
    FileUtils.mkdir_p(@output)
    @leagues.each do |league|
      seasons = (2016..2025).map do |awarded_year|
        start_year = league == "MLB" ? awarded_year : awarded_year - 1
        url, teams = case league
        when "NBA", "NFL" then espn(league, start_year)
        when "NHL" then awarded_year == 2021 ? nhl(awarded_year) : espn(league, start_year)
        when "MLB" then mlb(start_year)
        end
        expected = league == "NFL" ? 32 : league == "NHL" ? (start_year < 2017 ? 30 : start_year < 2021 ? 31 : 32) : 30
        raise "#{league} #{start_year}: expected #{expected} distinct teams" unless teams.size == expected && teams.map { |team| team.fetch("source_id") }.uniq.size == expected

        { "start_year" => start_year, "label" => %w[NBA NHL].include?(league) ? "#{start_year}_#{start_year + 1}" : start_year.to_s,
          "url" => url, "teams" => teams.sort_by { |team| team.fetch("source_id") } }
      end
      document = { "league" => league, "as_of" => @as_of,
        "meaning" => "Complete annual league/conference/division classification. No player roster, game participation, or exact affiliation dates are asserted.", "seasons" => seasons }
      File.write(File.join(@output, "#{league.downcase}_alignments.json"), JSON.pretty_generate(document) + "\n")
      puts "#{league}: #{seasons.size} seasons, #{seasons.sum { |season| season.fetch('teams').size }} annual teams"
    end
  end

  private

  def get(url)
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
      http.get(uri.request_uri, "User-Agent" => "Mozilla/5.0", "Accept" => "application/json")
    end
    raise "HTTP #{response.code}: #{url}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def espn(league, start_year)
    sport = { "NBA" => "basketball", "NFL" => "football", "NHL" => "hockey" }.fetch(league)
    year = league == "NFL" ? start_year : start_year + 1
    url = "https://site.web.api.espn.com/apis/v2/sports/#{sport}/#{league.downcase}/standings?season=#{year}&level=3"
    data = get(url)
    raise "Wrong #{league} season: #{url}" unless data.fetch("season").fetch("year") == year

    teams = data.fetch("children").flat_map do |conference|
      conference.fetch("children").flat_map do |division|
        division.fetch("standings").fetch("entries").map do |entry|
          team = entry.fetch("team")
          abbreviation = team.fetch("abbreviation")
          abbreviation = { "LA" => "LAK", "NJ" => "NJD", "SJ" => "SJS", "TB" => "TBL", "UTAH" => "UTA" }.fetch(abbreviation, abbreviation) if league == "NHL"
          { "source_id" => league == "NHL" ? abbreviation : team.fetch("id"), "provider_team_id" => team.fetch("id"),
            "name" => team.fetch("displayName"), "abbreviation" => abbreviation,
            "conference" => conference.fetch("name"), "division" => division.fetch("name") }
        end
      end
    end
    [ url, teams ]
  end

  def nhl(year)
    date = "#{year}-05-20"
    url = "https://api-web.nhle.com/v1/standings/#{date}"
    teams = get(url).fetch("standings").map do |team|
      raise "Wrong NHL season: #{url}" unless team.fetch("seasonId") == (year - 1) * 10000 + year

      { "source_id" => team.fetch("teamAbbrev").fetch("default"), "name" => team.fetch("teamName").fetch("default"),
        "abbreviation" => team.fetch("teamAbbrev").fetch("default"), "conference" => team["conferenceName"], "division" => team.fetch("divisionName") }
    end
    [ url, teams ]
  end

  def mlb(year)
    url = "https://statsapi.mlb.com/api/v1/teams?sportId=1&season=#{year}"
    teams = get(url).fetch("teams").map do |team|
      raise "Wrong MLB season: #{url}" unless team.fetch("season") == year

      { "source_id" => team.fetch("id").to_s, "name" => team.fetch("name"), "abbreviation" => team.fetch("abbreviation"),
        "conference" => team.fetch("league").fetch("name"), "division" => team.fetch("division").fetch("name") }
    end
    [ url, teams ]
  end
end

if $PROGRAM_NAME == __FILE__
  options = {}
  OptionParser.new do |parser|
    parser.on("--as-of DATE") { |value| options[:as_of] = value }
    parser.on("--leagues LIST", Array) { |value| options[:leagues] = value }
  end.parse!
  abort "Usage: ruby scripts/capture_championship_alignments.rb --as-of YYYY-MM-DD [--leagues NBA,NFL,NHL,MLB]" unless options[:as_of] && ARGV.empty? && (options.fetch(:leagues, []) - %w[NBA NFL NHL MLB]).empty?
  ChampionshipAlignmentCapture.new(**options).call
end
