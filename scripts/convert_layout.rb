require "json"
require_relative "lib/seed_catalog"
require_relative "../../../../lib/micharisma_seeders/lib/micharisma_seeders"

# One-time restructure into the catalog/batch layout (CONTRIBUTING.md,
# "Library layout"). Every identity record moves to its canonical catalog
# file with its inherited scope and source made explicit; duplicate
# definitions merge (first file in path order keeps its source); batch
# files keep only their observations and are removed when nothing remains.
# Codes are unchanged, so a database replay must create and conflict nothing.
#
#   ruby scripts/convert_layout.rb [--dry-run]
class LayoutConversion
  def initialize(dry_run: false)
    @dry_run = dry_run
    registry = MICharismaSeeders::SequenceRegistry.read(File.join(SeedCatalog::LIBRARY, "entity_sequences.yaml"))
    @reader = MICharismaSeeders::Reader.new(registry: registry)
    @catalog = Hash.new { |hash, key| hash[key] = {} }
    @report = { "moved" => Hash.new(0), "merged" => Hash.new(0), "merged_with_new_fields" => [], "rewritten" => [], "removed" => [] }
  end

  def files
    Dir.glob(File.join(SeedCatalog::LIBRARY, "**/*.{yaml,yml,json}")).sort
      .reject { |path| File.basename(path) == "entity_sequences.yaml" || relative(path).start_with?("#{SeedCatalog::CATALOG}/") }
  end

  def relative(path)
    path.delete_prefix("#{SeedCatalog::LIBRARY}/")
  end

  def collect(path)
    moved = 0
    @reader.read(path).each do |row|
      next unless SeedCatalog::IDENTITY_TYPES.include?(row.type)
      record = SeedCatalog.standalone({ "type" => row.type, "code" => row.code, "aliases" => row.aliases,
        "attributes" => row.attributes || {}, "references" => row.references || {} }, scope: row.scope || {}, source: row.source)
      target = SeedCatalog.canonical_path(row.type, row.code)
      bucket = @catalog[target]
      if bucket.key?(row.code)
        merged = SeedCatalog.merge(bucket[row.code], record)
        @report["merged"][row.type] += 1
        @report["merged_with_new_fields"] << "#{row.code} (#{relative(path)})" if merged != bucket[row.code]
        bucket[row.code] = merged
      else
        bucket[row.code] = SeedCatalog.order(record)
      end
      @report["moved"][row.type] += 1
      moved += 1
    end
    moved
  end

  def without_identities(node)
    filtered = node.dup
    filtered["records"] = node["records"].reject { |record| SeedCatalog.identity?(record) } if node.key?("records")
    filtered.delete("records") if filtered["records"] == []
    if node.key?("groups")
      groups = node["groups"].map { |group| without_identities(group) }.reject { |group| !group.key?("records") && !group.key?("groups") }
      groups.empty? ? filtered.delete("groups") : filtered["groups"] = groups
    end
    filtered
  end

  def rewrite(path)
    document = MICharismaSeeders::SafeDocument.read(path)
    document = document.to_h if document.respond_to?(:to_h) && !document.is_a?(Hash)
    remaining = without_identities(JSON.parse(JSON.generate(document)))
    if remaining.key?("records") || remaining.key?("groups")
      contents = path.end_with?(".json") ? JSON.pretty_generate(remaining) + "\n" : SeedCatalog.dump(remaining)
      File.write(path, contents) unless @dry_run
      @report["rewritten"] << relative(path)
    else
      File.delete(path) unless @dry_run
      @report["removed"] << relative(path)
    end
  end

  def run
    files.each { |path| rewrite(path) if collect(path).positive? }
    @catalog.sort.each { |relative_path, records| SeedCatalog.write_catalog(relative_path, records) } unless @dry_run
    summary = { "catalog_files" => @catalog.size, "identities" => @catalog.values.sum(&:size),
      "moved" => @report["moved"].sort.to_h, "duplicate_definitions_merged" => @report["merged"].sort.to_h,
      "merges_that_added_fields" => @report["merged_with_new_fields"].size,
      "batch_files_rewritten" => @report["rewritten"].size, "batch_files_removed" => @report["removed"] }
    puts JSON.pretty_generate(summary)
    @report
  end
end

if $PROGRAM_NAME == __FILE__
  dry_run = ARGV.delete("--dry-run")
  abort "Usage: ruby scripts/convert_layout.rb [--dry-run]" unless ARGV.empty?
  report = LayoutConversion.new(dry_run: dry_run).run
  File.write(File.join(SeedCatalog::ROOT, "tmp_layout_merges.txt"), report["merged_with_new_fields"].join("\n") + "\n") if dry_run
end
