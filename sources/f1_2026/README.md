# Formula One 2026

This batch is the first motorsport data: the 2026 FIA Formula One World Championship, captured on 2026-11-13, after round 20 (Brazil) and with three rounds still to run.

| Records | Count |
| --- | --- |
| Sport, federation, league, season | `SPORT-MOT`, `FEDERATION-FIA`, `MOT-LEAGUE-F1`, `MOT-F1-SEASON_2026` |
| Constructors (Team + 2026 Campaign) | 11 |
| Drivers with race or sprint results (Player) | 25 |
| Driver–constructor activations | 26 |
| Car-number periods | 28 |
| Circuits (Stadium) | 23, plus 17 countries, 18 subdivisions, 19 cities |
| Sessions (Game) in the championship | 29: 23 Grands Prix and 6 sprints |
| Entries and driver results | 286 game entries, 572 appearances (20 races and 6 sprints) |

## Modeling decisions

- **One sport, series as leagues.** Motorsport (`SPORT-MOT`) is one Sport, and F1 is its first League, under the FIA (`FEDERATION-FIA`). IndyCar, NASCAR and WEC join as further Leagues. A driver who changes series stays one Player. Motorcycle racing should be its own sport. See `skills/seed-identity`.
- **Constructors are Teams.** The 2026 Campaign carries the season's entrant name: `MOT-F1-TEAM-RB` is "RB F1 Team" (Racing Bulls), and `MOT-F1-TEAM-AUDI` is "Audi". The Team for a renamed constructor stays the same Team across renames. Linking Audi to Sauber, and RB to AlphaTauri and Toro Rosso, is left for a historical batch. Jolpica constructor and driver IDs are kept as aliases (`MOT-JOLPICA-CONSTRUCTOR_*`, `MOT-JOLPICA-DRIVER_*`).
- **Every session is a Game at its circuit**, linked to the season championship Contest (`MOT-F1-SEASON_2026-CHAMPIONSHIP`) with metadata `round` (and `series: Sprint` for sprints). That makes the venue recorded for every session, and gives each Game an entry for each constructor that raced. Each driver's result is an Appearance:
  - `jersey_number` holds the car number;
  - `statistics` holds `finish_position`, `position_text`, `grid`, `laps`, `points` and `status`.
- **Unfinished season, so no titles.** Rounds 21–23 are Games without results. No championship placing or TitleAward is recorded. The drivers' and constructors' titles (person-level and team titles) belong in the refresh after Abu Dhabi.
- **Car numbers are observed runs.** A run is the consecutive sessions in which a driver raced the same number for the same team, and its dates are the first and last of those sessions. The mid-season swap shows up exactly:
  - Hadjar's Red Bull #6 has a gap for rounds 12–14;
  - Lawson's #30 runs Racing Bulls (rounds 1–11), then Red Bull (12–14), then Racing Bulls (15–20).

  The actual assignment periods may be longer than the runs.
- **Activations have no dates**, because Jolpica supplies no contract dates.

## Sources

- **Jolpica-F1** for the calendar, circuits, constructors, drivers, race results and sprint results. See `skills/sports-seed-sources/references/jolpica.md`.
  - The capture checks the season echo, the round sequence, result totals (22 per session, no repeated driver), and that every result's driver and constructor is known.
  - After import, each driver's points summed from appearances matched Jolpica's round-20 driver standings for all 25 drivers.
- **`circuits.json`** is the reviewed geography. For each circuit it gives the country and the ISO 3166-2 subdivision containing Jolpica's locality, and it reuses existing cities for Austin, Miami, Las Vegas and Montréal, and England for Silverstone.

## Known gaps

- **Practice and reserve drivers aren't seeded.** The season's driver table lists 36 drivers, including FP1 and reserve drivers, but only the 25 with race or sprint results are seeded.
- **Jeddah isn't seeded.** It's in the circuit table but not on the 2026 calendar, and is recorded as `unscheduled_circuits` in the capture.
- **City is Jolpica's locality, as the geography policy says.** Five circuits sit in a neighboring municipality:

  | Circuit | Jolpica says | Actually in |
  | --- | --- | --- |
  | Barcelona-Catalunya | Barcelona | Montmeló |
  | Hungaroring | Budapest | Mogyoród, Pest County |
  | Sepang | Kuala Lumpur | Sepang, Selangor |
  | Spa-Francorchamps | Spa | Stavelot |
  | Miami International Autodrome | Miami | Miami Gardens |

  Marina Bay is a district of Singapore. Each correction needs its own source; `circuits.json` lists them under `locality_notes`.
- **Liam Lawson has no current team.** He has activations with both Red Bull teams, so `CurrentTeamImporter` reports him as ambiguous rather than picking one.
- **No qualifying, practice, lap or pit-stop data.**

## Regenerate

From the AthleteAce application root:

```sh
mise exec -- ruby db/seeds/athlete_ace_data/scripts/capture_f1_2026.rb --as-of YYYY-MM-DD   # network; --refresh to bypass the cache
mise exec -- ruby db/seeds/athlete_ace_data/scripts/build_f1_2026.rb
mise exec -- ruby db/seeds/athlete_ace_data/scripts/build_f1_2026.rb --check
mise exec -- bundle exec rails seeds:validate
mise exec -- bundle exec rails db:seed   # twice: the replay must create 0 records and report 0 conflicts
```

A refresh after later rounds adds their entries and appearances. It also produces new number-run end dates, which an existing database preserves and reports as conflicts. Extending those periods needs an explicit reconciliation, like the NHL schedule refresh task.
