# 2026 roster position assignments (pilot)

This batch is the first use of `Position` and `PositionAssignment` records. It defines baseball and football position vocabularies and attaches each player's source-listed position to the 2026 roster entries for four teams:

| League | Teams | Assignments |
| --- | --- | --- |
| MLB | Los Angeles Dodgers (LAD), New York Mets (NYM) | 54 + 64 |
| NFL | Chicago Bears (CHI), San Francisco 49ers (SF) | 82 + 88 |

`report.json` has the per-team counts by position.

## Sources

There is no new capture. The positions come from the `position` field already recorded for every player in `sources/coverage_2026/mlb.json` (MLB Stats API `fullSeason` rosters) and `sources/coverage_2026/nfl.json` (ESPN season rosters), both captured on 2026-10-26. Each assignment attaches to the matching `RosterEntry` in `yaml/coverage_2026/` and carries that team's roster URL.

## What a listing means

An assignment says which position the source roster listed for the player that season. It doesn't say where the player appeared in games, how often, or whether they also played elsewhere. Game-level positions belong on appearances, with an in-game `sequence`. Each roster entry lists one position, except for the Ohtani correction. No assignment is marked `primary`, because the sources don't distinguish a primary position from a secondary one.

- **Shohei Ohtani (LAD)** is listed as `TWP` (Two-Way Player). As a reviewed correction (`SPLITS` in the builder, logged under `splits` in `report.json`), the batch records the two roles that designation combines: `P` and `DH`. That gives him two assignments on one roster entry. The builder fails if the source stops listing him as `TWP`, so the correction can't outlive its premise. `TWP` stays in the vocabulary for other sources.
- **Group listings.** Some players are listed under a group rather than a specific position. In this batch, that's one Mets player listed as `OF` and two Bears players listed as `DB`. Other NFL teams also list `OL`. These assignments reference the group position itself. They never pick a specific child position.

## Vocabularies

`yaml/catalog/BSB/positions.yml` and `yaml/catalog/FTB/positions.yml` are AthleteAce's position lists for those sports. The abbreviations match the source rosters. The names and groupings are curated:

- **Baseball:** IF groups 1B/2B/3B/SS, and OF groups LF/CF/RF. P, C, DH and TWP have no parent group.
- **Football:**
  - Offense, Defense and Special Teams are the top-level groups.
  - OL (OT, G, C) sits under Offense, and DB (CB, S) sits under Defense.
  - PK, P and LS sit under Special Teams.

The builder fails if a source lists a position that isn't in the vocabulary, if a roster or roster entry is missing from the catalog, or if a group is referenced before it is defined.

## Regenerate

From the AthleteAce application root:

```sh
mise exec -- ruby db/seeds/athlete_ace_data/scripts/build_position_assignments_2026.rb
mise exec -- ruby db/seeds/athlete_ace_data/scripts/build_position_assignments_2026.rb --check
mise exec -- bundle exec rails seeds:validate
mise exec -- bundle exec rails db:seed   # run twice: the replay must create 0 and report 0 conflicts
```

To cover more teams, add their abbreviations to `SELECTIONS` in the builder. Every coverage_2026 MLB and NFL team already has listed positions in its capture.
