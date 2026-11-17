require "json"
require_relative "lib/seed_catalog"

root = File.expand_path "..", __dir__
check = ARGV.delete "--check"
abort "Usage: ruby scripts/build_nba_media.rb [--check]" unless ARGV.empty?
capture = JSON.parse File.read(File.join(root, "sources/nba_media_2026/capture.json"))
media = JSON.parse File.read(File.join(root, "sources/nba_media_2026/media.json"))
raise "Expected a full media commit SHA" unless media.fetch("commit").match?(/\A[0-9a-f]{40}\z/)
records = [{ "type" => "Figure", "code" => "FIGURE-BKT-NBA-PLAYER-JAMES_LEBRON",
  "attributes" => { "first_name" => "LeBron", "last_name" => "James" },
  "source" => { "url" => "https://www.nba.com/player/2544/lebron-james" } }]
selections = []
renditions = JSON.parse File.read(File.join(root, "sources/nba_media_2026/renditions.json"))
conferences = JSON.parse File.read(File.join(root, "sources/nba_media_2026/conferences.json"))
(capture.fetch("available") + renditions + conferences.fetch("available")).each do |entry|
  logo_code = entry["reuse_logo"] || entry.fetch("code")
  unless entry["reuse_representation"]
    source = entry.slice "url", "asset_url", "captured_on", "original_source", "generated_by", "derived_from"
    if entry.fetch("kind") == "logo"
      records << { "type" => "Logo", "code" => logo_code,
        "attributes" => entry.slice("name", "role"), "references" => { "owner" => entry.fetch("owner") }, "source" => source }
    end
    subject = entry.fetch("kind") == "logo" ? logo_code : entry.fetch("subject", entry["owner"])
    records << { "type" => "AssetRepresentation", "code" => "#{entry.fetch('code')}-FILE-#{entry.fetch('file_format').upcase}",
      "attributes" => entry.slice("file_format", "view", "content_type", "sha256", "byte_size")
        .merge("canonical_path" => "media/#{entry.fetch('path')}", "details" => { "depiction" => entry.fetch("depiction", "source_image") }),
      "references" => { "subject" => subject },
      "source" => source.merge("github" => entry.fetch("github", media.merge("path" => entry.fetch("path")))) }
  end
  if entry.fetch("kind") == "logo" && %w[default primary].include?(entry.fetch("role"))
    selections << { "type" => entry.fetch("owner_type"), "code" => entry.fetch("owner"), "asset" => logo_code }
  elsif entry.fetch("kind") == "portrait" && entry.fetch("view") == "nba_headshot"
    selections << { "type" => "Figure", "code" => entry.fetch("owner"), "asset" => "#{entry.fetch('code')}-FILE-PNG" }
  end
end
raise "Expected 34 primary selections" unless selections.size == 34
writer = SeedCatalog::Writer.new check: check
writer.write_batch File.join(root, "yaml/nba_media_2026/media.yml"), SeedCatalog::ENVELOPE.merge("records" => records.sort_by { |record| record.fetch("code") })
writer.finish codes_path: File.join(root, "sources/nba_media_2026/catalog_codes.json")
primary = JSON.pretty_generate("selections" => selections.sort_by { |selection| selection.fetch("code") }) + "\n"
primary_path = File.join root, "sources/nba_media_2026/primary.json"
if check
  raise "Generated primary selections differ" unless File.read(primary_path) == primary
else
  File.write primary_path, primary
end
puts JSON.generate(records: records.size, reused_files: capture.fetch("available").count { |entry| entry["reuse_representation"] }, primary_selections: selections.size)
