---
name: geography-and-venues
description: Curate stadiums, cities, states, and countries for AthleteAce seeds and bind teams to home venues. Use when adding venues, reconciling provider locality names, handling renamed or replaced buildings, or refreshing the home-venue geography capture. Not for team identities (see seed-identity).
---

# Geography and venues

A stadium is a physical building shared across sports and teams. A city is a provider locality inside a state inside a country. Both need reviewed identities because providers spell, rename, and mislocate them constantly.

## Model

- `Country` (ISO 3166-1), `State` (ISO 3166-2 subdivision — US states, DC, Canadian provinces, and UK constituent countries such as England), `City`, `Stadium`.
- State and country are part of city identity: `CITY-US-KS-KANSAS_CITY` ≠ `CITY-US-MO-KANSAS_CITY`.
- One physical facility is one Stadium even when several teams use it (MetLife, SoFi, TD Garden).
- No county-level geography is asserted. England is a constituent country, not a county.
- Rizz place codes are adopted later via `rizz:sync_places`; manifests keep `COUNTRY-`/`STATE-`/`CITY-`/`STADIUM-` codes.

## Sources

- **Venues:** season schedule home listings (ESPN `…/teams/{id}/schedule?season=…&seasontype=2`; MLB season team feed with venue hydration). Include only that team's non-neutral home games; keep event IDs and dates.
- **Localities:** the venue's own address or directions page, league stadium guides, club media guides.
- **Subdivision names and abbreviations:** USPS Publication 28 and Canada Post addressing guidelines.

## The venue registry

`sources/geography_2026/venues.json` is the reviewed identity and locality registry. Each observation maps `(league, provider team ID, source venue name)` to a fixed stadium code. Generation (`scripts/build_geography_2026.rb`) rejects:

- unmapped observations and duplicate bindings,
- contradictory locations for one code,
- wrong team sets,
- tied primary venues.

When a source **renames** a facility, review that it's the same building and map the new name to the existing code. When a team **moves** to another building, issue a new code. A new building with an old name gets a distinct code (Buffalo's `…HIGHMARK_STADIUM_2026`).

## Primary and alternate venues

The venue with the most non-neutral home observations becomes the team's primary home link. Alternates (Citi Field for NYCFC, Moody Center for the Spurs, NHL outdoor games) are seeded as stadiums and retained in the capture. International neutral sites are excluded. A tie fails generation and needs review.

## Locality reconciliation

Group provider variants under one city when they are the same place (Bronx, Brooklyn, Flushing → New York), and normalize spellings consistently (Montréal, Newcastle upon Tyne). Keep raw values in the capture. Record every correction in the batch README with its evidence.

## Import behavior

`db:seed` imports the geography manifest, then applies `bindings.json`: it fills missing `Team.stadium` and the selected season's `Campaign.stadium`/`Campaign.city`. Different existing selections are reported as conflicts, not overwritten. Earlier campaigns are unchanged. Replay must report zero updates and zero conflicts.

```sh
mise exec -- bundle exec ruby db/seeds/athlete_ace_data/scripts/capture_geography_2026.rb --refresh --as-of YYYY-MM-DD
# review venues.json against the new capture and update its review date
mise exec -- bundle exec ruby db/seeds/athlete_ace_data/scripts/build_geography_2026.rb
mise exec -- bundle exec rails seeds:validate db:seed
mise exec -- bundle exec ruby db/seeds/athlete_ace_data/scripts/build_geography_2026.rb --check
```

Not populated by this batch: capacities, opening years, addresses, artwork, full venue history. Don't import capacity or opening-year values from older JSON files without fresh evidence.

## Game venues

Every game should record where it was played (`Contest.stadium`), and each entry whether it is home or away (`Contestant.side`). A game with no recorded venue falls back to the home entry's season venue, then the team's. The app shows that fallback as inferred, and shows a recorded venue that differs from the home venue as away from home. `sources/nhl_venues_2026/` is the worked example:

- Match each schedule venue name to one of the home team's bound venues. Review aliases (Montréal's "Centre Bell") in the batch's `venues.json`. Don't loosen the match.
- For games that don't match, capture the provider's own game record (NHL landing `venueLocation`) for the locality before issuing a stadium. A venue abroad brings its country and ISO 3166-2 subdivision with it.
- When games were seeded before their venues, deliver venues and sides as a generated bindings file applied by `Seeds::GameVenueImporter` (fill missing, report differences). Adding references to already-seeded records would only produce replay conflicts.
- Keep a provider's designated home team at neutral or abroad sites. Don't assert a neutral-site designation the source doesn't make.

## Mistakes we've made

- ESPN `team.franchise.venue` was years stale; rejected permanently.
- FC Dallas's city field said "Toyota Stadium" (actually Frisco, Texas).
- MLB said Sacramento for Sutter Health Park (West Sacramento). The EPL schedule said Nottingham for the City Ground (West Bridgford).
- Canadian MLS listings omitted the province; reconciled with the same city's NBA/NHL listings.
- The NHL schedule calls the Bell Centre by its French name, "Centre Bell"; an exact-name match would have issued a second Montréal arena.

## References

`sources/geography_2026/README.md` (worked example), the application's `docs/seed-library-2026.md` (Seed home venues).
