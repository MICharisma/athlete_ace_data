require "digest"
require "fileutils"
require "json"
require "net/http"
require "uri"

# Captures the 2026 Formula One season from Jolpica-F1, the Ergast-compatible
# successor to the Ergast API: calendar, circuits, constructors, drivers, and
# every published race and sprint result. Writes one normalized capture.
#
#   ruby scripts/capture_f1_2026.rb --as-of YYYY-MM-DD [--refresh]
class F12026Capture
  ROOT = File.expand_path("..", __dir__)
  BASE = "https://api.jolpi.ca/ergast/f1".freeze
  SEASON = "2026".freeze
  CACHE = File.join(ROOT, "sources/.http-cache/f1_2026")
  OUTPUT = File.join(ROOT, "sources/f1_2026/season.json")
  PAGE = 100

  def initialize(as_of:, refresh: false)
    @as_of, @refresh = as_of, refresh
  end

  def fetch(path, offset: 0)
    url = "#{BASE}/#{path}.json?limit=#{PAGE}&offset=#{offset}"
    cache = File.join(CACHE, "#{Digest::SHA256.hexdigest(url)}.json")
    body = if File.file?(cache) && !@refresh
      File.read(cache, encoding: "UTF-8")
    else
      sleep 0.5 # Jolpica's published burst limit is four requests a second.
      response = Net::HTTP.get_response(URI(url))
      raise "#{url} returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      FileUtils.mkdir_p(CACHE)
      File.write(cache, response.body)
      response.body.force_encoding("UTF-8")
    end
    JSON.parse(body).fetch("MRData")
  end

  # Every page of a table, checked against the advertised total.
  def all(path, table, key)
    rows = []
    offset = 0
    loop do
      data = fetch(path, offset: offset)
      page = data.fetch(table).fetch(key)
      raise "#{path} returned season #{data.dig(table, 'season')}" if data.dig(table, "season") && data.dig(table, "season") != SEASON
      rows.concat(page)
      offset += PAGE
      break if offset >= data.fetch("total").to_i
    end
    rows
  end

  # Results tables nest result rows under races; count rows, not races.
  def results(path, key)
    rows = []
    offset = 0
    total = nil
    loop do
      data = fetch(path, offset: offset)
      raise "#{path} returned season #{data.dig('RaceTable', 'season')}" unless data.dig("RaceTable", "season") == SEASON
      total = data.fetch("total").to_i
      data.dig("RaceTable", "Races").each do |race|
        race.fetch(key).each { |row| rows << [ race.fetch("round"), row ] }
      end
      offset += PAGE
      break if offset >= total
    end
    raise "#{path}: #{rows.size} rows, total #{total}" unless rows.size == total
    rows
  end

  def run
    races = all(SEASON, "RaceTable", "Races")
    circuits = all("#{SEASON}/circuits", "CircuitTable", "Circuits")
    constructors = all("#{SEASON}/constructors", "ConstructorTable", "Constructors")
    drivers = all("#{SEASON}/drivers", "DriverTable", "Drivers")
    rounds = races.map { |race| race.fetch("round") }
    raise "Rounds are not 1..#{rounds.size}" unless rounds == (1..rounds.size).map(&:to_s)
    scheduled = races.map { |race| race.dig("Circuit", "circuitId") }.uniq
    missing = scheduled - circuits.map { |row| row.fetch("circuitId") }
    raise "Calendar circuits missing from the circuit table: #{missing.join(', ')}" if missing.any?
    # The circuit table can keep circuits whose races were dropped from the calendar.
    unscheduled = circuits.map { |row| row.fetch("circuitId") } - scheduled
    circuits = circuits.select { |row| scheduled.include?(row.fetch("circuitId")) }

    result_rows = { "race" => results("#{SEASON}/results", "Results"), "sprint" => results("#{SEASON}/sprint", "SprintResults") }
    known_drivers = drivers.map { |row| row.fetch("driverId") }
    known_constructors = constructors.map { |row| row.fetch("constructorId") }
    normalized = result_rows.flat_map do |session, rows|
      rows.map do |round, row|
        driver, constructor = row.dig("Driver", "driverId"), row.dig("Constructor", "constructorId")
        raise "Unknown driver #{driver} in round #{round}" unless known_drivers.include?(driver)
        raise "Unknown constructor #{constructor} in round #{round}" unless known_constructors.include?(constructor)
        raise "Sprint result for round #{round}, which has no sprint" if session == "sprint" && !races[round.to_i - 1].key?("Sprint")
        { "round" => round.to_i, "session" => session, "driver_id" => driver, "constructor_id" => constructor,
          "number" => row.fetch("number"), "position" => row.fetch("position").to_i, "position_text" => row.fetch("positionText"),
          "points" => row.fetch("points"), "grid" => row.fetch("grid").to_i, "laps" => row.fetch("laps").to_i, "status" => row.fetch("status") }
      end
    end
    normalized.group_by { |row| [ row.fetch("round"), row.fetch("session") ] }.each do |(round, session), rows|
      raise "Round #{round} #{session} lists #{rows.size} results" unless rows.size == 22
      raise "Round #{round} #{session} repeats a driver" unless rows.map { |row| row.fetch("driver_id") }.uniq.size == rows.size
    end

    document = {
      "provider" => "jolpica", "league" => "F1", "season" => SEASON, "as_of" => @as_of, "source_url" => "#{BASE}/#{SEASON}.json",
      "meaning" => "Jolpica-F1 calendar, circuits, constructors and drivers for the 2026 season, with every published race and sprint result as of the capture date. The driver table includes practice and reserve drivers; only drivers with race or sprint results are race entrants. Races after the capture date have no results.",
      "races" => races.map do |race|
        { "round" => race.fetch("round").to_i, "race_name" => race.fetch("raceName"), "date" => race.fetch("date"), "time" => race["time"],
          "circuit_id" => race.dig("Circuit", "circuitId"), "url" => race["url"],
          "sprint" => race["Sprint"] && { "date" => race.dig("Sprint", "date"), "time" => race.dig("Sprint", "time") } }.compact
      end,
      "circuits" => circuits.map do |circuit|
        location = circuit.fetch("Location")
        { "circuit_id" => circuit.fetch("circuitId"), "name" => circuit.fetch("circuitName"), "locality" => location.fetch("locality"),
          "country" => location.fetch("country"), "lat" => location["lat"], "long" => location["long"], "url" => circuit["url"] }
      end.sort_by { |row| row.fetch("circuit_id") },
      "unscheduled_circuits" => unscheduled.sort,
      "constructors" => constructors.map { |row| { "constructor_id" => row.fetch("constructorId"), "name" => row.fetch("name"), "nationality" => row["nationality"], "url" => row["url"] } }.sort_by { |row| row.fetch("constructor_id") },
      "drivers" => drivers.map do |row|
        { "driver_id" => row.fetch("driverId"), "given_name" => row.fetch("givenName"), "family_name" => row.fetch("familyName"),
          "code" => row["code"], "permanent_number" => row["permanentNumber"], "date_of_birth" => row["dateOfBirth"],
          "nationality" => row["nationality"], "url" => row["url"] }
      end.sort_by { |row| row.fetch("driver_id") },
      "results" => normalized.sort_by { |row| [ row.fetch("round"), row.fetch("session") == "race" ? 1 : 0, row.fetch("position") ] }
    }
    FileUtils.mkdir_p(File.dirname(OUTPUT))
    File.write(OUTPUT, JSON.pretty_generate(document) + "\n")
    completed = document.fetch("results").map { |row| [ row.fetch("round"), row.fetch("session") ] }.uniq.group_by(&:last).transform_values(&:size)
    puts({ races: races.size, circuits: circuits.size, constructors: constructors.size, drivers: drivers.size,
      entrants: document.fetch("results").map { |row| row.fetch("driver_id") }.uniq.size, completed_sessions: completed }.to_json)
  end
end

if $PROGRAM_NAME == __FILE__
  as_of = ARGV.index("--as-of")&.then { |index| ARGV.delete_at(index); ARGV.delete_at(index) }
  refresh = ARGV.delete("--refresh")
  abort "Usage: ruby scripts/capture_f1_2026.rb --as-of YYYY-MM-DD [--refresh]" unless as_of&.match?(/\A\d{4}-\d{2}-\d{2}\z/) && ARGV.empty?
  F12026Capture.new(as_of: as_of, refresh: refresh).run
end
