# ESPN site API

Base: `https://site.api.espn.com/apis/site/v2/sports/{SPORT}/{LEAGUE}`.

## Endpoints

- Teams: `/teams?limit=100&season={YEAR}`
- Roster: `/teams/{ID}/roster?season={YEAR}`
- Schedule: `/teams/{ID}/schedule?season={YEAR}&seasontype=2` — season-specific home venues.
- Team feeds expose logo URLs.

## Season labels

NBA and NHL use the **ending** year (2026/27 → `2027`). NFL uses the calendar year. Current soccer competitions use the **starting** year. Confirm the season in every response.

## Shape quirks

- NFL athletes are grouped by position under `items`.
- Soccer players can have a single name. Keep it; don't fabricate a surname.
- ESPN soccer club and player IDs are shared across competitions. Reuse EPL and Champions League clubs by ESPN club ID, not abbreviation.

## Meaning

- NBA, MLS: complete source-listed season roster snapshot.
- NFL: complete listing including reserve categories where supplied.
- EPL: club roster snapshot, not a certified senior/U21 registration list.
- Champions League: listed league-phase clubs and rosters, not UEFA List A/B certification.

## Rejected endpoints

- The site roster endpoint requested with an old season returned an empty list.
- The old-season core team-athlete collection returned **current** athletes.
- `team.franchise.venue` is stale (Warriors → Oracle Arena, Clippers → Crypto.com Arena, Nets → Newark, Winnipeg → Atlanta). Use season schedules for venues; never fall back to the franchise field.

For historical NBA participation use Basketball Reference instead.

## College basketball

- Sports paths are `basketball/mens-college-basketball` and `basketball/womens-college-basketball`. Team IDs are shared across the two (Harvard is `108` in both).
- Seasons use the **ending** year (2026-27 → `2027`).
- Select a conference with `/groups`: find `NCAA Division I`, then the conference child, and read its `teams`. The Ivy League's group ID is `12`.
- **The `teams?groups=…` filter is ignored**: it returned 100 unrelated teams, and Brown and Penn were missing. Never build a conference list from that endpoint.
- `shortDisplayName` gives the name schools use ("Penn"); `location` can give the formal name ("Pennsylvania").
- Check each roster against the school's official page. See `club-pages.md` and the worked example in `sources/ncaa_ivy_2026/README.md`.
