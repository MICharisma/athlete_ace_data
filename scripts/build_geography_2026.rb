require_relative "build_2026"

class Geography2026Builder
  ROOT = Sports2026Builder::ROOT
  COUNTS = { "NBA" => 30, "NFL" => 32, "MLB" => 30, "NHL" => 32, "MLS" => 30, "EPL" => 20 }.freeze

  def initialize(check: false)
    @check = check
    @records = {}
  end

  def add(type, code, attributes, references, source)
    record = { "type" => type, "code" => code, "attributes" => attributes, "references" => references, "source" => source }
    prior = @records[code]
    raise "Contradictory geography: #{code}" if prior && prior.except("source") != record.except("source")
    @records[code] ||= record
  end

  def token(value)
    value.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").upcase.gsub(/[^A-Z0-9]+/, "_").gsub(/\A_|_\z/, "")
  end

  def write(relative, content)
    path = File.join(ROOT, relative)
    if @check
      raise "Generated file differs: #{path}" unless File.file?(path) && File.read(path) == content
    else
      File.write(path, content)
    end
  end

  def call
    capture = JSON.parse(File.read(File.join(ROOT, "sources/geography_2026/home_venues.json")))
    registry = JSON.parse(File.read(File.join(ROOT, "sources/geography_2026/venues.json")))
    as_of = Date.iso8601(capture.fetch("as_of")).iso8601
    raise "Geography review predates this capture" unless registry.fetch("as_of") == as_of
    expected = COUNTS.transform_keys(&:to_s)
    actual = capture.fetch("teams").group_by { |row| row.fetch("league") }.transform_values(&:size)
    raise "Incomplete league coverage: #{actual}" unless actual == expected

    lookup = {}
    registry.fetch("venues").each do |venue|
      venue.fetch("observations").each do |observation|
        key = observation.values_at("league", "team_id", "name")
        raise "Duplicate venue binding: #{key}" if lookup.key?(key)
        lookup[key] = venue
      end
    end
    countries = { "US" => "United States", "CA" => "Canada", "GB" => "United Kingdom" }
    countries.each do |code, name|
      add("Country", "COUNTRY-#{code}", { "name" => name, "abbreviation" => code }, {},
        { "url" => code == "CA" ? "https://www.canada.ca/" : code == "GB" ? "https://www.gov.uk/" : "https://www.usa.gov/about-the-us" })
    end
    catalog = Sports2026Builder.new(check: true)
    bindings = capture.fetch("teams").map do |row|
      league = row.fetch("league")
      roster = JSON.parse(File.read(File.join(ROOT, "sources/coverage_2026/#{league.downcase}.json")))
      raise "Wrong season for #{league}" unless row.fetch("season") == roster.fetch("season")
      team = roster.fetch("teams").select { |entry| entry.fetch("source_id").to_s == row.fetch("team_id") }
      raise "No unique roster identity for #{row.fetch('team')}" unless team.one?
      source = { "url" => row.fetch("url"), "captured_on" => as_of }
      observations = row.fetch("venues").map do |observation|
        raw = observation.fetch("venue")
        name = raw.fetch("fullName", raw["name"])
        venue = lookup.fetch([ league, row.fetch("team_id"), name ])
        country, state, city = venue.values_at("country", "state", "city")
        state_code = "STATE-#{country}-#{state}"
        city_code = "CITY-#{country}-#{state}-#{token(city)}"
        venue_source = source.merge(venue.fetch("review", {}).slice("url", "note"))
        add("State", state_code, { "name" => registry.fetch("subdivisions").fetch(country).fetch(state), "abbreviation" => state },
          { "country" => "COUNTRY-#{country}" }, { "url" => registry.fetch("subdivision_sources").fetch(country) })
        add("City", city_code, { "name" => city }, { "state" => state_code }, venue_source)
        add("Stadium", venue.fetch("code"), { "name" => venue.fetch("name") }, { "city" => city_code }, venue_source)
        { "stadium" => venue.fetch("code"), "city" => city_code, "observations" => observation.fetch("observations", []).size }
      end
      ranked = observations.sort_by { |entry| [ -entry.fetch("observations"), entry.fetch("stadium") ] }
      raise "Ambiguous primary venue for #{row.fetch('team')}" if ranked.size > 1 && ranked[0].fetch("observations") == ranked[1].fetch("observations")
      primary = ranked.first
      code = catalog.team_code(roster, team.first)
      season = "#{Sports2026Builder::SPORTS.fetch(league)}-#{league}-SEASON_#{row.fetch('season')}"
      { "league" => league, "team" => code, "season" => season, "campaign" => "#{season}-TEAM-#{code.split('-TEAM-').last}",
        "stadium" => primary.fetch("stadium"), "city" => primary.fetch("city"), "venues" => ranked, "source" => source }
    end
    raise "Duplicate team or campaign bindings" unless bindings.map { |row| row.fetch("team") }.uniq.size == 174 && bindings.map { |row| row.fetch("campaign") }.uniq.size == 174
    records = @records.values.sort_by { |row| [ %w[Country State City Stadium].index(row.fetch("type")), row.fetch("code") ] }
    document = { "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "records" => records }
    writer = SeedCatalog::Writer.new(check: @check)
    writer.write_batch(File.join(ROOT, "yaml/coverage_2026/geography.yaml"), document) # All places: they go to the catalog.
    writer.finish(codes_path: File.join(ROOT, "sources/coverage_2026/catalog_codes_geography.json"))
    report = { "as_of" => as_of, "counts" => records.group_by { |row| row.fetch("type") }.transform_values(&:size), "teams" => bindings }
    write("sources/geography_2026/bindings.json", JSON.pretty_generate(report) + "\n")
    puts JSON.generate(report.fetch("counts").merge("home_venue_bindings" => bindings.size))
  end
end

if $PROGRAM_NAME == __FILE__
  abort "Usage: ruby #{$PROGRAM_NAME} [--check]" unless ARGV.empty? || ARGV == [ "--check" ]
  Geography2026Builder.new(check: ARGV.include?("--check")).call
end
