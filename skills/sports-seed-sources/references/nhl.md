# NHL web API

Base: `https://api-web.nhle.com/v1`. Season identifiers are the full pair, e.g. `20262027`.

## Endpoints

- Season roster: `/roster/{CLUB}/{YYYYYYYY}` — season roster snapshot.
- Club schedule: `/club-schedule-season/{CLUB}/{YYYYYYYY}` — every game for that club.
- Archived gamecenter boxscores supply single-game facts (see `sources/leddy_game_20220322.json` for a reviewed example).

## Schedule capture rules

Fetch all 32 club schedules. Select regular-season game type `2` (exclude preseason and playoffs). Deduplicate by NHL game ID. For 2026/27 require 84 games per club, 1,344 distinct games, and two agreeing copies of each game (home and away club schedules). Do not carry those counts to another season without checking its format.

Scheduled games carry no fabricated scores, lineups, or appearances. Venue names stay in `details`.

## Identity

Official NHL player IDs are the strongest binding. Preserve the two players named Elias Pettersson by their IDs (`…_SOURCE_8480012`, `…_SOURCE_8483678`).

## Rescheduling

After recapturing, regenerating, and reviewing the diff, apply date/venue/time/state changes with `rails seeds:refresh_nhl_schedule`. Ordinary `db:seed` preserves existing values. Game identity stays the provider game ID when a date changes. A rerun on the same capture prints `changed: 0`.

## Older captures

Archived club statistics list every skater and goalie with regular-season appearances, including departed players. They become Activations, not Roster observations.
