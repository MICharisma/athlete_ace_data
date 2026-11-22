require "date"
require "json"
require "time"
require_relative "lib/seed_catalog"

# Records each team's current home tenancy from the 2026 home venue capture.
# Like a current roster capture, this records current knowledge, not the date
# a team moved in: a tenancy starts on the first observed home game at the
# team's primary venue in the captured season (US Eastern date) and stays
# open. MLB's season venue listing has no games, so an MLB tenancy starts on
# the 2026 MLB opener from the season date capture.
class Tenancies2026Builder
  ROOT = File.expand_path("..", __dir__)
  GEOGRAPHY = File.join(ROOT, "sources/geography_2026")
  MLB_SEASON = "BSB-MLB-SEASON_2026".freeze

  def initialize(check: false, output: File.join(ROOT, "yaml/tenancies/current_2026.yml"))
    @output = output
    @writer = SeedCatalog::Writer.new(check: check)
  end

  def call
    capture = read(File.join(GEOGRAPHY, "home_venues.json"))
    bindings = read(File.join(GEOGRAPHY, "bindings.json"))
    lookup = read(File.join(GEOGRAPHY, "venues.json")).fetch("venues").each_with_object({}) do |venue, result|
      venue.fetch("observations").each { |observation| result[observation.values_at("league", "team_id", "name")] = venue.fetch("code") }
    end
    mlb_opener = read(File.join(ROOT, "sources/season_dates/season_dates.json")).fetch("seasons")
      .find { it.fetch("season") == MLB_SEASON }&.fetch("first_game_date") or raise "No captured start date for #{MLB_SEASON}"
    rows, teams = capture.fetch("teams"), bindings.fetch("teams")
    raise "Capture and bindings list different teams" unless rows.size == teams.size

    records = rows.zip(teams).map do |row, binding|
      unless row.fetch("league") == binding.fetch("league") && binding.fetch("season").end_with?("-SEASON_#{row.fetch('season')}")
        raise "Capture and bindings disagree at #{binding.fetch('team')}"
      end
      venue = row.fetch("venues").find do |entry|
        raw = entry.fetch("venue")
        lookup.fetch([ row.fetch("league"), row.fetch("team_id"), raw.fetch("fullName", raw["name"]) ]) == binding.fetch("stadium")
      end or raise "No primary venue observations for #{binding.fetch('team')}"
      tenancy(binding, venue.fetch("observations", []), mlb_opener)
    end
    @writer.write_batch(@output, { "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "records" => records.sort_by { it.fetch("code") } })
    puts({ tenancies: records.size }.to_json)
  end

  private

  def tenancy(binding, observations, mlb_opener)
    first = observations.min_by { it.fetch("date") }
    if first
      start = eastern_date(first.fetch("date"))
      details = { "bounds" => "observed", "season" => binding.fetch("season"), "first_observed_event" => first.fetch("event_id") }
    else
      raise "No observed home games for #{binding.fetch('team')}" unless binding.fetch("season") == MLB_SEASON

      start = mlb_opener
      details = { "bounds" => "season_level", "season" => MLB_SEASON }
    end
    { "type" => "Tenancy", "code" => "#{binding.fetch('team')}-TENANCY-#{start.tr('-', '_')}",
      "attributes" => { "role" => "home", "start_date" => start, "details" => details,
        "source" => binding.fetch("source").merge("note" => "Current home venue. The start date is the first observation in this capture, not the date the team moved in.") },
      "references" => { "team" => binding.fetch("team"), "stadium" => binding.fetch("stadium") } }
  end

  def eastern_date(timestamp)
    previous, ENV["TZ"] = ENV["TZ"], "America/New_York"
    Time.parse(timestamp).localtime.to_date.iso8601
  ensure
    ENV["TZ"] = previous
  end

  def read(path)
    JSON.parse(File.read(path, encoding: "UTF-8"))
  end
end

if $PROGRAM_NAME == __FILE__
  check = ARGV.delete("--check")
  abort "Usage: ruby scripts/build_tenancies_2026.rb [--check]" unless ARGV.empty?
  Tenancies2026Builder.new(check: check).call
end
