---
name: seed-identity
description: Assign and reconcile stable entity codes, aliases, and Figure identities for AthleteAce seeds; bind provider IDs to catalog codes; resolve homonyms, renamed teams, and abbreviation collisions. Use whenever a batch introduces or matches people, teams, venues, or places. Not for manifest syntax (see manifest-authoring).
---

# Seed identity

Identity is the hardest part of curation and the easiest to get silently wrong. A code is issued once and stays bound to the same real-world thing while its display facts change.

## Code conventions

Codes are uppercase, local to the `MIC-ALA` catalog (supplied by the envelope), and use `-` between components and `_` inside a component. Follow the patterns already in `yaml/`:

| Type | Pattern | Example |
| --- | --- | --- |
| Sport / League | `SPORT-{SPT}`, `{SPT}-LEAGUE-{LG}` | `SPORT-BKT`, `BKT-LEAGUE-NBA` |
| Team | `{SPT}-{LG}-TEAM-{ABBR}` | `BKT-NBA-TEAM-NYK` |
| Player | `{SPT}-{LG}-PLAYER-{LAST}_{FIRST}` | `BKT-NBA-PLAYER-ACUFF_JR_DARIUS` |
| Figure | `FIGURE-{LAST}_{FIRST}` (provisional) | `FIGURE-KERR_STEVE` |
| Year / Season | `YEAR-{YYYY}`, `{SPT}-{LG}-SEASON_{LABEL}` | `BKT-NBA-SEASON_2022_2023` |
| Campaign | `{SEASON}-TEAM-{ABBR}` | `BKT-NBA-SEASON_2022_2023-TEAM-NYK` |
| Country / State / City | ISO-based | `COUNTRY-US`, `STATE-CA-AB`, `CITY-CA-AB-CALGARY` |
| Stadium | `STADIUM-{CC}-{ST}-{CITY}-{NAME}` | `STADIUM-CA-AB-EDMONTON-ROGERS_PLACE` |

A team code's league component is catalog qualification only. Fulham's `SOC-EPL-TEAM-FUL` stays one club when its Campaign is in the Championship. Never create a second Team because a club changed league or city.

Never put database IDs in codes or references. File and directory names never determine identity.

## Aliases

When an entity gains another valid spelling or a canonical code is adopted, keep the old code as an alias rather than re-issuing. The Raiders are `FTB-NFL-TEAM-RAIDERS` with `FTB-NFL-TEAM-OAK` and `FTB-NFL-TEAM-LV` aliases; annual display names live on Campaigns. Conflicting aliases abort the import, which is the desired failure.

## Figures and players

- A `Figure` is one human across athletic profiles and staff roles; every Player belongs to exactly one Figure. Deion Sanders has several Players, one Figure.
- Names live on the Figure by purpose: `name`, `short_name`, `sort_name`, `name_segments`, `alternate_names` (other scripts, legal names), `nicknames`. Don't force single-name or non-Western names into first + last; set the purpose fields explicitly.
- Use `FIGURE-` for provisional codes. Rizz assigns canonical `MIC-RZZ-…` codes later through `rizz:sync_figures`; the provisional code stays as an alias. Seeding never calls Rizz.
- Reference the Figure from the Player (`references.figure` or `scope.figure`). Never write `Person` records or reverse `Figure → Player` links.
- A player's debut-team code (e.g. `BKT-NBA-LAL-2017-HART_JOSH`) is an identity anchor, not a current-team claim.

Places adopt Rizz codes the same way via `rizz:sync_places` (ISO 3166-1 / 3166-2 matching). Keep using `COUNTRY-`/`STATE-`/`CITY-` codes in manifests; they stay bound as aliases.

## Binding provider IDs

Generators keep a bindings record mapping `(provider, source_id) → code` with a reconciliation basis. The 2026 capture uses three bases, recorded in `sources/coverage_2026/report.json`:

- `existing_official_provider_id` — the provider ID already bound in the catalog (strongest).
- `existing_unambiguous_catalog_name` — exactly one existing catalog record has this name in this sport.
- `new_provider_identity` — no existing record; issue a new code.

Name matching happens only in generators, and only when unambiguous. The database importer never matches by name or abbreviation. Ambiguous matches fail generation and need a human decision recorded in the registry.

## Levels and genders

- Men's and women's competitions are separate Leagues with separate Teams (NBA/WNBA; `BKT-LEAGUE-NCAA_D1_MEN`/`_WOMEN`). One school's two programs are two Teams.
- Don't match college players to professional players by name. Link them only through a shared provider ID. ESPN athlete IDs carry over to the pros, so `BKT-ESPN-PLAYER_{id}` aliases make that link.
- In a league with conferences but no divisions (most of NCAA), the Membership references `league` and `conference` only.

## Homonyms and collisions

- Two different people with one name keep distinct codes, disambiguated by provider ID: `HCK-NHL-PLAYER-PETTERSSON_ELIAS_SOURCE_8480012` and `…_SOURCE_8483678`.
- Abbreviations are not global: Bayern Munich and Manchester United can both be `MUN`. Identify clubs by provider club ID (ESPN club IDs are shared across EPL and Champions League).
- The same club in several competitions is one Team with several Campaigns, not several Teams.
- Distinct places with one name stay distinct by parent: Kansas City, Kansas vs Kansas City, Missouri.
- A new building with an old name gets a new code (Buffalo's `…HIGHMARK_STADIUM_2026`).

## When unsure

Surface it rather than settle it: list the candidates, their evidence, and the proposed binding in the batch README or report, and leave generation failing until reviewed. Don't merge two people because they share a name, and don't split one person because sources spell them differently — record the spellings as aliases or alternate names.

## Mistakes we've made

- Soccer club abbreviation collisions (`MUN`) nearly merged two clubs.
- Index shorthand ("OKC Thunder", "Philadelphia Sixers", "Portland Trailblazers") had to be normalized to established team names before matching.

## References

The application's `docs/yaml-seed-library.md` (Figures and names, Optional lookup sequences) and `docs/entity-code-decisions.md`. Example: `yaml/figures/steve_kerr.yaml`, `yaml/nfl_raiders_city_history.yaml`.
