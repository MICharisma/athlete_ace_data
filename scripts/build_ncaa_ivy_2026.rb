require "fileutils"
require "json"
require "yaml"
require_relative "../../../../lib/micharisma_seeders/lib/micharisma_seeders"

# Builds the 2026-27 Ivy League basketball manifests offline from the
# captures in sources/ncaa_ivy_2026. Men's and women's programs are separate
# NCAA Division I leagues, each with its own Ivy League conference.
class NcaaIvy2026Builder
  ROOT = File.expand_path("..", __dir__)
  SOURCES = File.join(ROOT, "sources/ncaa_ivy_2026")
  OUTPUT = File.join(ROOT, "yaml/ncaa_ivy_2026")
  FEEDS = %w[mens womens].freeze
  LEAGUE_NAMES = {
    "men" => [ "NCAA Division I Men's Basketball", "NCAA D1 Men" ],
    "women" => [ "NCAA Division I Women's Basketball", "NCAA D1 Women" ]
  }.freeze
  REQUIRED = %w[SPORT-BKT YEAR-2026 COUNTRY-US].freeze
  NUMBER_NOTE = "Known current number from the capture date onward until explicitly superseded; the actual introduction date is unknown.".freeze

  def initialize(check: false)
    @check = check
    registry = MICharismaSeeders::SequenceRegistry.read(File.join(ROOT, "yaml/entity_sequences.yaml"))
    reader = MICharismaSeeders::Reader.new(registry: registry)
    paths = Dir.glob(File.join(ROOT, "yaml/**/*.{yaml,yml,json}")).reject { |path| path.include?("/ncaa_ivy_2026/") || path.end_with?("entity_sequences.yaml") }
    @known = {}
    paths.flat_map { |path| reader.read(path) }.each { |row| ([ row.code ] + row.aliases).each { |code| @known[code] = row.code } }
    missing = REQUIRED.reject { |code| @known.key?(code) }
    raise "Missing catalog parents: #{missing.join(', ')}" if missing.any?
    @report = { "coverage" => {}, "withheld" => [], "identity_bindings" => [] }
  end

  def token(value)
    value.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").tr("øØłŁæÆœŒ", "oOlLaAoO").upcase.gsub(/[^A-Z0-9]+/, "_").gsub(/\A_|_\z/, "")
  end

  def record(type, code, attributes = {}, references = {}, source: nil, aliases: nil)
    row = { "type" => type, "code" => code, "attributes" => attributes, "references" => references }
    row["aliases"] = aliases if aliases
    row["source"] = source if source
    row
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

  def build(feed)
    capture = JSON.parse(File.read(File.join(SOURCES, "#{feed}.json"), encoding: "UTF-8"))
    gender = capture.fetch("gender")
    league_token = capture.fetch("league")
    league = "BKT-LEAGUE-#{league_token}"
    conference = "BKT-#{league_token}-CONFERENCE-IVY_LEAGUE"
    season = "BKT-#{league_token}-SEASON_#{capture.fetch('season')}"
    as_of = capture.fetch("as_of")
    meaning = capture.fetch("roster_meaning")
    name, abbreviation = LEAGUE_NAMES.fetch(gender)

    records = [
      record("League", league, { "name" => name, "abbreviation" => abbreviation, "url" => "https://www.ncaa.com/" },
        { "sport" => "SPORT-BKT", "jurisdiction" => "COUNTRY-US" }),
      record("Conference", conference, { "name" => "Ivy League", "abbreviation" => "Ivy" }, { "league" => league },
        source: { "url" => capture.fetch("source_url"), "captured_on" => as_of }),
      record("Season", season, { "label" => capture.fetch("season") }, { "league" => league, "year" => "YEAR-2026" })
    ]
    claimed = {}
    numbers = []
    player_total = 0

    capture.fetch("teams").each do |team|
      abbr = token(team.fetch("abbreviation"))
      team_code = "BKT-#{league_token}-TEAM-#{abbr}"
      campaign = "#{season}-TEAM-#{abbr}"
      roster = "#{campaign}-ROSTER-#{as_of.tr('-', '_')}"
      check = team.fetch("official_check")
      unconfirmed = check.fetch("espn_only", [])
      source = { "url" => team.fetch("url"), "captured_on" => as_of, "note" => meaning }
      official = { "url" => check.fetch("url"), "status" => check.fetch("status") }

      records << record("Team", team_code, { "territory" => team.fetch("territory"), "mascot" => team.fetch("mascot"),
        "abbreviation" => team.fetch("abbreviation") }, { "league" => league }, source: source)
      records << record("Membership", "#{team_code}-MEMBERSHIP-IVY_LEAGUE", { "active" => true },
        { "team" => team_code, "league" => league, "conference" => conference },
        source: { "url" => capture.fetch("source_url"), "captured_on" => as_of })
      records << record("Campaign", campaign, { "display_name" => "#{team.fetch('territory')} #{team.fetch('mascot')}",
        "abbreviation" => team.fetch("abbreviation"),
        "details" => { "roster_coverage" => "complete_source_listing", "source_player_count" => team.fetch("players").size,
          "roster_meaning" => meaning, "official_check" => official } },
        { "team" => team_code, "season" => season, "conference" => conference }, source: source)
      records << record("Roster", roster, { "kind" => "published_roster_snapshot", "coverage" => "complete",
        "effective_on" => as_of, "details" => { "meaning" => meaning, "official_check" => official } },
        { "campaign" => campaign }, source: source)

      team.fetch("players").each do |player|
        id = player.fetch("source_id")
        provider_alias = "BKT-ESPN-PLAYER_#{token(id)}"
        player_code = @known[provider_alias]
        basis = "existing_official_provider_id"
        unless player_code
          basis = "new_provider_identity"
          suffix = [ token(player.fetch("last_name")), token(player.fetch("first_name")) ].reject(&:empty?).join("_")
          player_code = "BKT-#{league_token}-PLAYER-#{suffix}"
          player_code += "_SOURCE_ESPN_#{token(id)}" if @known.key?(player_code) || claimed.key?(player_code)
          attributes = player.slice("first_name", "last_name")
          attributes["photo_urls"] = [ player.fetch("photo_url") ] if player["photo_url"]
          records << record("Player", player_code, attributes, { "sport" => "SPORT-BKT" }, source: source, aliases: [ provider_alias ])
          claimed[player_code] = id
        end
        @report["identity_bindings"] << { "provider" => "espn", "league" => league_token, "source_id" => id, "code" => player_code, "basis" => basis }

        records << record("RosterEntry", "#{roster}-PLAYER_#{token(id)}",
          { "details" => { "provider" => "espn", "source_id" => id, "class_year" => player["experience"], "position" => player["position"] }.compact },
          { "roster" => roster, "player" => player_code }, source: source)
        player_total += 1

        if unconfirmed.include?(player.fetch("display_name"))
          @report["withheld"] << { "league" => league_token, "team" => team_code, "player" => player_code,
            "name" => player.fetch("display_name"), "reason" => "Listed by ESPN but absent from the official roster page; no Activation or number assignment." }
          next
        end

        records << record("Activation", "#{campaign}-PLAYER-#{player_code.split('-PLAYER-').last}", {},
          { "player" => player_code, "campaign" => campaign }, source: source)
        next unless player.fetch("number", "").match?(/\A[0-9]{1,2}\z/)

        numbers << record("JerseyNumberAssignment", "#{team_code}-NUMBER-#{player_code}-FROM_#{as_of.tr('-', '_')}",
          { "number" => player.fetch("number"), "start_date" => as_of,
            "details" => { "period_basis" => "current_source_capture", "note" => NUMBER_NOTE } },
          { "team" => team_code, "player" => player_code }, source: source)
      end
    end

    write(File.join(OUTPUT, "#{feed}.yaml"), { "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA",
      "source" => { "url" => capture.fetch("source_url"), "captured_on" => as_of, "note" => meaning }, "records" => records + numbers })
    @report["coverage"][league_token] = { "season" => capture.fetch("season"), "teams" => capture.fetch("teams").size,
      "roster_entries" => player_total, "number_assignments" => numbers.size,
      "official_checks" => capture.fetch("teams").to_h { |team| [ team.fetch("abbreviation"), team.fetch("official_check").fetch("status") ] } }
  end

  def run
    FEEDS.each { |feed| build(feed) }
    @report["identity_bindings"].sort_by! { |row| [ row.fetch("league"), row.fetch("source_id").to_i ] }
    report = JSON.pretty_generate(@report) + "\n"
    path = File.join(SOURCES, "report.json")
    if @check
      raise "Generated report differs" unless File.file?(path) && File.read(path, encoding: "UTF-8") == report
    else
      File.write(path, report)
    end
    puts JSON.pretty_generate(@report["coverage"].transform_values { |row| row.except("official_checks") }.merge("withheld" => @report["withheld"].size))
  end
end

if $PROGRAM_NAME == __FILE__
  check = ARGV.delete("--check")
  abort "Usage: ruby scripts/build_ncaa_ivy_2026.rb [--check]" unless ARGV.empty?
  NcaaIvy2026Builder.new(check: check).run
end
