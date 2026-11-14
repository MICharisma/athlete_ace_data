# Pseudo leagues

This bundle contains fictional basketball, hockey, and soccer leagues for developing seasonal play and game participation. All names, dates, contracts, results, and titles are generated. They make no historical sports claims. Shared Sport, Country, and Year codes reuse the sourced catalog's identities; all other codes begin with `PSEUDO-`.

The `pseudo` Git branch contains this bundle alongside the unchanged sourced library in `yaml/`. The normal seed task still selects `yaml/`. Select `pseudo/` explicitly to import these leagues.

## Coverage

Each league has eight teams, two conferences, four divisions, and three calendar-year seasons, 2022 through 2024. The same team identities continue across seasons. Each Campaign records its conference and division; this bundle does not create current Team Membership rows.

| League | Abbreviation | Players per team | Regular games per season | Playoff games per season |
| --- | --- | ---: | ---: | ---: |
| Horizon Basketball League | HBL | 12 | 56 | 9 |
| Northern Ice League | NIL | 24 | 56 | 9 |
| Riverside Football League | RFL | 23 | 56 | 3 |

There are 24 Teams, 472 Players, 72 Campaigns, 1,416 Contracts, 1,416 Activations, 1,416 Stints, and 567 Games. Each team has a club Organization and affiliation. Each season has a regular-season Contest and playoff Contest, with separate table and playoff titles.

Each player has one calendar-year contract, Activation, and Stint per season. The first two roster slots move to the next team each offseason. These moves preserve the Player identity and position, and give 48 players a three-team history. Contract values are fictional USD amounts. The base league generator creates no movement Transactions or roster observations. The basketball supplement adds the game observations described below. `Player.team` stays unset; assignments come from dated participation records.

The regular schedule is a complete double round robin over 14 weekly matchdays, starting February 5. Every pair meets once at each team's venue, with no team booked twice on the same date. All three fictional leagues award three table points for a win and one for a draw. Basketball and hockey games have no draws. Ties in table points use ascending team code.

The top four teams enter June playoffs, seeded first versus fourth and second versus third. Basketball and hockey use three-game semifinal and final series, each ending 2–1. Soccer uses single games. Scores and home or away roles live in each Game Contestant's `tiebreakers` object. Table Contestants store points there and use `placing` for rank. A Game's ContestGame membership records its matchweek or playoff round, series, and game number.

The basketball supplement adds 390 game availability observations, 4,680 RosterEntries, and 3,510 Appearances across all 195 HBL games. Hockey and soccer have no appearances yet. Each basketball team lists all 12 contracted players for that game: ten active, one inactive with ankle soreness, and one inactive for rest. Nine active players enter the game, including five starters. The tenth active player is a coach-decision DNP and has no Appearance. Slots rotate between games, so players become unavailable and return under the same Contract and Stint.

`hbl_numbers.yml` stores 128 independent player/team number periods. Adjacent periods with the same number merge across seasons. Game roster entries and appearances do not repeat these numbers.

Each team totals 240 player-minutes for a 48-minute game without overtime. Individual points add up to the existing team score. Field goals, three-pointers, and free throws reconcile to each player's points. Other individual statistics provide varied simulated lines; this generator does not reconstruct possessions, shot locations, lineup substitutions, or cross-team event totals.

Roster `kind: game_availability` means an observation of the full candidate roster, including unavailable players. `coverage: complete` refers to those 12 players, not twelve dressed players. Each Roster identifies its Game and Contestant through `details.game_code` and `details.contestant_code`. Those semantic codes are an interim seed convention checked by the dataset tests, not foreign-key associations. Its actual relational parent remains Campaign. Each Appearance directly references the existing Game Contestant and a matching dated Stint.

These status labels and statistics keys describe this fictional dataset. They do not implement NBA injury rules or an automatic roster-selection policy. An injury or rest observation never edits a Contract, ends a Stint, or creates a movement Transaction. Formal injury designations, precise effective times, and game-roster associations remain tracked in [AA-211](https://linear.app/athleteace/issue/AA-211/separate-injury-designation-game-availability-and-team-assignment).

## Regenerate and check

Run these commands from the data repository. The generator uses Ruby's standard library and overwrites only its named manifests and copied sequence registry in `pseudo/`. To change generated data, edit [the league generator](../scripts/build_pseudo.rb) or [the basketball participation generator](../scripts/build_pseudo_games.rb), then regenerate both in the order below.

```sh
ruby scripts/build_pseudo.rb
ruby scripts/build_pseudo_games.rb
ruby scripts/build_pseudo.rb --check
ruby scripts/build_pseudo_games.rb --check
python -m unittest discover -s tools -p 'test_*.py'
python tools/validate_seeds.py pseudo --registry pseudo/entity_sequences.yaml
```

Use a Python environment installed with `tools/requirements.txt`, as described in [Contributing seed data](../CONTRIBUTING.md). Generation prints record counts. `--check` exits nonzero if any generated file differs or is missing. Unit checks must report 16 tests and `OK`; failures return nonzero. Schema validation must report 17 manifests and zero failures. Schema validation does not resolve references or exercise database constraints.

From the AthleteAce application checkout, validate and import this bundle with:

```sh
SEED_LIBRARY_ROOT="$PWD/db/seeds/athlete_ace_data/pseudo" mise exec -- ruby -S bundle exec rails seeds:validate
SEED_LIBRARY_ROOT="$PWD/db/seeds/athlete_ace_data/pseudo" mise exec -- ruby -S bundle exec rails seeds:import
```

Both commands return nonzero on failure. Preflight must report 16,021 records, 16,021 codes, and 17 files. Import creates missing records and preserves existing values. Its report must have zero conflicts for an unedited bundle. Repeating the import must create zero records with zero conflicts. Selecting this bundle does not clear existing catalog data. Use `seeds:import` directly to exercise the library without running the default `db:seed` orchestration.
