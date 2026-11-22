require "date"
require "fileutils"
require "json"
require "yaml"
require_relative "../../../../lib/micharisma_seeders/lib/micharisma_seeders"
require_relative "lib/seed_catalog"

# Derives each team's dated namings from the per-season names its Campaigns
# already record. A run of consecutive seasons under one name and abbreviation
# becomes one TeamNaming. It starts on the run's first season start date and
# ends the day before the next naming starts; the latest naming stays open.
# These bounds are season-level, not announcement dates, and every naming
# records that in its details. A season without a start date stops the build:
# unknown dates are never filled in.
class TeamNamingsBuilder
  ROOT = File.expand_path("..", __dir__)
  LEAGUES = %w[BKT-LEAGUE-NBA FTB-LEAGUE-NFL HCK-LEAGUE-NHL BSB-LEAGUE-MLB].freeze
  NOTE = "Season-level bounds: the naming starts on the start date of the first season whose Campaign uses this name " \
    "and ends the day before the next naming starts. They are not announcement or approval dates.".freeze

  attr_reader :unsplit

  def initialize(check: false, library: File.join(ROOT, "yaml"), output: File.join(ROOT, "yaml/team_namings/team_namings.yml"),
    nicknames: File.join(ROOT, "sources/team_namings/nicknames.yml"), leagues: LEAGUES)
    @check, @output, @leagues = check, output, leagues
    @historical = File.file?(nicknames) ? YAML.safe_load(File.read(nicknames)).fetch("nicknames").map { it.fetch("text") } : []
    @writer = SeedCatalog::Writer.new(check: check)
    sequences = File.join(library, "entity_sequences.yaml")
    reader = MICharismaSeeders::Reader.new(registry: File.file?(sequences) ? MICharismaSeeders::SequenceRegistry.read(sequences) : nil)
    paths = Dir.glob(File.join(library, "**/*.{yaml,yml,json}")).reject { |path| path == sequences || path.start_with?(File.dirname(output)) }
    @rows = paths.flat_map { |path| reader.read(path) }.group_by(&:type).transform_values do |rows|
      rows.group_by(&:code).transform_values do |same|
        { "attributes" => same.reduce({}) { |attrs, row| attrs.merge(row.attributes) },
          "references" => same.reduce({}) { |refs, row| refs.merge(row.scope.to_h, row.references) } }
      end
    end
    @unsplit = []
  end

  def call
    seasons = @rows.fetch("Season", {}).select { |_, season| @leagues.include?(season.dig("references", "league")) }
    # Like the importer, a Campaign without a season reference takes the
    # season of its league and year.
    by_context = seasons.to_h { |code, season| [ season.fetch("references").values_at("league", "year"), code ] }
    @rows.fetch("Campaign", {}).each_value do |campaign|
      campaign["references"]["season"] ||= by_context[campaign.fetch("references").values_at("league", "year")]
    end
    campaigns = @rows.fetch("Campaign", {}).select { |_, campaign| seasons.key?(campaign.dig("references", "season")) }
    undated = campaigns.values.map { |campaign| campaign.dig("references", "season") }.uniq.reject { |code| seasons.dig(code, "attributes", "start_date") }
    raise "Seasons without a start date: #{undated.sort.join(', ')}" if undated.any?
    abbreviated = campaigns.select { |_, campaign| campaign.dig("attributes", "display_name").to_s.match?(/\A[A-Z]{2,4}\z/) }.keys
    raise "Campaigns whose display name is an abbreviation: #{abbreviated.sort.join(', ')}" if abbreviated.any?

    nicknames = {}
    namings = campaigns.group_by { |_, campaign| campaign.dig("references", "team") }.sort.flat_map do |team, rows|
      runs = rows.sort_by { |_, campaign| start_of(seasons, campaign) }
        .chunk_while { |(_, a), (_, b)| name_key(a) == name_key(b) }.to_a
      runs.each_with_index.map do |run, index|
        first, last = run.first.last, run.last.last
        following = runs[index + 1]
        naming(team, first, last, seasons, following && start_of(seasons, following.first.last) - 1, nicknames)
      end
    end
    write nicknames.values.sort_by { it.fetch("code") } + namings
  end

  private

  def start_of(seasons, campaign)
    Date.parse(seasons.dig(campaign.dig("references", "season"), "attributes", "start_date").to_s)
  end

  def name_key(campaign)
    campaign.fetch("attributes").values_at("display_name", "abbreviation")
  end

  def naming(team, first, last, seasons, end_date, nicknames)
    display_name, abbreviation = name_key(first)
    territory, nickname = split(display_name)
    first_season, last_season = first.dig("references", "season"), last.dig("references", "season")
    attributes = { "territory" => territory, "abbreviation" => abbreviation, "start_date" => start_of(seasons, first).iso8601 }
    attributes["display_name"] = display_name unless nickname
    attributes["end_date"] = end_date.iso8601 if end_date
    attributes["details"] = { "bounds" => "season_level", "first_season" => first_season, "last_season" => last_season }
    attributes["source"] = { "note" => NOTE, "generator" => "scripts/build_team_namings.rb" }
    references = { "team" => team }
    if nickname
      code = "NICKNAME-#{code_part(nickname)}"
      nicknames[code] ||= record("Nickname", code, { "text" => nickname })
      references["nickname"] = code
    else
      @unsplit << display_name
    end
    record("TeamNaming", "#{team}-NAMING-#{first_season.split('-SEASON_').last}", attributes.compact, references)
  end

  # The longest known nickname that ends the name is its nickname; the rest is
  # the territory. A name that ends in no known nickname stays whole.
  def split(display_name)
    nickname = known_nicknames.find { |known| display_name.end_with?(" #{known}") }
    nickname ? [ display_name.delete_suffix(" #{nickname}"), nickname ] : [ nil, nil ]
  end

  # Current team mascots, plus former nicknames reviewed in sources/team_namings.
  def known_nicknames
    @known_nicknames ||= (@rows.fetch("Team", {}).values.map { |team| team.dig("attributes", "mascot").to_s.strip } + @historical)
      .reject(&:empty?).uniq.sort_by { -it.length }
  end

  def code_part(value)
    value.upcase.gsub(/[^A-Z0-9]+/, "_").delete_prefix("_").delete_suffix("_")
  end

  def record(type, code, attributes, references = {})
    { "type" => type, "code" => code, "attributes" => attributes, "references" => references }
  end

  def write(records)
    @writer.write_batch(@output, { "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "records" => records })
  end
end

if $PROGRAM_NAME == __FILE__
  check = ARGV.delete("--check")
  abort "Usage: ruby scripts/build_team_namings.rb [--check]" unless ARGV.empty?
  builder = TeamNamingsBuilder.new(check: check)
  builder.call
  warn "Names kept whole (no known nickname): #{builder.unsplit.uniq.sort.join(', ')}" if builder.unsplit.any?
end
