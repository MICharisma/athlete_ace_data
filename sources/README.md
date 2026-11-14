# 2025 starting-year coverage capture

`coverage_2025.json` is a normalized capture of public, official league sources. It stores the team indexes, full source player lists, source URLs, external source keys, roster meaning, and capture date. It is outside `yaml/`, so the Rails importer does not treat it as a seed envelope.

The catalog selects every NBA/NFL/NHL/EPL team for the latest completed season: NBA/NHL/EPL `2025_2026`, NFL `2025`. It selects complete source listings for the Knicks, 49ers, and Blues, and the first two source-listed players for every other team. Source order is retained in this capture; offline generation is deterministic.

The NBA source is its director face-sheet site labeled `2025 season`, with coaching rows excluded. The Knicks listing is a captured roster snapshot, not a complete season appearance union. NFL's year-specific roster sitemap can include reserve/offseason names; the 49ers listing does not assert active-game status. NHL archived club statistics include all skaters and goalies with regular-season appearances, retaining players who departed. EPL's published September 12, 2025 senior registration lists supply the two-player samples; the separate U21 paragraphs are excluded. None of these records asserts contract terms or exact membership dates.

The source article misspells its Tottenham heading `Tottenham Hostspur`; the generator normalizes it to `Tottenham Hotspur`. NBA index shorthand `Philadelphia Sixers`, `OKC Thunder`, and `Portland Trailblazers` is normalized to the established team names. Existing JSON data supplies NBA/NFL abbreviation conventions only; roster observations and team membership come from the official indexes.

Run from the AthleteAce application root:

```sh
# Rebuild YAML from this committed capture without network access.
mise exec -- bundle exec ruby db/seeds/athlete_ace_data/scripts/build_coverage_2025.rb
mise exec -- bundle exec ruby db/seeds/athlete_ace_data/scripts/build_participation.rb

# Explicitly refresh official sources, replace the capture, and regenerate YAML.
mise exec -- bundle exec ruby db/seeds/athlete_ace_data/scripts/build_coverage_2025.rb --refresh
mise exec -- bundle exec ruby db/seeds/athlete_ace_data/scripts/build_participation.rb

mise exec -- bundle exec rails seeds:validate
mise exec -- bundle exec rails db:seed
```

Refresh requires network access and Nokogiri from AthleteAce's bundle. It rejects incomplete team indexes, wrong source seasons, fewer than two source players, and ambiguous name-based codes. External IDs remain capture metadata; generated references use readable catalog codes and reuse the existing pilot's preferred identities and aliases. Review capture/manifest diffs after refreshing a source that can change.

## Participation observations

`build_participation.rb` generates `yaml/participation/organizations.yaml` and `rosters_2025.yaml` offline from the existing coverage capture/manifests. It issues one sporting-club Organization and primary-team affiliation for each of the 114 Teams. It does not identify corporate owners or invent affiliation bounds. The 82 NBA/NFL/EPL Rosters retain their different source categories; only the EPL registration source establishes an effective date. Knicks and 49ers lists are complete for their captured source categories, while other lists remain partial. Capture dates are stored as source dates rather than fabricated observation timestamps. NHL's season-statistics lists do not generate Rosters.

`yaml/participation/nhl_leddy_history.yaml` is a hand-reviewed historical sample using the Blues' March 21, 2022 trade announcement, July 13 contract-extension announcement, and October 11 opening-night roster announcement. Those primary source URLs and publication dates are kept in the manifest. The trade's player movement coverage is partial; omitted trade participants are not deletion instructions. The contract's exact legal date bounds are not inferred from its announcement.

`leddy_game_20220322.json` captures the relevant facts from the NHL's archived gamecenter boxscore for game 2021021008. It stores the official game date, season/type, teams/scores, and Leddy's player statistics. The manifest selects his goals, assists, points, shots, time on ice, and jersey number. Unknown starter status is left unset. It does not expand season statistics into game appearances.

## Player photo references

`nba_player_photos.json` records 17 official NBA headshot URLs for players in the captured Knicks roster. Provider IDs come from `coverage_2025.json`. The headshot URL pattern was observed on the [official Jalen Brunson page](https://www.nba.com/player/1628973/jalen-brunson), and each saved URL returned an image content type to a HEAD request on the capture date. No image files are downloaded. The coverage generator applies these URLs to existing Player definitions with per-record source metadata. These references add no current-team assignments or eligibility claims.

Offline regeneration uses `scripts/build_coverage_2025.rb`. The source JSON retains the verified URLs so seed replay does not make network requests. Reverify URLs before updating that capture; remote latest headshots can change and do not establish historical jersey details.
