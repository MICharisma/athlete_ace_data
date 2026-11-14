# Seed data batches to collect

As of 2026-11-14.

## How a batch works

A batch is one sourced capture turned into seed records: identities go to the shared catalog (`yaml/catalog/`), observations go to the batch's own directory. Follow the `seed-curation` skill in the data repo.

1. Scope the claim: league, season, record types, and what each list means.
2. Capture from the source into `sources/<batch>/`.
3. Build offline with a generator that writes through `SeedCatalog::Writer` and supports `--check`.
4. Write the batch README: sources, meaning, rejected sources, known gaps.
5. Validate, import, and replay.
6. Commit the data repo, then the app pointer and Dockerfile pin.

A batch is done when validation and the layout lint pass, a replay creates 0 records and reports 0 conflicts, and the README lists its gaps.

## What full coverage means

A league-season has full coverage when all six layers below are complete and a replay creates 0 records and reports 0 conflicts. Core coverage is layers 1–3 plus the champion.

| Layer | Records | Complete when |
| --- | --- | --- |
| 1. Structure | League, conferences, divisions, Season with start and end dates, a Membership per team | Every team's conference and division for that season is recorded |
| 2. Teams | Team, a Campaign per season (display name, abbreviation, colors, home venue), logo | Every team that played that season has a Campaign with its home venue |
| 3. Rosters | Player and Figure (name, birthdate, photo), Activation, RosterEntry, position assignment, number period | Every player who appeared or was rostered, with the roster marked `complete` and its meaning stated |
| 4. Schedule and results | Every regular-season and postseason Game, its entries, home and away, venue, score | Game count matches the league schedule and every game has a venue |
| 5. Appearances | One Appearance per player per game, with starter status and key statistics | Each game's appearances add up to its box score |
| 6. Honors | Champion and runner-up titles; MVP, Finals MVP and rookie awards as person-level titles | Every title the league awards that season is recorded with its recipient |

Unknown facts stay empty rather than estimated. A batch can cover one layer for many seasons, or every layer for one season.

## Major league seasons

Proposal: full coverage for every season since 2000 in the oldest leagues, and since founding for the younger ones; champions for every season ever, since each is one record. The catalog today has core coverage for one or two recent seasons per league, plus champions back to 2015–16.

| League | First season | Seasons through 2026 | Proposed full-coverage window | In the catalog now |
| --- | --- | --- | --- | --- |
| NFL | 1920 | 107 | 2000–2026 (27) | Teams 2015–2026; champions 2015–2024; complete rosters 2026 |
| NBA | 1946–47 (as the BAA) | 81 | 2000–01 to 2026–27 (27) | Teams 2015–16 on; champions to 2024–25; complete rosters 2023–24, 2024–25, 2026–27 |
| MLB | 1876 (National League) | 151 | 2000–2026 (27) | Teams 2016–2026; champions 2016–2025; complete rosters 2026 |
| NHL | 1917–18 | 110 (2004–05 cancelled) | 2000–01 to 2026–27 (26 played) | Teams 2015–16 on; champions to 2024–25; complete rosters and full schedule with venues for 2026–27 |
| Premier League | 1992–93 | 35 | Since founding (35) | Complete rosters 2026–27; two-player samples 2025–26 |
| UEFA Champions League | 1955–56 (as the European Cup) | 72 | 1992–93 on (35) | Complete squads 2026–27 for 36 clubs |
| MLS | 1996 | 31 | Since founding (31) | Complete rosters 2026 |
| WNBA | 1997 | 30 | Since founding (30) | Nothing yet |
| Formula One | 1950 | 77 | Since founding (77); Jolpica-F1 has every season | 2026 through round 20 |
| NCAA Division I men's basketball | 1938–39 (first tournament) | 89 | Current season, adding conferences | Ivy League 2026–27 |
| NCAA Division I women's basketball | 1981–82 (first NCAA tournament) | 46 | Current season, adding conferences | Ivy League 2026–27 |

First seasons are from general knowledge; confirm each against the league's own records before capture. Season counts include the current 2026 or 2026–27 season.

## Size of the work

Layers 4 and 5 are most of the effort: the big four leagues played roughly 135,000 regular-season games from 2000 to 2026, and only the 2026–27 NHL schedule is seeded so far.

| League | Regular-season games, 2000–2026 (approx.) | Players per season in the catalog's 2026 rosters |
| --- | --- | --- |
| MLB | 64,000 | 1,680 |
| NBA | 32,600 | 518 |
| NHL | 31,500 | 804 |
| NFL | 7,000 | 2,555 |

Game counts are approximate, from standard schedule lengths with the shortened seasons (2011–12 and 2019–21 NBA, 2012–13 and 2019–21 NHL, 2020 MLB) taken out, and exclude postseasons. One appearance per player per game puts layer 5 in the hundreds of thousands to millions of records per league, so it needs bulk box-score sources rather than per-game captures.

## Near-term batches

These extend data already in the catalog, so each one reuses an existing source and generator.

| Batch | Source | What it adds | When |
| --- | --- | --- | --- |
| F1 2026 season refresh | Jolpica-F1 | Rounds 21–23, the Drivers' and Constructors' titles | After Abu Dhabi, Dec 6 |
| Finals MVPs and season awards | League sites | First real person-level titles for seasons in championship history | Any time |
| Positions for all MLB and NFL rosters | 2026 coverage captures | Listed positions for every team, not just four | Any time |
| Ivy basketball positions | Ivy 2026 capture | Positions moved out of roster details into assignments | Next Ivy rebuild |
| Game venues for other leagues | ESPN and MLB schedules | Venue and home/away for NBA, NFL, MLB and MLS games | Any time |
| Circuit locality corrections | Circuit and municipal sites | The five F1 circuits where Jolpica names a nearby city | Any time |

## New coverage batches

These add leagues or sports the catalog doesn't have yet. Each needs a new capture and builder; the first batch for a league also adds its catalog identities.

- **WNBA:** current rosters, as a separate league from the NBA.
- **NCAA basketball beyond the Ivy League:** the major conferences, men's and women's.
- **NCAA football:** start with one conference.
- **More soccer:** NWSL, then La Liga, Bundesliga and Serie A, sharing club identities the way the EPL and Champions League do.
- **More motorsport:** IndyCar and NASCAR Cup as further leagues under the same sport.
- **Earlier seasons:** back-fill NBA, NFL, NHL and MLB rosters for seasons already covered by championship history.

Tennis and golf wait for the schema decision on athletes with no team (AA-231).

## Schema test batches

These come from the "Seed format test cases" project in Linear. Each is picked to stress the format, so expect a schema decision along with the data.

| Issue | Batch | What it tests |
| --- | --- | --- |
| AA-225 | Ivy track and field, indoor and outdoor, plus cross country | One group of athletes across seasons and sports |
| AA-227 | Ivy women's gymnastics | Events per season, using position assignments |
| AA-228 | Ivy fencing | A coed championship with men's and women's squads |
| AA-229 | 2024 conference realignment | Memberships with start and end dates |
| AA-230 | Name changes and non-Western names | Figure name fields and Rizz names |
| AA-232 | Players who became coaches | One Figure across playing and staff roles |
| AA-233 | Manifests that must fail | Validator and importer rejections |

AA-226 (motorsport) and AA-234 (positions) are already done.

## Claiming a batch

- Open or assign a Linear issue in the "Seed format test cases" project before starting, so two people don't capture the same league.
- Name the batch directory by what was captured: `yaml/batches/{SPORT}/{LEAGUE}/{SEASON}/{source}_{date}/`.
- Never add a second definition of a team, player, season or place. Merge into its catalog file; the validator fails on duplicates.
- Close the issue with the batch README's link and its replay result.
