---
name: team-visuals
description: Source and record AthleteAce team visuals — logos, uniforms and kits, asset representations, and team color palettes — with exact provenance and honest labeling of illustrative assets. Use when adding or refreshing logos, kit references, local media files, or team colors. Not for player headshots beyond recording verified URLs.
---

# Team visuals

Visuals are owners' works. We record where they came from and what they depict; we don't assert redistribution rights or pretend illustrations are accurate.

## Models

- `Logo` — periods may overlap; concurrent marks are intentional.
- `UniformCampaign` — a design reused across seasons/competitions; `UniformPiece` names its components (no shared garment taxonomy).
- `AssetRepresentation` — one canonical file per owner, format, and view, with content type, byte size, SHA-256, and pinned GitHub repository, commit, and path.
- Team palette — primary/secondary colors; `text_color` is derived (white or near-black by contrast).

Uniform designs and their nicknames are separate from jersey-number assignments.

## Sources

Prefer official brand pages, kit-launch galleries, and provider logo feeds (ESPN team feeds). For each asset record the exact page URL and image URL, capture date, checksum, and representation type. See `sports-seed-sources/references/club-pages.md`.

Player headshots: record verified official URLs only (HEAD request returns an image content type on the capture date). Don't download them; reverify before updating, and don't treat a latest headshot as historical jersey evidence. Example: `sources/nba_player_photos.json`.

## Honest labeling

- Downloaded reference photographs are distinct from authored representations.
- Authored SVG and GLB files are labeled **illustrative**. They demonstrate storage and loading, not accurate geometry, materials, or textures.
- When a source is unavailable (NBA Store, LockerVision), the depiction stays schematic and the README says why.
- Missing historical introduction dates stay unknown.

## Media ingestion workflow

Files live in the independent public `MICharisma/athlete_ace_media` repository, which is not a submodule. Manifests retain original provenance and add `source.github` with `repository`, full 40-character `commit`, and relative `path`. The application's [seed media guide](../../../../../docs/seed-media.md) describes adding files. `canonical_path` remains a logical catalog path, not a runtime file location.

```sh
mise exec -- bundle exec rails db:migrate
mise exec -- bundle exec rails seeds:validate db:seed
mise exec -- bundle exec rails seeds:assets:verify
mise exec -- ruby db/seeds/athlete_ace_data/scripts/build_visual_assets.rb --check
mise exec -- ruby db/seeds/athlete_ace_data/scripts/preview_visual_assets.rb
```

`db:seed` downloads pinned raw files into application Active Storage after importing the catalog. `seeds:assets:import` resumes ingestion separately. Replays verify stored files without fetching them from GitHub again. `seeds:assets:verify` raises on missing, empty, resized, or changed stored files, or when nothing was imported. A nonzero exit means the check failed.

The pilot generator reads `sources/coverage_2026/media.json` offline, including its repository commit and per-file checksums. It does not download original provider URLs. The developer preview uses pinned raw URLs; the application serves stored copies. Docker builds contain no canonical media files.

## Palettes

Team colors currently come from the legacy `sports/*/USA/*` team JSON catalogs and are applied by palette enrichment during `db:seed`, matched by league-qualified entity code (never by name or abbreviation). Palette enrichment **refreshes** recorded colors on replay — an exception to the importer's preservation rule. Use official brand guides as the evidence for new colors and record the source. Teams without recorded palettes (EPL, Utah) render a neutral fallback; that is better than guessed colors.

## Mistakes we've made

- Store and uniform API sources refused automated capture; Knicks garment depictions had to stay schematic.

## References

The application's `docs/team-palettes.md`, `docs/jersey-numbers.md` (uniform section), `docs/seed-library-2026.md` (Preview and verify local assets). Worked example: `sources/coverage_2026/README.md`, `sources/coverage_2026/visual_assets.json`.
