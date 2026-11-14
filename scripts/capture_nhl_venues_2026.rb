require "digest"
require "fileutils"
require "json"
require "net/http"
require "uri"

# Captures the NHL gamecenter landing record for every 2026-27 game whose
# source venue is not one of the home team's bound venues (or a reviewed
# alias for one). Those are the games played away from home: the venue's
# locality has to come from the source before a stadium can be issued.
#
#   ruby scripts/capture_nhl_venues_2026.rb --as-of YYYY-MM-DD [--refresh]
class NhlVenues2026Capture
  ROOT = File.expand_path("..", __dir__)
  CACHE = File.join(ROOT, "sources/.http-cache/nhl_venues_2026")
  OUTPUT = File.join(ROOT, "sources/nhl_venues_2026/offsite.json")

  def initialize(as_of:, refresh: false)
    @as_of, @refresh = as_of, refresh
    @schedule = read("sources/coverage_2026/nhl.json")
    @registry = read("sources/nhl_venues_2026/venues.json")
    @home_names = self.class.home_venue_names(read("sources/geography_2026/bindings.json"), read("sources/geography_2026/venues.json"), @registry)
  end

  def self.home_venue_names(bindings, venues, registry)
    by_code = venues.fetch("venues").to_h { |venue| [ venue.fetch("code"), venue ] }
    names = Hash.new { |hash, key| hash[key] = {} }
    bindings.fetch("teams").select { |team| team.fetch("league") == "NHL" }.each do |team|
      abbreviation = team.fetch("team").split("-").last
      team.fetch("venues").each do |bound|
        venue = by_code.fetch(bound.fetch("stadium"))
        ([ venue.fetch("name") ] + venue.fetch("observations").map { |row| row.fetch("name") }).each do |name|
          names[abbreviation][name.downcase] = venue.fetch("code")
        end
      end
    end
    registry.fetch("aliases").each { |row| names[row.fetch("home")][row.fetch("name").downcase] = row.fetch("stadium") }
    names
  end

  def read(path)
    JSON.parse(File.read(File.join(ROOT, path), encoding: "UTF-8"))
  end

  def fetch(url)
    path = File.join(CACHE, "#{Digest::SHA256.hexdigest(url)}.json")
    return File.read(path, encoding: "UTF-8") if File.file?(path) && !@refresh
    response = Net::HTTP.get_response(URI(url))
    raise "#{url} returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    FileUtils.mkdir_p(CACHE)
    File.write(path, response.body)
    response.body.force_encoding("UTF-8")
  end

  def run
    raise "Unexpected NHL season" unless @schedule.fetch("season") == "2026_2027"
    games = @schedule.fetch("games").reject { |game| @home_names.fetch(game.fetch("home")).key?(game.fetch("venue").downcase) }
    captured = games.map do |game|
      landing = JSON.parse(fetch(game.fetch("source_url")))
      raise "#{game.fetch('source_id')} landing returned game #{landing['id']}" unless landing.fetch("id").to_s == game.fetch("source_id")
      raise "#{game.fetch('source_id')} venue changed" unless landing.dig("venue", "default") == game.fetch("venue")
      teams = [ landing.dig("awayTeam", "abbrev"), landing.dig("homeTeam", "abbrev") ]
      raise "#{game.fetch('source_id')} teams changed" unless teams == [ game.fetch("away"), game.fetch("home") ]
      { "source_id" => game.fetch("source_id"), "date" => game.fetch("date"), "home" => game.fetch("home"), "away" => game.fetch("away"),
        "venue" => game.fetch("venue"), "venue_location" => landing.dig("venueLocation", "default"),
        "venue_utc_offset" => landing["venueUTCOffset"], "source_url" => game.fetch("source_url") }
    end
    document = { "provider" => "nhl", "league" => "NHL", "season" => "2026_2027", "as_of" => @as_of,
      "meaning" => "NHL gamecenter landing records for every 2026-27 schedule game whose venue is not a bound home venue of the home team. Venue and locality as published; no attendance or neutral-site designation is asserted.",
      "games" => captured }
    FileUtils.mkdir_p(File.dirname(OUTPUT))
    File.write(OUTPUT, JSON.pretty_generate(document) + "\n")
    puts({ games: captured.size, venues: captured.map { |game| [ game.fetch("venue"), game.fetch("venue_location") ] }.uniq }.to_json)
  end
end

if $PROGRAM_NAME == __FILE__
  as_of = ARGV.index("--as-of")&.then { |index| ARGV.delete_at(index); ARGV.delete_at(index) }
  refresh = ARGV.delete("--refresh")
  abort "Usage: ruby scripts/capture_nhl_venues_2026.rb --as-of YYYY-MM-DD [--refresh]" unless as_of&.match?(/\A\d{4}-\d{2}-\d{2}\z/) && ARGV.empty?
  NhlVenues2026Capture.new(as_of: as_of, refresh: refresh).run
end
