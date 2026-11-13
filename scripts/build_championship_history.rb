require "fileutils"
require "json"
require "yaml"
require_relative "build_2026"

class ChampionshipHistoryBuilder
  ROOT = File.expand_path("..", __dir__)
  SPORTS = { "NBA" => "BKT", "NFL" => "FTB", "NHL" => "HCK", "MLB" => "BSB" }.freeze
  TITLES = { "NBA" => [ "nba_championship", "NBA championship" ], "NFL" => [ "super_bowl", "Super Bowl" ],
    "NHL" => [ "stanley_cup", "Stanley Cup" ], "MLB" => [ "world_series", "World Series" ] }.freeze

  def initialize(check: false, source: File.join(ROOT, "sources/championship_history"), output: File.join(ROOT, "yaml/championship_history"))
    @check, @source, @output = check, source, output
    registry = MICharismaSeeders::SequenceRegistry.read(File.join(ROOT, "yaml/entity_sequences.yaml"))
    reader = MICharismaSeeders::Reader.new(registry: registry)
    paths = Dir.glob(File.join(ROOT, "yaml/**/*.{yaml,yml,json}")).reject { |path| path.include?("/championship_history/") || path.end_with?("entity_sequences.yaml") }
    @existing = paths.flat_map { |path| reader.read(path) }
    @known = @existing.each_with_object({}) { |row, result| ([ row.code ] + row.aliases).each { |code| result[code] = row.code } }
    @attributes = @existing.group_by(&:code).transform_values { |rows| rows.reduce({}) { |attrs, row| attrs.merge(row.attributes) } }
    @captures = SPORTS.keys.to_h { |league| [ league, JSON.parse(File.read(File.join(source, "#{league.downcase}_alignments.json"))) ] }
    @name_corrections = JSON.parse(File.read(File.join(source, "display_name_corrections.json"))).fetch("corrections")
  end

  def prepare_ranges
    ranges = []
    bindings = []
    @captures.each do |league, capture|
      current = JSON.parse(File.read(File.join(ROOT, "sources/coverage_2026/#{league.downcase}.json")))
      current_codes = current.fetch("teams").to_h do |team|
        abbreviation = Sports2026Builder::ABBREVIATIONS.fetch(league, {}).fetch(team.fetch("abbreviation"), team.fetch("abbreviation"))
        key = league == "NHL" ? abbreviation : team.fetch("source_id")
        [ key, @known.fetch("#{SPORTS.fetch(league)}-#{league}-TEAM-#{abbreviation}") ]
      end
      history = Hash.new { |hash, key| hash[key] = [] }
      capture.fetch("seasons").each do |season|
        season.fetch("teams").each do |team|
          id = team.fetch("source_id")
          code = current_codes[id]
          code = "HCK-NHL-TEAM-ARI" if league == "NHL" && id == "ARI"
          raise "Unreviewed #{league} team identity #{id}: #{team.fetch('name')}" unless code

          bindings << { "league" => league, "source_id" => id, "team" => code,
            "basis" => league == "NHL" ? "reviewed_official_abbreviation" : "existing_provider_team_id" }
          conference, division = classification_codes(league, season.fetch("start_year"), team)
          abbreviation = Sports2026Builder::ABBREVIATIONS.fetch(league, {}).fetch(team.fetch("abbreviation"), team.fetch("abbreviation"))
          history[code] << { "year" => season.fetch("start_year"), "conference" => conference, "division" => division,
            "display_name" => display_name(league, season.fetch("start_year"), team), "abbreviation" => abbreviation }
        end
      end
      history.sort.each do |team, years|
        years.sort_by { |row| row.fetch("year") }.each do |row|
          values = row.reject { |key, _| key == "year" }
          prior = ranges.last
          if prior && prior.fetch("team") == team && prior.fetch("through") + 1 == row.fetch("year") && prior.reject { |key, _| %w[league team from through].include?(key) } == values
            prior["through"] = row.fetch("year")
          else
            ranges << { "league" => league, "team" => team, "from" => row.fetch("year"), "through" => row.fetch("year") }.merge(values)
          end
        end
      end
    end
    document = { "meaning" => "Inclusive starting-year ranges, expanded to one Campaign per team and season. Split ranges when classification or annual display facts change.",
      "team_bindings" => bindings.uniq.sort_by { |row| [ row.fetch("league"), row.fetch("source_id") ] }, "ranges" => ranges }
    File.write(File.join(@source, "alignment_ranges.yml"), YAML.dump(document))
    puts "Prepared #{ranges.size} alignment ranges for review."
  end

  def call
    document = YAML.safe_load(File.read(File.join(@source, "alignment_ranges.yml")))
    ranges = document.fetch("ranges")
    bindings = document.fetch("team_bindings").to_h { |binding| [ [ binding.fetch("league"), binding.fetch("source_id") ], binding.fetch("team") ] }
    anchors = {}
    campaigns = []
    pairs = {}
    ranges.each do |range|
      first, last = range.values_at("from", "through")
      raise "Invalid year range: #{range.inspect}" unless first.is_a?(Integer) && last.is_a?(Integer) && first <= last

      league = range.fetch("league")
      capture = @captures.fetch(league)
      if range.fetch("team") == "HCK-NHL-TEAM-ARI"
        anchors[range.fetch("team")] = record("Team", range.fetch("team"), { "territory" => "Arizona", "mascot" => "Coyotes", "abbreviation" => "ARI" }, { "league" => "HCK-LEAGUE-NHL" })
      end
      (first..last).each do |year|
        season = capture.fetch("seasons").find { |row| row.fetch("start_year") == year }
        raise "No captured #{league} season for #{year}" unless season

        pair = [ range.fetch("team"), year ]
        raise "Overlapping team/season range: #{pair.inspect}" if pairs.key?(pair)

        season_code = "#{SPORTS.fetch(league)}-#{league}-SEASON_#{season.fetch('label')}"
        anchors["YEAR-#{year}"] = record("Year", "YEAR-#{year}", { "number" => year })
        anchors[season_code] = record("Season", season_code, @attributes.fetch(season_code, {}).merge("label" => season.fetch("label")), { "league" => "#{SPORTS.fetch(league)}-LEAGUE-#{league}", "year" => "YEAR-#{year}" })
        division = range.fetch("division")
        unless @known.key?(division)
          raise "Unreviewed division #{division}" unless league == "NHL" && year == 2020 && !range["conference"]

          name = division.split("-").last.capitalize
          anchors[division] = record("Division", division, { "name" => "#{name} (2020-21)" }, { "league" => "HCK-LEAGUE-NHL" })
        end
        code = "#{season_code}-TEAM-#{range.fetch('team').split('-TEAM-').last}"
        attributes = range.slice("display_name", "abbreviation").merge(@attributes.fetch(code, {}))
        references = { "team" => range.fetch("team"), "season" => season_code, "division" => division }
        references["conference"] = range["conference"] if range["conference"]
        source = { "url" => season.fetch("url"), "captured_on" => capture.fetch("as_of"), "note" => capture.fetch("meaning") }
        correction = @name_corrections.find { |entry| entry.fetch("league") == league && (entry.fetch("from")..entry.fetch("through")).cover?(year) && bindings.fetch([ league, entry.fetch("source_id") ]) == range.fetch("team") }
        source["display_name_correction"] = correction.slice("url", "published_on", "note") if correction
        campaigns << record("Campaign", code, attributes, references).merge("source" => source)
        pairs[pair] = code
      end
    end
    @captures.each do |league, capture|
      capture.fetch("seasons").each do |season|
        selected = ranges.select { |range| range.fetch("league") == league && (range.fetch("from")..range.fetch("through")).cover?(season.fetch("start_year")) }
        expected = season.fetch("teams").map { |team| bindings.fetch([ league, team.fetch("source_id") ]) }
        raise "Incomplete #{league} #{season.fetch('label')} alignment" unless selected.map { |range| range.fetch("team") }.sort == expected.sort

        season.fetch("teams").each do |team|
          range = selected.find { |entry| entry.fetch("team") == bindings.fetch([ league, team.fetch("source_id") ]) }
          expected_classification = classification_codes(league, season.fetch("start_year"), team)
          raise "Alignment differs from capture: #{range.fetch('team')} #{season.fetch('label')}" unless range.values_at("conference", "division") == expected_classification
          raise "Annual name differs from reviewed sources: #{range.fetch('team')} #{season.fetch('label')}" unless range.fetch("display_name") == display_name(league, season.fetch("start_year"), team)
        end
      end
    end
    championships = championship_records(pairs)
    write("anchors.yml", anchors.values.sort_by { |row| row.fetch("code") })
    write("campaigns.yml", campaigns.sort_by { |row| row.fetch("code") })
    write("championships.yml", championships)
    puts JSON.generate(anchors: anchors.size, campaigns: campaigns.size, championships: championships.size / 4)
  end

  private

  def display_name(league, year, team)
    correction = @name_corrections.find do |entry|
      entry.fetch("league") == league && entry.fetch("source_id") == team.fetch("source_id") && (entry.fetch("from")..entry.fetch("through")).cover?(year)
    end
    correction ? correction.fetch("display_name") : team.fetch("name")
  end

  def classification_codes(league, year, team)
    prefix = "#{SPORTS.fetch(league)}-#{league}"
    if league == "NHL" && year == 2020
      return [ nil, "#{prefix}-DIVISION-2020_2021-#{token(team.fetch('division').split.last)}" ]
    end
    conference = team.fetch("conference")
    conference += " Conference" if league == "NHL" && !conference.end_with?("Conference")
    division = team.fetch("division")
    division += " Division" if league == "NBA"
    division = division.sub("American League", "AL").sub("National League", "NL") if league == "MLB"
    [ @known.fetch("#{prefix}-CONFERENCE-#{token(conference)}"), @known.fetch("#{prefix}-DIVISION-#{token(division)}") ]
  end

  def championship_records(pairs)
    capture = JSON.parse(File.read(File.join(@source, "championships.json")))
    rows = capture.fetch("championships")
    SPORTS.each_key do |league|
      years = rows.select { |row| row.fetch("league") == league }.map { |row| row.fetch("championship_year") }.sort
      raise "Expected ten #{league} championships, 2016 through 2025" unless years == (2016..2025).to_a
    end
    rows.flat_map do |row|
      league = row.fetch("league")
      source = { "url" => row.fetch("url"), "captured_on" => capture.fetch("as_of"), "note" => "Championship and finalists only; no complete playoff bracket or individual games are asserted." }
      winner_campaign = pairs.fetch([ row.fetch("winner"), row.fetch("start_year") ])
      runner_campaign = pairs.fetch([ row.fetch("runner_up"), row.fetch("start_year") ])
      raise "A championship needs two distinct finalists" if winner_campaign == runner_campaign

      season = winner_campaign.split("-TEAM-").first
      code = "#{season}-CHAMPIONSHIP"
      key, title = TITLES.fetch(league)
      attributes = { "name" => "#{row.fetch('championship_year')} #{title}", "kind" => "championship",
        "details" => { "coverage" => "finalists_only", "championship_year" => row.fetch("championship_year"), "source" => source } }
      award_attributes = { "key" => key, "name" => title }
      award_attributes["awarded_on"] = row["awarded_on"] if row["awarded_on"]
      [ record("Contest", code, attributes, { "context" => "#{SPORTS.fetch(league)}-LEAGUE-#{league}", "season" => season, "champion" => row.fetch("winner") }),
        record("Contestant", "#{code}-WINNER", { "placing" => 1 }, { "contest" => code, "campaign" => winner_campaign }),
        record("Contestant", "#{code}-RUNNER_UP", { "placing" => 2 }, { "contest" => code, "campaign" => runner_campaign }),
        record("TitleAward", "#{code}-TITLE", award_attributes, { "contest" => code, "winner" => "#{code}-WINNER" }) ].map { |entry| entry.merge("source" => source) }
    end
  end

  def token(value)
    value.upcase.gsub(/[^A-Z0-9]+/, "_").sub(/_\z/, "")
  end

  def record(type, code, attributes, references = {})
    { "type" => type, "code" => code, "attributes" => attributes, "references" => references }
  end

  def write(name, records)
    document = { "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "records" => records }
    contents = YAML.dump(JSON.parse(JSON.generate(document)))
    path = File.join(@output, name)
    if @check
      raise "Generated file differs: #{path}" unless File.file?(path) && File.read(path) == contents
    else
      FileUtils.mkdir_p(@output)
      File.write(path, contents)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  check = ARGV.delete("--check")
  prepare = ARGV.delete("--prepare-ranges")
  abort "Usage: ruby scripts/build_championship_history.rb [--check | --prepare-ranges]" unless ARGV.empty? && !(check && prepare)
  builder = ChampionshipHistoryBuilder.new(check: check)
  prepare ? builder.prepare_ranges : builder.call
end
