---
name: sports-seed-sources
description: Capture and verify public sports roster, historical NBA participant, NHL schedule, and team visual sources for the AthleteAce seed catalog. Use when fetching from the NHL, MLB StatsAPI, ESPN, Basketball Reference, or official club pages, or when refreshing a coverage capture. Not for live scores or unsourced roster generation.
---

# Sports seed sources

Use the checkout's pinned Ruby and bundle for the scripts. Inspect the current target seasons before fetching; the installed scripts target 2026 calendar seasons and 2026/27 split-year seasons. A capture date does not select a season.

Read `sources/coverage_2026/README.md` for source meanings and known failures, and the application's `docs/seed-library-2026.md` before importing or applying schedule changes. Decide what each list means with `source-evidence` before fetching.

## Choose the provider

Load only the reference for the provider you need:

| Provider | Use for | Reference |
| --- | --- | --- |
| NHL web API | NHL season rosters, full schedules | `references/nhl.md` |
| MLB Stats API | MLB teams, full-season inventories, venues | `references/mlb.md` |
| ESPN site API | NBA, NFL, MLS, EPL, UCL rosters; season schedules; logos | `references/espn.md` |
| Basketball Reference | Historical NBA appearance unions | `references/basketball-reference.md` |
| Official club pages | Logos, kits, uniforms, announcements | `references/club-pages.md` |

Adding a provider? Create `references/<provider>.md` with: endpoints, season-label convention, what the list means, required count checks, and that provider's demonstrated mistakes.

## Season labels differ by provider

NBA and NHL split seasons are requested by **ending** year on ESPN (2026/27 → `2027`) but by the full `YYYYYYYY` pair on the NHL API (`20262027`). Soccer on ESPN uses the **starting** year. NFL and MLB use the calendar year. Always confirm the season the response reports.

## Capture, regenerate, and verify

Use `scripts/capture_2026.rb` for explicit network capture and `scripts/build_2026.rb` for offline generation. Pass the actual observation date with the required `--as-of` option. `--leagues` limits capture scope. `--refresh` replaces HTTP cache entries; omit it to reuse the ignored cache. The scripts use browser-style public request headers and fail on HTTP errors, missing rosters, and wrong team or season counts.

```sh
mise exec -- bundle exec ruby db/seeds/athlete_ace_data/scripts/capture_2026.rb --refresh --as-of YYYY-MM-DD [--leagues nba,nhl]
mise exec -- bundle exec ruby db/seeds/athlete_ace_data/scripts/build_2026.rb
mise exec -- bundle exec ruby db/seeds/athlete_ace_data/scripts/build_2026.rb --check
mise exec -- bundle exec rails seeds:validate db:seed
```

Review `sources/coverage_2026/report.json` (coverage, number conflicts, identity bindings) and the manifest diff before importing. Same-capture replay must create zero records and report zero conflicts.

Current captured numbers seed jersey-number periods; NHL schedule updates need an explicit task. Both are covered in `historical-claims`.

## Demonstrated mistakes across providers

- An echoed year or season-shaped URL is insufficient; check a known historical player or transfer.
- NBA Stats reset or timed out during the 2026 capture. LockerVision's uniform API returned unauthorized, and NBA Store pages blocked direct capture. Do not bypass those controls or treat those sources as exercised downloads.
- Preserve stable provider IDs; never fabricate surnames for single-name players.
