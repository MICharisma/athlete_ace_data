require "fileutils"
require "json"
require "yaml"
require_relative "../../../../lib/micharisma_seeders/lib/micharisma_seeders"

# Builds baseball and football position vocabularies, then attaches each
# player's source-listed 2026 roster position to the roster entries already
# seeded from sources/coverage_2026 for a few selected teams. Offline and
# deterministic; --check fails when committed output differs.
class PositionAssignments2026Builder
  ROOT = File.expand_path("..", __dir__)
  CAPTURES = File.join(ROOT, "sources/coverage_2026")
  REPORT = File.join(ROOT, "sources/position_assignments_2026/report.json")

  # [abbreviation, name, parent abbreviation]. Groups come before members.
  VOCABULARIES = {
    "BSB" => {
      file: "yaml/positions/baseball.yaml",
      note: "Baseball position vocabulary. Abbreviations match the MLB Stats API roster positions in sources/coverage_2026/mlb.json; IF and OF group the fielding positions.",
      positions: [
        %w[IF Infielder], %w[OF Outfielder],
        [ "P", "Pitcher" ], [ "C", "Catcher" ],
        [ "1B", "First Base", "IF" ], [ "2B", "Second Base", "IF" ], [ "3B", "Third Base", "IF" ], [ "SS", "Shortstop", "IF" ],
        [ "LF", "Left Field", "OF" ], [ "CF", "Center Field", "OF" ], [ "RF", "Right Field", "OF" ],
        [ "DH", "Designated Hitter" ], [ "TWP", "Two-Way Player" ]
      ]
    },
    "FTB" => {
      file: "yaml/positions/football.yaml",
      note: "Football position vocabulary. Abbreviations match the ESPN NFL roster positions in sources/coverage_2026/nfl.json; Offense, Defense and Special Teams, OL and DB group them.",
      positions: [
        [ "OFF", "Offense" ], [ "DEF", "Defense" ], [ "ST", "Special Teams" ],
        [ "OL", "Offensive Lineman", "OFF" ], [ "DB", "Defensive Back", "DEF" ],
        [ "QB", "Quarterback", "OFF" ], [ "RB", "Running Back", "OFF" ], [ "FB", "Fullback", "OFF" ],
        [ "WR", "Wide Receiver", "OFF" ], [ "TE", "Tight End", "OFF" ],
        [ "OT", "Offensive Tackle", "OL" ], [ "G", "Guard", "OL" ], [ "C", "Center", "OL" ],
        [ "DE", "Defensive End", "DEF" ], [ "DT", "Defensive Tackle", "DEF" ], [ "LB", "Linebacker", "DEF" ],
        [ "CB", "Cornerback", "DB" ], [ "S", "Safety", "DB" ],
        [ "PK", "Place Kicker", "ST" ], [ "P", "Punter", "ST" ], [ "LS", "Long Snapper", "ST" ]
      ]
    }
  }.freeze

  # capture => [sport token, league token, team abbreviations]
  SELECTIONS = {
    "mlb" => [ "BSB", "MLB", %w[LAD NYM] ],
    "nfl" => [ "FTB", "NFL", %w[CHI SF] ]
  }.freeze

  # Reviewed corrections: a source listing replaced by curated positions.
  # The build fails if the source stops listing the expected designation.
  SPLITS = {
    [ "mlb", "660271" ] => {
      listed: "TWP", positions: %w[P DH],
      note: "Reviewed correction: the source lists Shohei Ohtani as TWP (Two-Way Player). AthleteAce records the two roles that designation combines, pitcher and designated hitter. A roster designation, not a record of game appearances."
    }
  }.freeze

  def initialize(check: false)
    @check = check
    registry = MICharismaSeeders::SequenceRegistry.read(File.join(ROOT, "yaml/entity_sequences.yaml"))
    reader = MICharismaSeeders::Reader.new(registry: registry)
    paths = Dir.glob(File.join(ROOT, "yaml/**/*.{yaml,yml,json}"))
      .reject { |path| path.include?("/positions/") || path.include?("/position_assignments_2026/") || path.end_with?("entity_sequences.yaml") }
    @known = {}
    paths.flat_map { |path| reader.read(path) }.each { |row| ([ row.code ] + row.aliases).each { |code| @known[code] = row.type } }
    @report = { "vocabularies" => {}, "assignments" => {}, "splits" => [] }
  end

  def position_code(sport, abbreviation)
    "#{sport}-POSITION-#{abbreviation}"
  end

  def write(path, document)
    contents = YAML.dump(JSON.parse(JSON.generate(document)))
    if @check
      raise "Generated file differs: #{path}" unless File.file?(path) && File.read(path, encoding: "UTF-8") == contents
    else
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, contents)
    end
  end

  def envelope(source, records)
    { "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "source" => source, "records" => records }
  end

  def build_vocabulary(sport, spec)
    raise "Missing SPORT-#{sport}" unless @known["SPORT-#{sport}"] == "Sport"
    defined = {}
    records = spec.fetch(:positions).map do |abbreviation, name, parent|
      raise "#{sport} #{abbreviation} names an undefined group #{parent}" if parent && !defined[parent]
      defined[abbreviation] = true
      references = { "sport" => "SPORT-#{sport}" }
      references["parent"] = position_code(sport, parent) if parent
      { "type" => "Position", "code" => position_code(sport, abbreviation),
        "attributes" => { "name" => name, "abbreviation" => abbreviation }, "references" => references }
    end
    write(File.join(ROOT, spec.fetch(:file)), envelope({ "note" => spec.fetch(:note) }, records))
    @report["vocabularies"][sport] = defined.keys
    defined
  end

  def build_assignments(feed, vocabulary)
    sport, league, teams = SELECTIONS.fetch(feed)
    capture = JSON.parse(File.read(File.join(CAPTURES, "#{feed}.json"), encoding: "UTF-8"))
    as_of = capture.fetch("as_of")
    records = []
    teams.each do |abbreviation|
      team = capture.fetch("teams").find { |row| row.fetch("abbreviation") == abbreviation } or raise "#{feed} capture has no #{abbreviation}"
      roster = "#{sport}-#{league}-SEASON_#{capture.fetch('season')}-TEAM-#{abbreviation}-ROSTER-#{as_of.tr('-', '_')}"
      raise "Missing roster #{roster}" unless @known[roster] == "Roster"
      counts = Hash.new(0)
      team.fetch("players").sort_by { |player| player.fetch("source_id").to_i }.each do |player|
        listed = player.fetch("position")
        raise "#{abbreviation} #{player.fetch('source_id')} lists #{listed.inspect}, which is not in the #{sport} vocabulary" unless vocabulary[listed]
        entry = "#{roster}-PLAYER_#{player.fetch('source_id')}"
        raise "Missing roster entry #{entry}" unless @known[entry] == "RosterEntry"
        split = SPLITS[[ feed, player.fetch("source_id") ]]
        if split
          raise "#{player.fetch('source_id')} is now listed as #{listed}, not #{split.fetch(:listed)}; review the split" unless listed == split.fetch(:listed)
          positions, note = split.fetch(:positions), split.fetch(:note)
          @report["splits"] << { "league" => league, "team" => abbreviation, "source_id" => player.fetch("source_id"),
            "listed" => listed, "recorded" => positions }
        else
          positions = [ listed ]
          note = "Position listed for this player on the source roster. A roster designation, not a record of where the player appeared in games."
        end
        positions.each do |abbreviation_listed|
          raise "#{sport} vocabulary has no #{abbreviation_listed}" unless vocabulary[abbreviation_listed]
          counts[abbreviation_listed] += 1
          records << { "type" => "PositionAssignment", "code" => "#{entry}-POSITION-#{abbreviation_listed}", "attributes" => {},
            "references" => { "subject" => entry, "position" => position_code(sport, abbreviation_listed) },
            "source" => { "url" => team.fetch("url"), "captured_on" => as_of, "note" => note } }
        end
      end
      @report["assignments"]["#{league}-#{abbreviation}"] = counts.sort.to_h
    end
    source = { "url" => capture.fetch("source_url"), "captured_on" => as_of, "note" => capture.fetch("roster_meaning") }
    write(File.join(ROOT, "yaml/position_assignments_2026/#{feed}.yaml"), envelope(source, records))
  end

  def run
    vocabularies = VOCABULARIES.to_h { |sport, spec| [ sport, build_vocabulary(sport, spec) ] }
    SELECTIONS.each { |feed, (sport, _league, _teams)| build_assignments(feed, vocabularies.fetch(sport)) }
    report = JSON.pretty_generate(@report) + "\n"
    if @check
      raise "Generated report differs" unless File.file?(REPORT) && File.read(REPORT, encoding: "UTF-8") == report
    else
      FileUtils.mkdir_p(File.dirname(REPORT))
      File.write(REPORT, report)
    end
    puts JSON.pretty_generate(@report["assignments"].transform_values { |counts| counts.values.sum }.merge("splits" => @report["splits"].size))
  end
end

if $PROGRAM_NAME == __FILE__
  check = ARGV.delete("--check")
  abort "Usage: ruby scripts/build_position_assignments_2026.rb [--check]" unless ARGV.empty?
  PositionAssignments2026Builder.new(check: check).run
end
