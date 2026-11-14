# Home venue geography, captured 27 October 2026

`home_venues.json` records 174 team listings for NBA and NHL 2026/27, NFL, MLB and MLS 2026, and EPL 2026/27. `venues.json` is the reviewed identity and locality registry. `bindings.json` and the places and stadiums in `yaml/catalog/places/` and `yaml/catalog/venues/` are generated from those inputs by `scripts/build_geography_2026.rb`.

## Sources and meaning

- ESPN's `/apis/site/v2/sports/{sport}/{league}/teams/{id}/schedule?season={year}` supplies season-specific venue names and locations. NBA and NHL use ending year 2027 and NFL uses 2026, with `seasontype=2`. Soccer uses starting year 2026. Each capture checks the returned team and season, includes only that team's non-neutral home listings, and retains event IDs and dates. The team cohort comes from the existing roster captures. These are source observations, not a certification that every venue used during a season is present.
- [MLB's season team feed](https://statsapi.mlb.com/api/v1/teams?sportId=1&season=2026&hydrate=venue(location,fieldInfo)) supplies the 30 MLB home venue listings. The season and provider team IDs must agree with the roster capture.
- The [Premier League's 2026/27 stadium guide](https://www.premierleague.com/en/news/4725666) corroborates its current grounds and supplies the City Ground locality correction.
- [USPS](https://pe.usps.com/text/pub28/pub28apb.htm) and [Canada Post](https://www.canadapost-postescanada.ca/cpc/en/support/articles/addressing-guidelines/symbols-and-abbreviations.page) supply subdivision names and postal abbreviations. The existing `State` model holds provinces and England as well as US states and DC. England is a UK constituent country, not an English county; see the [ONS description](https://www.ons.gov.uk/methodology/geography/ukgeographies/administrativegeography/england). No county-level geography is asserted.

ESPN's `team.franchise.venue` is unsuitable for current-season imports. During this capture it still pointed the Warriors to Oracle Arena, the Clippers to Crypto.com Arena, the Nets to Newark, and Winnipeg to Atlanta. That endpoint was rejected. Season schedules instead identify Chase Center, Intuit Dome, Barclays Center, and Canada Life Centre. Do not restore the franchise field as a fallback for missing schedule data.

The most frequently observed home venue becomes the primary home link. Alternatives such as Citi Field for NYCFC, Moody Center for the Spurs, and the NHL outdoor grounds are retained and seeded too. International neutral sites are excluded. The 160 stadiums are physical facilities shared across sports, so MetLife, SoFi, TD Garden, and other shared buildings are single records. Capacity and opening-year values from older JSON files are not imported.

## Reviewed localities and identities

City names represent provider localities, which can include towns. State and country are part of city identity, so Kansas City, Kansas and Kansas City, Missouri remain distinct. Canadian cities without a province in their soccer listing are reconciled with the same city's NBA or NHL listings.

- FC Dallas's feed puts `Toyota Stadium` in its city field. [Club directions](https://www.fcdallas.com/stadium/directions) identify Frisco, Texas.
- MLB labels Sutter Health Park's locality Sacramento. The [venue's address](https://www.sutterhealthpark.com/) is West Sacramento, California.
- The EPL schedule says Nottingham for the City Ground. The Premier League guide locates it in West Bridgford.
- Bronx, Brooklyn, Flushing, and New York City source variants are grouped under New York. Montréal and Newcastle upon Tyne use consistent spellings. Raw values remain in the capture.
- [Buffalo's club media guide](https://static.www.nfl.com/league/apps/league-site/media-guides/2024/BUF.pdf) identifies a new home for the 2026 season. Its code ends in `HIGHMARK_STADIUM_2026`, keeping it distinct from the former same-name building.

Each registry observation maps a league, provider team ID, and source venue name to a fixed code. When a source renames a facility, review the physical identity and map the new observation to that code. A move to another building needs another code. Generation rejects unmapped observations, duplicate bindings, contradictory locations, wrong team sets, and tied primary venues.

The application imports the geography before filling missing team and current-season venue links. Existing different selections are reported rather than overwritten. See [the application guide](../../../../../docs/seed-library-2026.md#seed-home-venues-and-their-geography) for commands and replay checks.
