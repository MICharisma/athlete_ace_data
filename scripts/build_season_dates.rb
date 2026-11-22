require "json"
require_relative "lib/seed_catalog"

# Adds the captured first and last regular-season game dates to the NBA, NFL,
# NHL and MLB Season definitions in the catalog, offline. A season still in
# progress on the capture date gets no end date.
class SeasonDatesBuilder
  ROOT = File.expand_path("..", __dir__)

  def initialize(check: false, source: File.join(ROOT, "sources/season_dates"))
    @source = source
    @writer = SeedCatalog::Writer.new(check: check)
  end

  def call
    capture = JSON.parse(File.read(File.join(@source, "season_dates.json"), encoding: "UTF-8"))
    capture.fetch("seasons").each do |season|
      code = season.fetch("season")
      relative = SeedCatalog.canonical_path("Season", code)
      raise "#{code} is not defined in #{relative}" unless SeedCatalog.read_catalog(relative).key?(code)

      attributes = { "start_date" => season.fetch("first_game_date"), "end_date" => season["last_game_date"] }.compact
      @writer.add({ "type" => "Season", "code" => code, "attributes" => attributes })
    end
    count = @writer.finish(codes_path: File.join(@source, "catalog_codes.json"))
    puts({ seasons: count }.to_json)
  end
end

if $PROGRAM_NAME == __FILE__
  check = ARGV.delete("--check")
  abort "Usage: ruby scripts/build_season_dates.rb [--check]" unless ARGV.empty?
  SeasonDatesBuilder.new(check: check).call
end
