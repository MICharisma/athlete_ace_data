require "date"
require "fileutils"
require "json"
require "yaml"
require_relative "../../../../lib/micharisma_seeders/lib/micharisma_seeders"

class Sports2026Builder
  ROOT = File.expand_path("..", __dir__)
  SPORTS = { "NBA" => "BKT", "NFL" => "FTB", "NHL" => "HCK", "MLB" => "BSB", "EPL" => "SOC", "MLS" => "SOC", "UCL" => "SOC" }.freeze
  ABBREVIATIONS = {
    "NBA" => { "NY" => "NYK", "NO" => "NOP", "GS" => "GSW", "SA" => "SAS", "UTAH" => "UTA", "WSH" => "WAS", "BRK" => "BKN", "CHO" => "CHA", "PHO" => "PHX" },
    "NFL" => { "WSH" => "WAS" }, "EPL" => { "MAN" => "MUN", "MNC" => "MCI" }
  }.freeze
  SOCCER = %w[EPL MLS UCL].freeze
  # The MLB source gives the ballpark city and a short nickname; these teams
  # play under a different place or club name.
  MLB_NAMES = {
    "AZ" => [ "Arizona", "Diamondbacks" ], "TEX" => [ "Texas", "Rangers" ], "COL" => [ "Colorado", "Rockies" ],
    "MIN" => [ "Minnesota", "Twins" ], "TB" => [ "Tampa Bay", "Rays" ], "NYY" => [ "New York", "Yankees" ],
    "NYM" => [ "New York", "Mets" ], "LAA" => [ "Los Angeles", "Angels" ], "ATH" => [ "Oakland", "Athletics" ]
  }.freeze

  def initialize(check: false)
    @check = check
    @output = File.join(ROOT, "yaml/coverage_2026")
    registry = MICharismaSeeders::SequenceRegistry.read(File.join(ROOT, "yaml/entity_sequences.yaml"))
    reader = MICharismaSeeders::Reader.new(registry: registry)
    paths = Dir.glob(File.join(ROOT, "yaml/**/*.{yaml,yml,json}")).reject { |path| path.include?("/coverage_2026/") || path.end_with?("entity_sequences.yaml") }
    @existing = paths.flat_map { |path| reader.read(path) }
    @known = {}
    @existing.each { |row| ([ row.code ] + row.aliases).each { |code| @known[code] = row.code } }
    @records = {}
    @names = Hash.new { |hash, key| hash[key] = [] }
    @existing.select { |row| row.type == "Player" }.each do |row|
      sport = row.references["sport"] || row.scope["sport"]
      key = [ sport, name_key(row.attributes.fetch("first_name", ""), row.attributes.fetch("last_name", "")) ]
      @names[key] |= [ row.code ]
    end
    @providers = {}
    @claims = {}
    @identity_report = {}
    @team_ids = {}
    @number_observations = Hash.new { |hash, key| hash[key] = [] }
    @summaries = {}
    legacy = JSON.parse(File.read(File.join(ROOT, "sources/coverage_2025.json")))
    legacy.fetch("teams").select { |team| team.fetch("league") == "NHL" }.each do |team|
      team.fetch("players").each do |player|
        base = "HCK-NHL-PLAYER-#{token(player.fetch('last_name'))}_#{token(player.fetch('first_name'))}"
        code = @known["#{base}_SOURCE_#{player.fetch('source_key')}"] || @known[base]
        if code
          @providers[[ "nhl", "HCK", player.fetch("source_key") ]] = code
          @claims[[ "nhl", "HCK", code ]] = player.fetch("source_key")
        end
      end
    end
  end

  def token(value)
    value.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").tr("øØłŁæÆœŒ", "oOlLaAoO").upcase.gsub(/[^A-Z0-9]+/, "_").gsub(/\A_|_\z/, "")
  end

  def name_key(first, last)
    token("#{first} #{last}").delete("_")
  end

  def add(type, code, attributes = {}, references = {}, source: nil)
    return @known.fetch(code) if @known.key?(code)
    @records[code] = { "type" => type, "code" => code, "attributes" => attributes, "references" => references }
    @records[code]["source"] = source if source
    @known[code] = code
    code
  end

  def bind_alias(type, canonical, alias_code)
    return if @known[alias_code] == canonical
    raise "Conflicting identity alias #{alias_code}" if @known.key?(alias_code)
    row = @records[canonical] ||= begin
      existing = @existing.find { |record| record.code == canonical }
      { "type" => type, "code" => canonical, "attributes" => existing.attributes,
        "references" => existing.scope.slice("sport", "figure").merge(existing.references), "source" => existing.source }
    end
    row["aliases"] ||= []
    row["aliases"] |= [ alias_code ]
    @known[alias_code] = canonical
  end

  def write(name, records, source: {})
    path = File.join(@output, "#{name}.yaml")
    document = { "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "source" => source, "records" => records }
    contents = YAML.dump(JSON.parse(JSON.generate(document)))
    if @check
      raise "Generated file differs: #{path}" unless File.file?(path) && File.read(path) == contents
    else
      FileUtils.mkdir_p(@output)
      File.write(path, contents)
    end
  end

  def source_for(capture, team)
    { "url" => team.fetch("url"), "captured_on" => capture.fetch("as_of"), "note" => capture.fetch("roster_meaning") }
  end

  def player_code(capture, player, source)
    league = capture.fetch("league")
    sport = SPORTS.fetch(league)
    provider = capture.fetch("provider")
    id = player.fetch("source_id")
    key = [ provider, sport, id ]
    if @providers.key?(key)
      @identity_report[key] ||= { "provider" => provider, "sport" => sport, "source_id" => id, "code" => @providers.fetch(key), "basis" => "existing_official_provider_id" }
      return @providers.fetch(key)
    end

    names = @names[[ "SPORT-#{sport}", name_key(player.fetch("first_name"), player.fetch("last_name")) ]]
    candidates = names.reject { |code| @claims[[ provider, sport, code ]] && @claims[[ provider, sport, code ]] != id }
    raise "Ambiguous #{provider} identity: #{player.inspect}" if candidates.size > 1
    code = candidates.first
    reason = code ? "existing_unambiguous_catalog_name" : "new_provider_identity"
    unless code
      suffix = [ token(player.fetch("last_name")), token(player.fetch("first_name")) ].reject(&:empty?).join("_")
      code = "#{sport}-#{league}-PLAYER-#{suffix}"
      code += "_SOURCE_#{token(provider)}_#{token(id)}" if @known.key?(code)
      attributes = player.slice("first_name", "last_name", "birthdate")
      attributes["photo_urls"] = [ player.fetch("photo_url") ] if player["photo_url"]
      add("Player", code, attributes, { "sport" => "SPORT-#{sport}" }, source: source)
      @names[[ "SPORT-#{sport}", name_key(player.fetch("first_name"), player.fetch("last_name")) ]] |= [ code ]
    end
    bind_alias("Player", code, "#{sport}-#{token(provider)}-PLAYER_#{token(id)}")
    @providers[key] = code
    @claims[[ provider, sport, code ]] = id
    @identity_report[key] = { "provider" => provider, "sport" => sport, "source_id" => id, "code" => code, "basis" => reason }
    code
  end

  def team_code(capture, team)
    league = capture.fetch("league")
    sport = SPORTS.fetch(league)
    key = [ capture.fetch("provider"), sport, team.fetch("source_id") ]
    return @team_ids[key] if @team_ids.key?(key)
    abbreviation = ABBREVIATIONS.fetch(league, {}).fetch(team.fetch("abbreviation"), team.fetch("abbreviation"))
    code = @known["#{sport}-#{league}-TEAM-#{abbreviation}"]
    unless code
      code = league == "UCL" ? "SOC-CLUB-ESPN_#{team.fetch('source_id')}" : "#{sport}-#{league}-TEAM-#{abbreviation}"
      raise "Historical NBA team lacks a catalog identity: #{team.inspect}" if capture.fetch("provider") == "basketball_reference"
      add("Team", code, team_names(league, team, abbreviation).merge("abbreviation" => abbreviation),
        { "league" => "#{sport}-LEAGUE-#{league}" }, source: source_for(capture, team))
    end
    @team_ids[key] = code
    code
  end

  # Clubs are known by their full name, without a separate place.
  def team_names(league, team, abbreviation)
    return { "mascot" => team.fetch("name") } if SOCCER.include?(league)

    territory, mascot = league == "MLB" ? MLB_NAMES.fetch(abbreviation, [ team.fetch("territory"), team.fetch("mascot") ]) : [ team.fetch("territory"), team.fetch("mascot") ]
    { "territory" => territory, "mascot" => mascot }
  end

  def build_capture(name)
    capture = JSON.parse(File.read(File.join(ROOT, "sources/coverage_2026/#{name}.json")))
    league = capture.fetch("league")
    sport = SPORTS.fetch(league)
    season = "#{sport}-#{league}-SEASON_#{capture.fetch('season')}"
    year = capture.fetch("season").split("_").first
    add("Year", "YEAR-#{year}", { "number" => year.to_i })
    add("Season", season, { "label" => capture.fetch("season") }, { "league" => "#{sport}-LEAGUE-#{league}", "year" => "YEAR-#{year}" })
    records = []
    capture.fetch("teams").each do |team|
      code = team_code(capture, team)
      abbreviation = ABBREVIATIONS.fetch(league, {}).fetch(team.fetch("abbreviation"), team.fetch("abbreviation"))
      campaign = "#{season}-TEAM-#{code.split('-TEAM-').last}"
      source = source_for(capture, team)
      add("Campaign", campaign, { "display_name" => team.fetch("name"), "abbreviation" => abbreviation,
        "details" => { "roster_coverage" => "complete_source_listing", "source_player_count" => team.fetch("players").size,
          "roster_meaning" => capture.fetch("roster_meaning") } }, { "team" => code, "season" => season }, source: source)
      roster = "#{campaign}-ROSTER-#{capture.fetch('as_of').tr('-', '_')}"
      roster_attributes = { "kind" => capture.fetch("provider") == "basketball_reference" ? "season_appearance_union" : league == "MLB" ? "full_season_inventory" : "published_roster_snapshot",
        "coverage" => "complete", "details" => { "meaning" => capture.fetch("roster_meaning") } }
      roster_attributes["effective_on"] = capture.fetch("as_of") unless capture.fetch("provider") == "basketball_reference" || league == "MLB"
      records << { "type" => "Roster", "code" => roster, "attributes" => roster_attributes, "references" => { "campaign" => campaign }, "source" => source }
      team.fetch("players").each do |player|
        player_id = player_code(capture, player, source)
        activation = "#{campaign}-PLAYER-#{player_id.split('-PLAYER-').last}"
        records << { "type" => "Activation", "code" => activation, "attributes" => {}, "references" => { "player" => player_id, "campaign" => campaign }, "source" => source } unless @known.key?(activation)
        @known[activation] = activation
        records << { "type" => "RosterEntry", "code" => "#{roster}-PLAYER_#{token(player.fetch('source_id'))}", "attributes" => {
          "details" => { "provider" => capture.fetch("provider"), "source_id" => player.fetch("source_id") } },
          "references" => { "roster" => roster, "player" => player_id }, "source" => source }
        if capture.fetch("provider") != "basketball_reference" && league != "MLB" && player.fetch("number", "").match?(/\A[0-9]{1,3}\z/)
          @number_observations[[ code, player_id ]] << { "number" => player.fetch("number"), "as_of" => capture.fetch("as_of"), "source" => source }
        end
      end
    end
    if league == "NHL"
      campaign_codes = capture.fetch("teams").to_h do |team|
        [ team.fetch("abbreviation"), "#{season}-TEAM-#{team_code(capture, team).split('-TEAM-').last}" ]
      end
      capture.fetch("games").each do |game|
        code = "HCK-NHL-GAME_#{game.fetch('source_id')}"
        records << { "type" => "Game", "code" => code, "attributes" => {
          "name" => "#{game.fetch('away')} at #{game.fetch('home')}", "begin_date" => game.fetch("date"), "end_date" => game.fetch("date"),
          "details" => game.slice("source_id", "start_time_utc", "venue", "state").merge("provider" => "nhl") },
          "references" => { "context" => "HCK-LEAGUE-NHL", "season" => season },
          "source" => { "url" => game.fetch("source_url"), "captured_on" => capture.fetch("as_of") } }
        %w[home away].each do |side|
          records << { "type" => "Contestant", "code" => "#{code}-#{side.upcase}",
            "attributes" => { "tiebreakers" => { "side" => side } },
            "references" => { "contest" => code, "campaign" => campaign_codes.fetch(game.fetch(side)) } }
        end
      end
    end
    write(name, records, source: { "url" => capture.fetch("source_url"), "captured_on" => capture.fetch("as_of"), "note" => capture.fetch("roster_meaning") })
    @summaries[name] = { "season" => capture.fetch("season"), "teams" => capture.fetch("teams").size,
      "memberships" => capture.fetch("teams").sum { |team| team.fetch("players").size }, "games" => capture.fetch("games", []).size,
      "meaning" => capture.fetch("roster_meaning") }
  end

  def run
    add("Sport", "SPORT-BSB", { "name" => "Baseball" })
    add("Federation", "FEDERATION-UEFA", { "name" => "Union of European Football Associations", "abbreviation" => "UEFA", "url" => "https://www.uefa.com/" })
    [ [ "BSB", "MLB", "Major League Baseball", "COUNTRY-US" ], [ "SOC", "MLS", "Major League Soccer", "COUNTRY-US" ],
      [ "SOC", "UCL", "UEFA Champions League", "FEDERATION-UEFA" ] ].each do |sport, league, name, jurisdiction|
      add("League", "#{sport}-LEAGUE-#{league}", { "name" => name, "abbreviation" => league }, { "sport" => "SPORT-#{sport}", "jurisdiction" => jurisdiction })
    end
    %w[nba nfl mlb nhl mls epl ucl nba_2023 nba_2024 nba_2025].each { |name| build_capture(name) }
    conflicts = []
    numbers = @number_observations.sort.filter_map do |(team, player), observations|
      if observations.map { |row| row.fetch("number") }.uniq.size > 1
        conflicts << { "team" => team, "player" => player, "observations" => observations }
        next
      end
      observation = observations.first
      { "type" => "JerseyNumberAssignment", "code" => "#{team}-NUMBER-#{player}-FROM_#{observation.fetch('as_of').tr('-', '_')}",
        "attributes" => { "number" => observation.fetch("number"), "start_date" => observation.fetch("as_of"),
          "details" => { "period_basis" => "current_source_capture", "note" => "Known current number from the capture date onward until explicitly superseded; the actual introduction date is unknown." } },
        "references" => { "team" => team, "player" => player }, "source" => observation.fetch("source") }
    end
    write("numbers", numbers)
    write("identities", @records.values)
    report = JSON.pretty_generate({ "coverage" => @summaries, "number_assignments" => numbers.size, "number_conflicts" => conflicts,
      "identity_bindings" => @identity_report.values.sort_by { |row| [ row.fetch("sport"), row.fetch("provider"), row.fetch("source_id") ] } }) + "\n"
    report_path = File.join(ROOT, "sources/coverage_2026/report.json")
    if @check
      raise "Generated report differs" unless File.read(report_path) == report
    else
      File.write(report_path, report)
    end
    puts JSON.pretty_generate({ coverage: @summaries.transform_values { |row| row.except("meaning") }, numbers: numbers.size, number_conflicts: conflicts.size })
  end
end

if $PROGRAM_NAME == __FILE__
  check = ARGV.delete("--check")
  abort "Usage: ruby scripts/build_2026.rb [--check]" unless ARGV.empty?
  Sports2026Builder.new(check: check).run
end
