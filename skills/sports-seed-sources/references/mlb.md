# MLB Stats API

Base: `https://statsapi.mlb.com/api/v1`. Seasons are calendar years.

## Endpoints

- Teams: `/teams?sportId=1&season={YEAR}` (add `&hydrate=venue(location,fieldInfo)` for home venues).
- Roster: `/teams/{ID}/roster?rosterType=fullSeason&season={YEAR}&hydrate=person`.

## Meaning

`fullSeason` is a season **inventory**: it includes departed players. It does not establish current active status, dates of membership, or dates of jersey-number use. Do not create number periods from it.

## Checks

Expect 30 teams. Provider team IDs and the season must agree between the team feed, roster capture, and venue capture.

## Venues

The season team feed's venue is the MLB home venue listing used by `geography-and-venues`. It may name a broader city than the venue's real locality (Sutter Health Park is in West Sacramento, not Sacramento) — verify against the venue's own address.
