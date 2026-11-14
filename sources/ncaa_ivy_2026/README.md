# Ivy League basketball, captured 13 November 2026

`mens.json` and `womens.json` record the 2026-27 rosters of the eight Ivy League men's and women's basketball programs. `scripts/build_ncaa_ivy_2026.rb` generates `yaml/ncaa_ivy_2026/mens.yaml`, `womens.yaml` and `report.json` from them without network access.

## Structure

Men's and women's programs are separate leagues, matching the NBA/WNBA split: `BKT-LEAGUE-NCAA_D1_MEN` and `BKT-LEAGUE-NCAA_D1_WOMEN`. Each has its own Ivy League conference (`BKT-NCAA_D1_{MEN,WOMEN}-CONFERENCE-IVY_LEAGUE`), its own `SEASON_2026_2027` on `YEAR-2026`, and its own eight Teams. Harvard's men's and women's programs are two Teams. Each Team has an active league-and-conference Membership with no division and no start date. Campaigns record the conference.

Only the Ivy League is covered. The rest of Division I is not seeded, so these leagues are incomplete.

## Sources and meaning

- **ESPN groups** (`…/basketball/{mens,womens}-college-basketball/groups`): selects the Ivy League's eight teams under NCAA Division I. Capture requires exactly these eight ESPN team IDs.
- **ESPN rosters** (`…/teams/{id}/roster?season=2027`): ESPN labels college seasons by ending year. Each response must report season 2027 and the requested team. These are complete ESPN season roster listings, not appearance unions or NCAA eligibility certifications.
- **Official athletics sites**: each school's `/sports/{mens,womens}-basketball/roster/2026-27` page. Penn, Yale and Cornell publish schema.org Person data, so their rosters were compared in both directions. Brown, Columbia, Dartmouth and Princeton use a newer page template without that data. For those, each ESPN name was confirmed on the page, but extra official names can't be detected.
- **Harvard** (`gocrimson.com`) returned an Incapsula bot-protection page. It was not bypassed. Harvard's rosters rest on ESPN alone.

## Discrepancies

ESPN lists two players who are absent from their school's official roster page:

- Nino Zarkovic, Columbia men
- Alana Andrews, Cornell women

Each has a Player and a RosterEntry recording ESPN's listing, but no Activation and no jersey-number assignment. `CurrentTeamImporter` still assigns their current team from the roster entry. Resolve them on the next capture.

## Identity

Players are matched only by ESPN athlete ID, through the `BKT-ESPN-PLAYER_{id}` alias. ESPN athlete IDs carry over when a college player turns professional, so a later NBA or WNBA capture can link to these players by ID. Names are never matched against professional players. All 270 players in this capture are new identities, and no name collisions occurred.

Jersey numbers follow the current-capture policy: they start on the capture date with an open end. Team colors and logos are captured but not seeded; see `team-visuals`.

## Regenerate

```sh
mise exec -- bundle exec ruby db/seeds/athlete_ace_data/scripts/capture_ncaa_ivy_2026.rb --refresh --as-of YYYY-MM-DD
mise exec -- bundle exec ruby db/seeds/athlete_ace_data/scripts/build_ncaa_ivy_2026.rb
mise exec -- bundle exec ruby db/seeds/athlete_ace_data/scripts/build_ncaa_ivy_2026.rb --check
mise exec -- bundle exec rails seeds:validate db:seed
```

Applying migration `20261113010000` (flexible league memberships) is required before import. The first import created 1,146 records. Replay created 0 records and reported 0 conflicts.
