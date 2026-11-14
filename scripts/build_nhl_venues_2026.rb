require "fileutils"
require "json"
require "yaml"
require_relative "../../../../lib/micharisma_seeders/lib/micharisma_seeders"
require_relative "capture_nhl_venues_2026"
require_relative "lib/seed_catalog"

# Builds venue and side bindings for every 2026-27 NHL schedule game, plus the
# geography for venues outside the home-venue capture, offline from:
#   sources/coverage_2026/nhl.json        (schedule: venue name, home, away)
#   sources/geography_2026/*.json         (each team's bound home venues)
#   sources/nhl_venues_2026/venues.json   (reviewed aliases and new places)
#   sources/nhl_venues_2026/offsite.json  (NHL landing records for off-site games)
# The application's Seeds::GameVenueImporter fills missing venues and sides
# from bindings.json and reports differences. --check fails on drift.
class NhlVenues2026Builder
  ROOT = File.expand_path("..", __dir__)
  SOURCES = File.join(ROOT, "sources/nhl_venues_2026")
  GEOGRAPHY = File.join(ROOT, "yaml/nhl_venues_2026/geography.yaml")
  BINDINGS = File.join(SOURCES, "bindings.json")
  SEASON = "HCK-NHL-SEASON_2026_2027".freeze

  def initialize(check: false)
    @check = check
    @writer = SeedCatalog::Writer.new(check: check)
    @schedule = read("sources/coverage_2026/nhl.json")
    @registry = read("sources/nhl_venues_2026/venues.json")
    @offsite = read("sources/nhl_venues_2026/offsite.json")
    @home_names = NhlVenues2026Capture.home_venue_names(read("sources/geography_2026/bindings.json"), read("sources/geography_2026/venues.json"), @registry)
    registry = MICharismaSeeders::SequenceRegistry.read(File.join(ROOT, "yaml/entity_sequences.yaml"))
    reader = MICharismaSeeders::Reader.new(registry: registry)
    @known = {}
    @entries = {}
    Dir.glob(File.join(ROOT, "yaml/**/*.{yaml,yml,json}")).reject { |path| path.include?("/nhl_venues_2026/") || path.end_with?("entity_sequences.yaml") }
      .flat_map { |path| reader.read(path) }.each do |row|
        ([ row.code ] + row.aliases).each { |code| @known[code] = row.type }
        @entries[row.code] = row.references.fetch("campaign") if row.type == "Contestant" && row.code.start_with?("HCK-NHL-GAME_")
      end
  end

  def read(path)
    JSON.parse(File.read(File.join(ROOT, path), encoding: "UTF-8"))
  end

  def write(path, contents)
    if @check
      raise "Generated file differs: #{path}" unless File.file?(path) && File.read(path, encoding: "UTF-8") == contents
    else
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, contents)
    end
  end

  def city_code(venue)
    "CITY-#{venue.fetch('country')}-#{venue.fetch('subdivision')}-#{token(venue.fetch('city'))}"
  end

  def token(value)
    value.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").upcase.gsub(/[^A-Z0-9]+/, "_").gsub(/\A_|_\z/, "")
  end

  def geography
    records = []
    @registry.fetch("countries").each do |country|
      records << { "type" => "Country", "code" => "COUNTRY-#{country.fetch('code')}",
        "attributes" => { "name" => country.fetch("name"), "abbreviation" => country.fetch("code") }, "references" => {},
        "source" => { "url" => country.fetch("source") } }
    end
    @registry.fetch("subdivisions").each do |subdivision|
      records << { "type" => "State", "code" => "STATE-#{subdivision.fetch('country')}-#{subdivision.fetch('code')}",
        "attributes" => { "name" => subdivision.fetch("name"), "abbreviation" => subdivision.fetch("code") },
        "references" => { "country" => "COUNTRY-#{subdivision.fetch('country')}" }, "source" => { "url" => subdivision.fetch("source") } }
    end
    @registry.fetch("venues").each do |venue|
      observed = @offsite.fetch("games").select { |game| game.fetch("venue") == venue.fetch("name") }
      raise "No captured games at #{venue.fetch('name')}" if observed.empty?
      locations = observed.map { |game| game.fetch("venue_location") }.uniq
      raise "#{venue.fetch('name')} locality #{locations.inspect} disagrees with #{venue.fetch('city')}" unless locations == [ venue.fetch("city") ]
      source = { "url" => observed.first.fetch("source_url"), "captured_on" => @offsite.fetch("as_of"), "note" => venue.fetch("basis") }
      state = "STATE-#{venue.fetch('country')}-#{venue.fetch('subdivision')}"
      records << { "type" => "City", "code" => city_code(venue), "attributes" => { "name" => venue.fetch("city") }, "references" => { "state" => state }, "source" => source }
      records << { "type" => "Stadium", "code" => venue.fetch("code"), "attributes" => { "name" => venue.fetch("name") }, "references" => { "city" => city_code(venue) }, "source" => source }
    end
    document = { "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA",
      "source" => { "note" => "Places for NHL 2026-27 venues outside the home-venue capture. Localities come from NHL landing records; subdivisions from ISO 3166-2." },
      "records" => records }
    @writer.write_batch(GEOGRAPHY, document) # All identities: they go to the catalog.
    records
  end

  def run
    raise "Unexpected NHL season" unless @schedule.fetch("season") == "2026_2027"
    offsite = @registry.fetch("venues").to_h { |venue| [ venue.fetch("name"), venue.fetch("code") ] }
    captured = @offsite.fetch("games").to_h { |game| [ game.fetch("source_id"), game ] }
    new_places = geography
    counts = Hash.new(0)
    games = @schedule.fetch("games").map do |game|
      code = "HCK-NHL-GAME_#{game.fetch('source_id')}"
      raise "Missing game #{code}" unless @known[code] == "Game"
      home_stadium = @home_names.fetch(game.fetch("home"))[game.fetch("venue").downcase]
      if home_stadium
        raise "#{code} was captured as off-site but plays at a home venue" if captured.key?(game.fetch("source_id"))
        stadium, basis = home_stadium, "home_team_venue"
      else
        raise "#{code} plays at #{game.fetch('venue').inspect}, which has no capture" unless captured.key?(game.fetch("source_id"))
        stadium = offsite[game.fetch("venue")] or raise "#{code} venue #{game.fetch('venue').inspect} is not in the registry"
        basis = "offsite_capture"
      end
      raise "Unknown stadium #{stadium}" unless @known[stadium] == "Stadium" || new_places.any? { |row| row.fetch("code") == stadium }
      sides = %w[home away].to_h do |side|
        entry = "#{code}-#{side.upcase}"
        expected = "#{SEASON}-TEAM-#{game.fetch(side)}"
        raise "#{entry} enters #{@entries[entry].inspect}, not #{expected}" unless @entries[entry] == expected
        [ side, entry ]
      end
      counts[basis] += 1
      { "game" => code, "stadium" => stadium, "source_venue" => game.fetch("venue"), "basis" => basis,
        "home" => sides.fetch("home"), "away" => sides.fetch("away") }
    end
    document = { "as_of" => @offsite.fetch("as_of"), "schedule_captured_on" => @schedule.fetch("as_of"),
      "counts" => counts.sort.to_h.merge("games" => games.size, "stadiums" => games.map { |row| row.fetch("stadium") }.uniq.size), "games" => games }
    write(BINDINGS, JSON.pretty_generate(document) + "\n")
    @writer.finish(codes_path: File.join(SOURCES, "catalog_codes.json"))
    puts JSON.pretty_generate(document.fetch("counts"))
  end
end

if $PROGRAM_NAME == __FILE__
  check = ARGV.delete("--check")
  abort "Usage: ruby scripts/build_nhl_venues_2026.rb [--check]" unless ARGV.empty?
  NhlVenues2026Builder.new(check: check).run
end
