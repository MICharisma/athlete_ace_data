require_relative "build_2026"

# Carry the legacy JSON conference, division, and membership catalog onto the
# 2026 team identities. Teams are matched to the 2026 captures by name, and any
# legacy team without exactly one match stops the build.
class Divisions2026Builder
  ROOT = Sports2026Builder::ROOT
  LEAGUES = { "MLB" => "baseball", "NBA" => "basketball", "NFL" => "football", "NHL" => "hockey", "MLS" => "soccer" }.freeze
  RENAMED = { [ "NHL", "Utah Hockey Club" ] => "Utah Mammoth",
    [ "MLS", "Cincinnati FC" ] => "FC Cincinnati", [ "MLS", "DC United" ] => "D.C. United", [ "MLS", "Miami Inter CF" ] => "Inter Miami CF",
    [ "MLS", "Montreal CF" ] => "CF Montréal", [ "MLS", "New York Red Bulls" ] => "Red Bull New York", [ "MLS", "Dallas FC" ] => "FC Dallas",
    [ "MLS", "Sporting Kansas City FC" ] => "Sporting Kansas City", [ "MLS", "Los Angeles Galaxy" ] => "LA Galaxy",
    [ "MLS", "Los Angeles FC" ] => "LAFC", [ "MLS", "Real Salt Lake FC" ] => "Real Salt Lake",
    [ "MLS", "St. Louis City SC" ] => "St. Louis CITY SC", [ "MLS", "Vancouver Whitecaps FC" ] => "Vancouver Whitecaps" }.freeze
  # Teams that joined after the legacy catalog was written.
  ADDED = { "MLS" => [ { "name" => "San Diego FC", "conference_name" => "Western Conference", "division_name" => "West",
    "note" => "Joined MLS's Western Conference as an expansion club in 2025; not present in the legacy catalog." } ] }.freeze

  def initialize(check: false)
    @check = check
    @teams = Sports2026Builder.new(check: true)
  end

  def token(value)
    @teams.token(value)
  end

  def call
    records = LEAGUES.flat_map { |league, sport_dir| league_records(league, sport_dir) }
    path = File.join(ROOT, "yaml/coverage_2026/divisions.yaml")
    document = { "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA",
      "source" => { "note" => "Current conference and division alignment carried over from the legacy JSON catalog onto 2026 team identities." },
      "records" => records }
    writer = SeedCatalog::Writer.new(check: @check)
    writer.write_batch(path, document) # Conferences and divisions go to the catalog.
    writer.finish(codes_path: File.join(ROOT, "sources/coverage_2026/catalog_codes_divisions.json"))
    puts JSON.generate(records.group_by { |record| record.fetch("type") }.transform_values(&:size))
  end

  private

  def league_records(league, sport_dir)
    folder = File.join(ROOT, "sports/#{sport_dir}/USA/#{league}")
    sport = Sports2026Builder::SPORTS.fetch(league)
    capture = JSON.parse(File.read(File.join(ROOT, "sources/coverage_2026/#{league.downcase}.json")))
    legacy_source = { "note" => "Legacy JSON catalog", "path" => "sports/#{sport_dir}/USA/#{league}" }
    records = []
    divisions = {}

    JSON.parse(File.read(File.join(folder, "conferences.json"))).fetch("conferences").each do |conference|
      conference_code = "#{sport}-#{league}-CONFERENCE-#{token(conference.fetch('name'))}"
      records << { "type" => "Conference", "code" => conference_code,
        "attributes" => conference.slice("name", "abbreviation", "logo_url").compact,
        "references" => { "league" => "#{sport}-LEAGUE-#{league}" }, "source" => legacy_source }
      conference.fetch("divisions").each do |division|
        code = "#{sport}-#{league}-DIVISION-#{token(division.fetch('name'))}"
        divisions[[ conference.fetch("name"), division.fetch("name") ]] = code
        records << { "type" => "Division", "code" => code, "attributes" => division.slice("name", "abbreviation", "logo_url").compact,
          "references" => { "conference" => conference_code }, "source" => legacy_source }
      end
    end

    rows = JSON.parse(File.read(File.join(folder, "memberships.json"))).fetch("memberships").select { |row| row.fetch("active") }
    rows = rows.map { |row| row.merge("name" => [ row["territory_name"], row.fetch("team_name") ].compact.join(" "), "source" => legacy_source) }
    rows += ADDED.fetch(league, []).map { |row| row.merge("source" => { "note" => row.fetch("note") }) }
    matched = rows.map do |row|
      name = RENAMED.fetch([ league, row.fetch("name") ], row.fetch("name"))
      teams = capture.fetch("teams").select { |team| team.fetch("name") == name || team.fetch("name").end_with?(" #{name}") }
      raise "#{league} #{row.fetch('name')} matches #{teams.size} 2026 teams" unless teams.one?
      [ row, teams.first ]
    end
    unless matched.map { |_, team| team.fetch("source_id") }.sort == capture.fetch("teams").map { |team| team.fetch("source_id") }.sort
      raise "#{league} memberships do not cover each 2026 team exactly once"
    end

    records + matched.map do |row, team|
      team_code = @teams.team_code(capture, team)
      division = divisions.fetch([ row.fetch("conference_name"), row.fetch("division_name") ])
      { "type" => "Membership", "code" => "#{team_code}-MEMBERSHIP-#{division.split('-DIVISION-').last}",
        "attributes" => { "active" => true }, "references" => { "team" => team_code, "division" => division }, "source" => row.fetch("source") }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  check = ARGV.delete("--check")
  abort "Usage: ruby scripts/build_divisions_2026.rb [--check]" unless ARGV.empty?
  Divisions2026Builder.new(check: check).call
end
