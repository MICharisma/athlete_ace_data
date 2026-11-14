require "digest"
require "fileutils"
require "json"
require "net/http"
require "yaml"

class VisualAssetPilot
  ROOT = File.expand_path("..", __dir__)
  AS_OF = "2026-10-26"
  BLUES_SOURCE = "https://www.nhl.com/blues/team/brand"
  ARSENAL_SOURCE = "https://www.arsenal.com/news/gallery-2627-adidas-home-kit-launches-in-the-armoury-afAJd0y8JygH"
  KNICKS_SOURCE = "https://store.nba.com/new-york-knicks/unisex-new-york-knicks-jalen-brunson-nike-white-swingman-jersey-association-edition/t-25470720+p-469981676139465+z-9-3762950839"
  BLUES_IMAGES = {
    "Home" => "https://media.d3.nhle.com/image/private/t_ratio1_1-size30/f_auto/prd/tvupl7zkynfkf5gtp1ea.jpg",
    "Away" => "https://media.d3.nhle.com/image/private/t_ratio1_1-size30/f_auto/prd/gjiy1lupxlpnmxt1mkxw.jpg",
    "Third" => "https://media.d3.nhle.com/image/private/t_ratio1_1-size30/f_auto/prd/c2nzm1e6tp2apnmdr3o9.jpg"
  }.freeze

  def initialize(check: false, download: false)
    @check, @download = check, download
    @records = []
    @gallery = []
    FileUtils.mkdir_p(File.join(ROOT, "media/pilot")) unless check
  end

  def add(type, code, attributes, references, source)
    @records << { "type" => type, "code" => code, "attributes" => attributes, "references" => references, "source" => source }
  end

  def save(path, bytes)
    if @check
      raise "File differs: #{path}" unless File.file?(path) && File.binread(path) == bytes.b
    else
      File.binwrite(path, bytes)
    end
  end

  def asset(subject, filename, source:, bytes: nil, view: "default", depiction: "source_image")
    relative = "media/pilot/#{filename}"
    path = File.join(ROOT, relative)
    if bytes
      save(path, bytes)
    elsif @download
      uri = URI(source.fetch("asset_url"))
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
        http.get(uri.request_uri, "User-Agent" => "Mozilla/5.0")
      end
      raise "HTTP #{response.code}: #{uri}" unless response.is_a?(Net::HTTPSuccess)
      raise "Expected an image: #{uri}" unless response["content-type"].to_s.start_with?("image/")
      save(path, response.body)
    end
    raise "Missing local asset #{path}; run with --download" unless File.file?(path)
    format = File.extname(filename).delete_prefix(".")
    content_type = { "svg" => "image/svg+xml", "png" => "image/png", "jpg" => "image/jpeg", "webp" => "image/webp", "glb" => "model/gltf-binary" }.fetch(format)
    add("AssetRepresentation", "#{subject}-FILE-#{filename.upcase.gsub(/[^A-Z0-9]+/, '_')}", {
      "canonical_path" => relative, "file_format" => format, "content_type" => content_type, "view" => view,
      "sha256" => Digest::SHA256.file(path).hexdigest, "byte_size" => File.size(path), "details" => { "depiction" => depiction }
    }, { "subject" => subject }, source)
    relative
  end

  def schematic_svg(color, accent, piece)
    shape = piece == "shorts" ? '<path d="M68 45H232L247 225H170L150 140L130 225H53Z"/>' :
      '<path d="M104 28L126 48H174L196 28L248 72L219 115L199 99V235H101V99L81 115L52 72Z"/>'
    %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 270"><title>Schematic #{piece}, illustrative proof of concept</title><g fill="#{color}" stroke="#{accent}" stroke-width="9" stroke-linejoin="round">#{shape}</g><text x="150" y="260" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#64748b">Illustrative geometry</text></svg>)
  end

  def schematic_glb(color)
    positions, indices = [], []
    boxes = [ [ -0.45, 0.05, -0.08, 0.45, 1.25, 0.08 ], [ -0.7, 0.9, -0.08, -0.45, 1.2, 0.08 ],
      [ 0.45, 0.9, -0.08, 0.7, 1.2, 0.08 ], [ -0.45, -0.75, -0.08, -0.03, 0.0, 0.08 ], [ 0.03, -0.75, -0.08, 0.45, 0.0, 0.08 ] ]
    boxes.each do |x0, y0, z0, x1, y1, z1|
      offset = positions.size / 3
      positions.concat([ [ x0, y0, z0 ], [ x1, y0, z0 ], [ x1, y1, z0 ], [ x0, y1, z0 ], [ x0, y0, z1 ], [ x1, y0, z1 ], [ x1, y1, z1 ], [ x0, y1, z1 ] ].flatten)
      indices.concat([ 0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7, 0, 1, 5, 0, 5, 4, 3, 7, 6, 3, 6, 2, 0, 4, 7, 0, 7, 3, 1, 2, 6, 1, 6, 5 ].map { |index| offset + index })
    end
    vertices = positions.pack("e*")
    binary = vertices + indices.pack("S<*")
    rgb = color.delete_prefix("#").scan(/../).map { |hex| hex.to_i(16) / 255.0 }
    document = { asset: { version: "2.0", generator: "AthleteAce illustrative uniform pilot" }, scene: 0,
      scenes: [ { nodes: [ 0 ] } ], nodes: [ { mesh: 0 } ], buffers: [ { byteLength: binary.bytesize } ],
      bufferViews: [ { buffer: 0, byteOffset: 0, byteLength: vertices.bytesize, target: 34962 },
        { buffer: 0, byteOffset: vertices.bytesize, byteLength: indices.size * 2, target: 34963 } ],
      accessors: [ { bufferView: 0, componentType: 5126, count: positions.size / 3, type: "VEC3", min: [ -0.7, -0.75, -0.08 ], max: [ 0.7, 1.25, 0.08 ] },
        { bufferView: 1, componentType: 5123, count: indices.size, type: "SCALAR" } ],
      materials: [ { pbrMetallicRoughness: { baseColorFactor: [ *rgb, 1 ], metallicFactor: 0, roughnessFactor: 1 }, doubleSided: true } ],
      meshes: [ { primitives: [ { attributes: { POSITION: 0 }, indices: 1, material: 0 } ] } ] }
    json = JSON.generate(document)
    json += " " * ((4 - json.bytesize % 4) % 4)
    binary += "\0" * ((4 - binary.bytesize % 4) % 4)
    [ 0x46546c67, 2, 12 + 8 + json.bytesize + 8 + binary.bytesize ].pack("L<*") +
      [ json.bytesize, 0x4e4f534a ].pack("L<*") + json + [ binary.bytesize, 0x004e4942 ].pack("L<*") + binary
  end

  def logo(team, name, role, filename, asset_url, url)
    code = "#{team}-LOGO-#{role.upcase}"
    source = { "url" => url, "asset_url" => asset_url, "captured_on" => AS_OF }
    add("Logo", code, { "name" => name, "role" => role, "ongoing" => true }, { "team" => team }, source)
    path = asset(code, filename, source: source)
    @gallery << { "name" => name, "path" => path, "kind" => "Logo" }
  end

  def uniform(team:, name:, role:, color:, accent:, source_url:, photograph: nil, campaigns: [])
    code = "#{team}-UNIFORM-#{role.upcase}"
    source = { "url" => source_url, "captured_on" => AS_OF }
    add("Uniform", code, { "name" => name, "role" => role, "details" => { "coverage" => "selected_visual_components" } }, { "team" => team }, source)
    campaigns.each do |campaign|
      add("UniformCampaign", "#{code}-USE-#{campaign}", {}, { "uniform" => code, "campaign" => campaign }, source)
    end
    if photograph
      path = asset(code, "#{role}-#{team.downcase}-reference.jpg", source: source.merge("asset_url" => photograph), view: "reference")
      @gallery << { "name" => "#{name}, source photograph", "path" => path, "kind" => "Reference" }
    end
    pieces = team.start_with?("HCK") ? [ "sweater", "pants" ] : [ "jersey", "shorts" ]
    pieces.each do |piece|
      piece_code = "#{code}-PIECE-#{piece.upcase}"
      add("UniformPiece", piece_code, { "name" => piece }, { "uniform" => code }, source)
      filename = "#{team.downcase}-#{role}-#{piece}.svg"
      geometry_piece = %w[shorts pants].include?(piece) ? "shorts" : "jersey"
      path = asset(piece_code, filename, source: source.merge("generated_by" => "scripts/build_visual_assets.rb"),
        bytes: schematic_svg(color, accent, geometry_piece), view: "front", depiction: "illustrative_schematic")
      @gallery << { "name" => "#{name}, #{piece}", "path" => path, "kind" => "Illustrative SVG" }
    end
    path = asset(code, "#{team.downcase}-#{role}.glb", source: source.merge("generated_by" => "scripts/build_visual_assets.rb"),
      bytes: schematic_glb(color), view: "whole", depiction: "illustrative_schematic")
    @gallery << { "name" => "#{name}, 3D", "path" => path, "kind" => "Illustrative GLB" }
  end

  def run
    nba = JSON.parse(File.read(File.join(ROOT, "sources/coverage_2026/nba.json")))
    knicks = nba.fetch("teams").find { |team| team.fetch("source_id") == "18" }
    logo("BKT-NBA-TEAM-NYK", "Knicks primary logo", "primary", "knicks-primary.png", knicks.fetch("logos").first.fetch("href"), knicks.fetch("url"))
    secondary = knicks.fetch("logos").find { |entry| entry.fetch("rel").include?("secondary_logo_on_white_color") }
    logo("BKT-NBA-TEAM-NYK", "Knicks secondary logo", "secondary", "knicks-secondary.png", secondary.fetch("href"), knicks.fetch("url"))
    logo("HCK-NHL-TEAM-STL", "Blues Blue Note", "primary", "blues-primary.svg", "https://assets.nhle.com/logos/nhl/svg/STL_light.svg", BLUES_SOURCE)
    logo("HCK-NHL-TEAM-STL", "Blues Fleur", "fleur", "blues-fleur.jpg", "https://media.d3.nhle.com/image/private/t_ratio1_1-size30/f_auto/prd/i4bpk0uecfyexiy8wsdq.jpg", BLUES_SOURCE)
    logo("SOC-EPL-TEAM-ARS", "Arsenal crest", "primary", "arsenal-primary.png", "https://a.espncdn.com/i/teamlogos/soccer/500/359.png", "https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/teams/359")
    uniform(team: "BKT-NBA-TEAM-NYK", name: "Knicks Association Edition", role: "association", color: "#ffffff", accent: "#f58426", source_url: KNICKS_SOURCE)
    uniform(team: "SOC-EPL-TEAM-ARS", name: "Arsenal 2026/27 home", role: "home_2026", color: "#ef0107", accent: "#ffffff", source_url: ARSENAL_SOURCE,
      photograph: "https://assets.arsenal.com/prod/images/gm_preview/5787f51e059c-dsc58983pn379aa.jpg",
      campaigns: [ "SOC-EPL-SEASON_2026_2027-TEAM-ARS", "SOC-UCL-SEASON_2026_2027-TEAM-ARS" ])
    BLUES_IMAGES.each do |name, image|
      uniform(team: "HCK-NHL-TEAM-STL", name: "Blues #{name.downcase} uniform", role: name.downcase, color: name == "Away" ? "#ffffff" : "#0061aa", accent: "#fcb514", source_url: BLUES_SOURCE,
        photograph: image, campaigns: [ "HCK-NHL-SEASON_2025_2026-TEAM-STL", "HCK-NHL-SEASON_2026_2027-TEAM-STL" ])
    end
    manifest = { "format" => "micharisma-seeds/v1", "namespace" => "MIC", "catalog" => "ALA", "records" => @records }
    save(File.join(ROOT, "yaml/coverage_2026/visual_assets.yaml"), YAML.dump(JSON.parse(JSON.generate(manifest))))
    save(File.join(ROOT, "sources/coverage_2026/visual_assets.json"), JSON.pretty_generate(@gallery) + "\n")
    puts JSON.pretty_generate(@records.group_by { |record| record.fetch("type") }.transform_values(&:size))
  end
end

if $PROGRAM_NAME == __FILE__
  check, download = ARGV.delete("--check"), ARGV.delete("--download")
  abort "Usage: ruby scripts/build_visual_assets.rb [--download|--check]" unless ARGV.empty? && !(check && download)
  VisualAssetPilot.new(check: check, download: download).run
end
