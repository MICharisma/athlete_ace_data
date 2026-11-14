require "fileutils"
require "json"
require "yaml"
require_relative "../../../../lib/micharisma_seeders/lib/micharisma_seeders"
require_relative "lib/seed_catalog"

# Builds the 2026 Formula One manifests offline from sources/f1_2026:
#   season.json    Jolpica-F1 capture (calendar, circuits, constructors, drivers, results)
#   circuits.json  reviewed circuit countries, ISO 3166-2 subdivisions and city bindings
# Motorsport is one sport with each series as a League; F1 is the first.
# Every Grand Prix and sprint is a Game at its circuit inside the season's
# championship. --check fails when committed output differs.
class F12026Builder
  ROOT = File.expand_path("..", __dir__)
  SOURCES = File.join(ROOT, "sources/f1_2026")
  OUTPUT = File.join(ROOT, "yaml/f1_2026")
  SPORT = "SPORT-MOT".freeze
  LEAGUE = "MOT-LEAGUE-F1".freeze
  FEDERATION = "FEDERATION-FIA".freeze
  REQUIRED = %w[YEAR-2026].freeze

  def initialize(check: false)
    @check = check
    @writer = SeedCatalog::Writer.new(check: check)
    @capture = read("season.json")
    @circuits = read("circuits.json")
    registry = MICharismaSeeders::SequenceRegistry.read(File.join(ROOT, "yaml/entity_sequences.yaml"))
    reader = MICharismaSeeders::Reader.new(registry: registry)
    @known = {}
    Dir.glob(File.join(ROOT, "yaml/**/*.{yaml,yml,json}")).reject { |path| path.include?("/f1_2026/") || path.end_with?("entity_sequences.yaml") }
      .flat_map { |path| reader.read(path) }.each { |row| ([ row.code ] + row.aliases).each { |code| @known[code] = row.type } }
    missing = REQUIRED.reject { |code| @known.key?(code) }
    raise "Missing catalog parents: #{missing.join(', ')}" if missing.any?
    raise "Unexpected season #{@capture.fetch('season')}" unless @capture.fetch("season") == "2026"
    @season = "MOT-F1-SEASON_#{@capture.fetch('season')}"
    @source = { "url" => @capture.fetch("source_url"), "captured_on" => @capture.fetch("as_of"), "note" => @capture.fetch("meaning") }
    @report = { "as_of" => @capture.fetch("as_of") }
  end

  def read(name)
    JSON.parse(File.read(File.join(SOURCES, name), encoding: "UTF-8"))
  end

  def token(value)
    value.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").upcase.gsub(/[^A-Z0-9]+/, "_").gsub(/\A_|_\z/, "")
  end

  def record(type, code, attributes = {}, references = {}, source: nil, aliases: nil)
    row = { "type" => type, "code" => code, "attributes" => attributes, "references" => references }
    row["aliases"] = aliases if aliases
    row["source"] = source if source
    row
  end

  def write(name, records, source:)
    document = { "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "source" => source, "records" => records }
    @writer.write_batch(File.join(OUTPUT, name), document) # Identities go to the catalog.
  end

  # Every record this batch owns, whether or not the catalog already has it:
  # the catalog writer merges equal definitions, so output never depends on
  # catalog state. Places owned elsewhere (Canada, Texas, Austin) are only referenced.
  def add_new(records, row)
    prior = records.find { |other| other.fetch("code") == row.fetch("code") }
    return if prior == row # A second circuit in the same country or subdivision.
    raise "#{row.fetch('code')} is defined twice with different values" if prior
    records << row
  end

  def team_code(constructor_id) = "MOT-F1-TEAM-#{token(constructor_id)}"
  def campaign_code(constructor_id) = "#{@season}-TEAM-#{token(constructor_id)}"
  def game_code(round, session) = "#{@season}-ROUND_#{format('%02d', round)}-#{session.upcase}"

  def session_date(race, session)
    session == "sprint" ? race.fetch("sprint").fetch("date") : race.fetch("date")
  end

  def foundation
    records = []
    add_new(records, record("Sport", SPORT, { "name" => "Motorsport" }))
    add_new(records, record("Federation", FEDERATION, { "name" => "Fédération Internationale de l'Automobile", "abbreviation" => "FIA", "url" => "https://www.fia.com/" }))
    add_new(records, record("League", LEAGUE, { "name" => "Formula One World Championship", "abbreviation" => "F1", "url" => "https://www.formula1.com/" },
      { "sport" => SPORT, "jurisdiction" => FEDERATION }))
    add_new(records, record("Season", @season, { "label" => @capture.fetch("season"), "start_date" => @capture.fetch("races").first.fetch("date") },
      { "league" => LEAGUE, "year" => "YEAR-#{@capture.fetch('season')}" }, source: @source))

    @stadiums = {}
    iso = @circuits.fetch("iso_source")
    @capture.fetch("circuits").each do |circuit|
      review = @circuits.fetch("circuits").fetch(circuit.fetch("circuit_id")) { raise "Circuit #{circuit.fetch('circuit_id')} has no review" }
      country = @circuits.fetch("provider_countries").fetch(circuit.fetch("country"), nil) || @circuits.fetch("countries").key(circuit.fetch("country"))
      raise "#{circuit.fetch('circuit_id')}: provider country #{circuit.fetch('country')} disagrees with review #{review.fetch('country')}" unless country == review.fetch("country")
      country_code = "COUNTRY-#{country}"
      if @circuits.fetch("countries").key?(country)
        add_new(records, record("Country", country_code, { "name" => @circuits.fetch("countries").fetch(country), "abbreviation" => country }, {}, source: { "url" => "#{iso}#{country}" }))
      end
      state = "STATE-#{country}-#{review.fetch('subdivision')}"
      if review.key?("subdivision_name")
        add_new(records, record("State", state, { "name" => review.fetch("subdivision_name"), "abbreviation" => review.fetch("subdivision") },
          { "country" => country_code }, source: { "url" => "#{iso}#{country}" }))
      end
      circuit_source = { "url" => "#{File.dirname(@capture.fetch('source_url'))}/circuits/#{circuit.fetch('circuit_id')}.json", "captured_on" => @capture.fetch("as_of") }
      city = review["city_code"]
      if city
        raise "Reviewed city #{city} is not in the catalog" unless @known[city] == "City"
        raise "#{city} is not in #{state}" unless city.start_with?("CITY-#{country}-#{review.fetch('subdivision')}-")
      else
        city = "CITY-#{country}-#{review.fetch('subdivision')}-#{token(circuit.fetch('locality'))}"
        add_new(records, record("City", city, { "name" => circuit.fetch("locality") }, { "state" => state }, source: circuit_source))
      end
      stadium = "STADIUM-#{city.delete_prefix('CITY-')}-#{token(circuit.fetch('name'))}"
      add_new(records, record("Stadium", stadium, { "name" => circuit.fetch("name"), "url" => circuit.fetch("url") }, { "city" => city }, source: circuit_source))
      @stadiums[circuit.fetch("circuit_id")] = stadium
    end
    write("foundation.yaml", records, source: @source)
    @report["foundation"] = records.group_by { |row| row.fetch("type") }.transform_values(&:size)
  end

  def season
    races = @capture.fetch("races").to_h { |race| [ race.fetch("round"), race ] }
    results = @capture.fetch("results")
    entrants = results.map { |row| row.fetch("driver_id") }.uniq
    drivers = @capture.fetch("drivers").to_h { |driver| [ driver.fetch("driver_id"), driver ] }
    @players = entrants.sort.to_h do |driver_id|
      driver = drivers.fetch(driver_id)
      [ driver_id, "MOT-F1-PLAYER-#{token(driver.fetch('family_name'))}_#{token(driver.fetch('given_name'))}" ]
    end
    duplicates = @players.values.tally.select { |_, count| count > 1 }.keys
    raise "Driver code collisions need review: #{duplicates.join(', ')}" if duplicates.any?

    records = []
    constructors = @capture.fetch("constructors")
    constructors.each do |constructor|
      id = constructor.fetch("constructor_id")
      records << record("Team", team_code(id), { "mascot" => constructor.fetch("name") }, { "league" => LEAGUE },
        source: @source, aliases: [ "MOT-JOLPICA-CONSTRUCTOR_#{token(id)}" ])
      records << record("Campaign", campaign_code(id), { "display_name" => constructor.fetch("name") }, { "team" => team_code(id), "season" => @season }, source: @source)
    end
    @players.each do |driver_id, code|
      driver = drivers.fetch(driver_id)
      attributes = { "first_name" => driver.fetch("given_name"), "last_name" => driver.fetch("family_name"), "birthdate" => driver["date_of_birth"] }.compact
      records << record("Player", code, attributes, { "sport" => SPORT }, source: @source, aliases: [ "MOT-JOLPICA-DRIVER_#{token(driver_id)}" ])
    end
    results.map { |row| [ row.fetch("driver_id"), row.fetch("constructor_id") ] }.uniq.sort.each do |driver_id, constructor_id|
      player = @players.fetch(driver_id)
      records << record("Activation", "#{campaign_code(constructor_id)}-PLAYER-#{player.delete_prefix('MOT-F1-PLAYER-')}", {},
        { "player" => player, "campaign" => campaign_code(constructor_id) }, source: @source)
    end

    # Numbers as observed runs: consecutive sessions in calendar order with the same
    # driver, team and number. A run's bounds are its first and last observed session.
    sessions = results.map { |row| [ row.fetch("round"), row.fetch("session") ] }.uniq.sort_by { |round, session| [ round, session == "race" ? 1 : 0 ] }
    runs = []
    results.group_by { |row| row.fetch("driver_id") }.each do |driver_id, rows|
      by_session = rows.to_h { |row| [ [ row.fetch("round"), row.fetch("session") ], row ] }
      current = nil
      sessions.each do |session|
        row = by_session[session]
        key = row && [ row.fetch("constructor_id"), row.fetch("number") ]
        if key && current && current[:key] == key && current[:last_index] == sessions.index(session) - 1
          current[:last] = session
          current[:last_index] = sessions.index(session)
        elsif key
          current = { driver_id: driver_id, key: key, first: session, last: session, last_index: sessions.index(session) }
          runs << current
        else
          current = nil
        end
      end
    end
    runs.sort_by { |run| [ run[:driver_id], run[:first] ] }.each do |run|
      constructor_id, number = run[:key]
      from = session_date(races.fetch(run[:first][0]), run[:first][1])
      through = session_date(races.fetch(run[:last][0]), run[:last][1])
      player = @players.fetch(run[:driver_id])
      records << record("JerseyNumberAssignment", "#{team_code(constructor_id)}-PLAYER-#{player.delete_prefix('MOT-F1-PLAYER-')}-NUMBER_#{number}-FROM_#{from.tr('-', '_')}",
        { "number" => number, "start_date" => from, "end_date" => through,
          "details" => { "period_basis" => "observed_session_results", "note" => "Car number in every published race and sprint result from the first to the last session of this run. The actual assignment period may be longer." } },
        { "player" => player, "team" => team_code(constructor_id) }, source: @source)
    end
    write("season.yaml", records, source: @source)
    @report["season"] = records.group_by { |row| row.fetch("type") }.transform_values(&:size)
    @report["number_runs"] = runs.group_by { |run| run[:driver_id] }.select { |_, list| list.size > 1 || list.first[:key] != runs.find { |r| r[:driver_id] == list.first[:driver_id] }[:key] }
      .transform_values { |list| list.map { |run| "#{run[:key][0]} ##{run[:key][1]} rounds #{run[:first][0]}-#{run[:last][0]}" } }.sort.to_h
  end

  def number(value)
    value.include?(".") ? value.to_f : value.to_i
  end

  def races
    records = []
    championship = "#{@season}-CHAMPIONSHIP"
    calendar = @capture.fetch("races")
    records << record("Contest", championship, { "name" => "#{@capture.fetch('season')} FIA Formula One World Championship", "kind" => "championship",
      "begin_date" => calendar.first.fetch("date"), "end_date" => calendar.last.fetch("date") }, { "context" => LEAGUE, "season" => @season }, source: @source)
    @capture.fetch("constructors").each do |constructor|
      id = constructor.fetch("constructor_id")
      records << record("Contestant", "#{championship}-TEAM-#{token(id)}", {}, { "contest" => championship, "campaign" => campaign_code(id) })
    end
    results = @capture.fetch("results").group_by { |row| [ row.fetch("round"), row.fetch("session") ] }
    counts = Hash.new(0)
    calendar.each do |race|
      round = race.fetch("round")
      sessions = race.key?("sprint") ? %w[sprint race] : %w[race]
      sessions.each do |session|
        code = game_code(round, session)
        date = session_date(race, session)
        time = session == "sprint" ? race.fetch("sprint")["time"] : race["time"]
        name = session == "sprint" ? "#{race.fetch('race_name')} Sprint" : race.fetch("race_name")
        details = { "provider" => "jolpica", "round" => round, "session" => session, "start_time_utc" => (time && "#{date}T#{time}") }.compact
        records << record("Game", code, { "name" => name, "begin_date" => date, "end_date" => date, "details" => details },
          { "context" => LEAGUE, "season" => @season, "stadium" => @stadiums.fetch(race.fetch("circuit_id")) },
          source: { "url" => race.fetch("url", @capture.fetch("source_url")), "captured_on" => @capture.fetch("as_of") })
        metadata = { "round" => "round_#{round}" }
        metadata["series"] = "Sprint" if session == "sprint"
        records << record("ContestGame", "#{code}-CHAMPIONSHIP", { "metadata" => metadata }, { "contest" => championship, "game" => code })
        rows = results.fetch([ round, session ], [])
        counts[rows.empty? ? "#{session}_scheduled" : "#{session}_with_results"] += 1
        rows.map { |row| row.fetch("constructor_id") }.uniq.sort.each do |id|
          records << record("Contestant", "#{code}-TEAM-#{token(id)}", {}, { "contest" => code, "campaign" => campaign_code(id) })
        end
        rows.sort_by { |row| row.fetch("position") }.each do |row|
          player = @players.fetch(row.fetch("driver_id"))
          statistics = { "finish_position" => row.fetch("position"), "position_text" => row.fetch("position_text"), "grid" => row.fetch("grid"),
            "laps" => row.fetch("laps"), "points" => number(row.fetch("points")), "status" => row.fetch("status") }
          records << record("Appearance", "#{code}-PLAYER-#{player.delete_prefix('MOT-F1-PLAYER-')}", { "jersey_number" => row.fetch("number"), "statistics" => statistics },
            { "player" => player, "contestant" => "#{code}-TEAM-#{token(row.fetch('constructor_id'))}" })
        end
      end
    end
    write("races.yaml", records, source: @source)
    @report["races"] = records.group_by { |row| row.fetch("type") }.transform_values(&:size).merge("sessions" => counts.sort.to_h)
  end

  def run
    foundation
    season
    races
    @writer.finish(codes_path: File.join(SOURCES, "catalog_codes.json"))
    report = JSON.pretty_generate(@report) + "\n"
    path = File.join(SOURCES, "report.json")
    if @check
      raise "Generated report differs" unless File.file?(path) && File.read(path, encoding: "UTF-8") == report
    else
      File.write(path, report)
    end
    puts report
  end
end

if $PROGRAM_NAME == __FILE__
  check = ARGV.delete("--check")
  abort "Usage: ruby scripts/build_f1_2026.rb [--check]" unless ARGV.empty?
  F12026Builder.new(check: check).run
end
