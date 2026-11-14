require "fileutils"
require "json"
require "yaml"

# The seed library's two layers (see CONTRIBUTING.md, "Library layout"):
# identity records live once each in yaml/catalog/, in a file computed from
# their code; batches hold observations. Generators write through a Writer,
# which sends identities to the catalog (merging with what is there) and
# writes the rest to the batch file. tools/seed_layout.py lints the result
# with the same path rules.
module SeedCatalog
  ROOT = File.expand_path("../..", __dir__)
  LIBRARY = File.join(ROOT, "yaml")
  CATALOG = "catalog".freeze
  ENVELOPE = { "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA" }.freeze
  IDENTITY_TYPES = %w[Year Country State City Stadium Federation Sport Position Figure League Conference Division
    Team Organization Season Campaign Player].freeze

  # Scope keys the importer reads for each identity type (LibraryImporter's
  # SCOPE_ASSOCIATIONS plus Campaign's inferred season context and League's
  # country jurisdiction). Other inherited context is dropped on standalone records.
  SCOPE_KEYS = {
    "State" => %w[country], "City" => %w[state], "Stadium" => %w[city], "League" => %w[sport country],
    "Conference" => %w[league], "Division" => %w[league conference], "Team" => %w[league], "Season" => %w[league year],
    "Player" => %w[sport figure], "Position" => %w[sport],
    "Campaign" => %w[team league year season stadium city conference division]
  }.freeze

  class Conflict < StandardError; end
  class Unplaced < StandardError; end

  module_function

  def initial(name)
    letter = name[0].to_s
    letter.match?(/[A-Za-z]/) ? letter : "0"
  end

  # The catalog file (relative to yaml/) that owns an identity record, or nil
  # for an observation. Mirrors canonical_path in tools/seed_layout.py.
  def canonical_path(type, code)
    parts = code.split("-")
    unplaced = -> { raise Unplaced, "#{type} #{code} has no catalog rule" }
    path = case type
           when "Year" then "years"
           when "Country", "State", "City" then "places/#{parts[1]}"
           when "Stadium" then "venues/#{parts[1]}"
           when "Federation" then "federations"
           when "Sport" then "#{parts[1]}/sport"
           when "Position" then "#{parts[0]}/positions"
           when "Figure" then "figures/#{initial(parts[-1])}"
           when "League"
             unplaced.call unless parts.size == 3 && parts[1] == "LEAGUE"
             "#{parts[0]}/#{parts[2]}/league"
           when "Conference", "Division"
             unplaced.call if parts.size < 3
             "#{parts[0]}/#{parts[1]}/league"
           when "Team"
             if parts.size >= 3 && parts[1] == "CLUB" then "#{parts[0]}/clubs"
             elsif parts.size >= 4 && parts[2] == "TEAM" then "#{parts[0]}/#{parts[1]}/teams"
             else unplaced.call
             end
           when "Organization"
             parts.size >= 4 && parts[2] == "ORG" ? "#{parts[0]}/#{parts[1]}/organizations" : "organizations"
           when "Season"
             unplaced.call unless parts.size == 3 && parts[2].start_with?("SEASON_")
             "#{parts[0]}/#{parts[1]}/seasons"
           when "Campaign"
             unplaced.call unless parts.size >= 5 && parts[2].start_with?("SEASON_") && parts[3] == "TEAM"
             "#{parts[0]}/#{parts[1]}/campaigns/#{parts[2].delete_prefix('SEASON_')}"
           when "Player"
             if parts.size == 2 then "players/#{initial(parts[1])}"
             else
               unplaced.call if parts.size < 3
               "#{parts[0]}/#{parts[1]}/players/#{initial(parts[-1])}"
             end
           end
    path && "#{CATALOG}/#{path}.yml"
  end

  def identity?(record)
    IDENTITY_TYPES.include?(record.fetch("type"))
  end

  # A record as it stands alone in the catalog: inherited scope and source made explicit.
  def standalone(record, scope: {}, source: nil)
    row = { "type" => record.fetch("type"), "code" => record.fetch("code") }
    row["aliases"] = record["aliases"].uniq.sort if record["aliases"]&.any?
    row["attributes"] = record.fetch("attributes", {})
    row["references"] = record.fetch("references", {})
    effective_scope = scope.merge(record.fetch("scope", {})).slice(*SCOPE_KEYS.fetch(record.fetch("type"), []))
    row["scope"] = effective_scope if effective_scope.any?
    effective_source = source || record["source"] ? (source || {}).merge(record["source"] || {}) : nil
    row["source"] = effective_source if effective_source
    row
  end

  # Merges an incoming definition into an existing one. New keys are added;
  # equal values are kept; a different value for the same key is a conflict.
  # The existing source is kept, so provenance stays with the first definition.
  def merge(existing, incoming)
    raise Conflict, "#{incoming['code']} is a #{incoming['type']} here and a #{existing['type']} in the catalog" unless existing["type"] == incoming["type"]
    merged = existing.dup
    %w[attributes references scope].each do |section|
      next unless incoming[section]
      target = (existing[section] || {}).dup
      incoming[section].each do |key, value|
        if target.key?(key) && target[key] != value
          raise Conflict, "#{incoming['code']} #{section}.#{key}: catalog has #{target[key].inspect}, incoming #{value.inspect}"
        end
        target[key] = value
      end
      merged[section] = target
    end
    aliases = (Array(existing["aliases"]) + Array(incoming["aliases"])).uniq.sort
    merged["aliases"] = aliases if aliases.any?
    merged["source"] ||= incoming["source"] if incoming["source"]
    order(merged)
  end

  # Whether the catalog definition already says everything the incoming one does.
  def covers?(existing, incoming)
    return false unless existing && existing["type"] == incoming["type"]
    %w[attributes references scope].all? { |section| (incoming[section] || {}).all? { |key, value| (existing[section] || {})[key] == value } } &&
      (Array(incoming["aliases"]) - Array(existing["aliases"])).empty?
  end

  def order(record)
    %w[type code aliases attributes references scope source].filter_map { |key| [ key, record[key] ] if record.key?(key) }.to_h
  end

  def dump(document)
    YAML.dump(JSON.parse(JSON.generate(document)))
  end

  def read_catalog(relative)
    path = File.join(LIBRARY, relative)
    return {} unless File.file?(path)
    YAML.safe_load(File.read(path, encoding: "UTF-8")).fetch("records").to_h { |row| [ row.fetch("code"), row ] }
  end

  def write_catalog(relative, records)
    path = File.join(LIBRARY, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, dump(ENVELOPE.merge("records" => records.values.sort_by { |row| row.fetch("code") })))
  end

  # Splits a generator's output: identities to the catalog, observations to
  # the batch file. In check mode nothing is written; the batch file must
  # match exactly and the catalog must already cover every identity.
  class Writer
    attr_reader :identities

    def initialize(check: false)
      @check = check
      @identities = Hash.new { |hash, key| hash[key] = {} }
      @written = []
    end

    # document: a micharisma-seeds/v1 envelope, flat or with nested groups.
    # Returns the observation document written, or nil when none remain.
    def write_batch(path, document)
      batch = split(JSON.parse(JSON.generate(document)), {}, nil)
      observations = batch.key?("records") || batch.key?("groups")
      if @check
        expected = observations ? SeedCatalog.dump(batch) : nil
        actual = File.file?(path) ? File.read(path, encoding: "UTF-8") : nil
        raise "Generated file differs: #{path}" unless actual == expected
      elsif observations
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, SeedCatalog.dump(batch))
      elsif File.file?(path)
        File.delete(path)
      end
      @written << path
      observations ? batch : nil
    end

    # Removes identities from a node (moving them to the catalog with the
    # scope and source they inherit there) and drops groups left empty.
    def split(node, scope, source)
      scope = scope.merge(node.fetch("scope", {}))
      source = node["source"] ? (source || {}).merge(node["source"]) : source
      kept = node.dup
      if node.key?("records")
        records = node["records"].reject do |record|
          next false unless SeedCatalog.identity?(record)
          add(SeedCatalog.standalone(record, scope: scope, source: source))
          true
        end
        records.empty? ? kept.delete("records") : kept["records"] = records
      end
      if node.key?("groups")
        groups = node["groups"].map { |group| split(group, scope, source) }.select { |group| group.key?("records") || group.key?("groups") }
        groups.empty? ? kept.delete("groups") : kept["groups"] = groups
      end
      kept
    end

    def add(record)
      relative = SeedCatalog.canonical_path(record.fetch("type"), record.fetch("code"))
      bucket = @identities[relative]
      code = record.fetch("code")
      bucket[code] = bucket.key?(code) ? SeedCatalog.merge(bucket[code], record) : SeedCatalog.order(record)
    end

    # Merge collected identities into the catalog, or verify it covers them.
    # codes_path, when given, records the identity codes this generator
    # contributes (sources/<batch>/catalog_codes.json), so tasks can select a
    # batch's own identities from the shared catalog.
    def finish(codes_path: nil)
      problems = []
      @identities.sort.each do |relative, records|
        catalog = SeedCatalog.read_catalog(relative)
        if @check
          records.each_value { |record| problems << "#{relative} lacks or contradicts #{record['code']}" unless SeedCatalog.covers?(catalog[record['code']], record) }
        else
          records.each_value { |record| catalog[record["code"]] = catalog.key?(record["code"]) ? SeedCatalog.merge(catalog[record["code"]], record) : record }
          SeedCatalog.write_catalog(relative, catalog)
        end
      end
      raise "Catalog out of date:\n  #{problems.first(20).join("\n  ")}#{problems.size > 20 ? "\n  ... #{problems.size - 20} more" : ''}" if problems.any?
      record_codes(codes_path) if codes_path
      @identities.values.sum(&:size)
    end

    def record_codes(path)
      contents = JSON.pretty_generate("codes" => @identities.values.flat_map(&:keys).sort) + "\n"
      if @check
        raise "Generated file differs: #{path}" unless File.file?(path) && File.read(path, encoding: "UTF-8") == contents
      else
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, contents)
      end
    end
  end
end
