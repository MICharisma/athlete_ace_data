# NHL 2026-27 game venues

This batch records where each of the 1,344 games in the 2026-27 NHL schedule is played, and which entry is home and which away. It is the first use of `Contest.stadium` and `Contestant.side`.

| Basis | Games |
| --- | --- |
| A venue bound to the home team (`home_team_venue`) | 1,340 |
| Captured off-site venue (`offsite_capture`) | 4 |

Seven games are played somewhere other than the home team's primary arena:

| Date | Game | Venue |
| --- | --- | --- |
| 2026-10-25 | MTL at WPG | Princess Auto Stadium, Winnipeg (Heritage Classic) |
| 2026-11-12 | CAR at SEA | Veikkaus Arena, Helsinki, Finland |
| 2026-11-14 | SEA at CAR | Veikkaus Arena, Helsinki, Finland |
| 2026-12-18 | CHI at OTT | PSD Bank Dome, Düsseldorf, Germany |
| 2026-12-20 | OTT at CHI | PSD Bank Dome, Düsseldorf, Germany |
| 2026-12-31 | COL at UTA | Rice-Eccles Stadium, Salt Lake City (Winter Classic) |
| 2027-02-20 | VGK at DAL | AT&T Stadium, Arlington (Stadium Series) |

The three outdoor venues were already bound to their home teams as alternative home venues by the geography capture, so they count as `home_team_venue`. The application still shows them as away from the home team's primary venue. The four European games are the `offsite_capture` games.

## Sources

- `sources/coverage_2026/nhl.json` (captured 2026-10-26) supplies each game's venue name, home team and away team.
- `sources/geography_2026/` binds each NHL team to its home venues. A schedule venue that matches one of the home team's bound venues by name, ignoring case, uses that stadium.
- `offsite.json` (captured 2026-11-13 by `scripts/capture_nhl_venues_2026.rb`) holds the NHL gamecenter landing record for every game whose venue doesn't match: venue, `venueLocation` locality and UTC offset. The capture checks that each landing record's game ID, venue and teams agree with the schedule.
- `venues.json` is the reviewed registry:
  - **Alias:** "Centre Bell" (the Canadiens' 42 home games) is the French name of the bound Bell Centre.
  - **New venues:** Veikkaus Arena (Helsinki) and PSD Bank Dome (Düsseldorf), with the localities from the NHL landing records.
  - **New geography:** Finland and Germany, and their ISO 3166-2 subdivisions Uusimaa (FI-18) and North Rhine-Westphalia (DE-NW).

## Outputs

- `yaml/nhl_venues_2026/geography.yaml` adds the two countries, two subdivisions, two cities and two stadiums as normal catalog records.
- `bindings.json` binds every game to a stadium and names its home and away entries. `Seeds::GameVenueImporter` applies it during `db:seed`, after the library import. It fills a missing venue or side, leaves existing equal values alone, and reports different values without overwriting them, like the home-venue enrichment. Bindings are used instead of venue references on the game records because the games were seeded before venues existed. Adding references to them would make every game a replay conflict.

The builder fails if:
- a venue doesn't match the home team's venues and has no capture;
- a captured venue isn't in the registry;
- a captured locality disagrees with the registry;
- a game, stadium or entry code is missing;
- an entry's campaign isn't the expected home or away team;
- a new place's code already exists.

## Known limits

- **Old key kept in `tiebreakers`:** `Contestant.side` is also still stored as `tiebreakers.side`. The entries come from `yaml/coverage_2026/nhl.yaml`, and `scripts/build_2026.rb` no longer reproduces its committed output: `--check` fails on `identities.yaml`, where it now skips about 60 NBA 2023-24 campaigns. Removing the key from the database would make all 2,688 NHL entries conflict on replay. Once that generator is repaired, it should emit `side` instead, and a cleanup can remove the key.
- **No neutral-site designation:** the batch doesn't assert one. The NHL lists a designated home team for every game, and the batch keeps it.
- **The 2022 Leddy game** in `yaml/participation/` has no recorded sides, so it has no venue yet.

## Regenerate

From the AthleteAce application root:

```sh
mise exec -- ruby db/seeds/athlete_ace_data/scripts/capture_nhl_venues_2026.rb --as-of YYYY-MM-DD   # network; only off-site games
mise exec -- ruby db/seeds/athlete_ace_data/scripts/build_nhl_venues_2026.rb
mise exec -- ruby db/seeds/athlete_ace_data/scripts/build_nhl_venues_2026.rb --check
mise exec -- bundle exec rails seeds:validate
mise exec -- bundle exec rails db:seed   # twice: the replay must create 0 records and report 0 conflicts
```
