# Official club and league pages

Use for visual evidence (logos, kits, uniforms) and for dated announcements (trades, extensions, opening-night rosters, stadium guides).

## Visuals

Record the exact page URL and image URL, capture date, checksum, and representation type. Examples that worked:

- The [Blues brand page](https://www.nhl.com/blues/team/brand) supplies several concurrent marks and uniform reference images.
- The Arsenal kit-launch gallery supplies the 2026/27 home reference.

Keep authored schematic SVG and 3D files labeled as illustrative. See `team-visuals`.

## Announcements

Club news pages establish an event and its publication date — the Blues' March 21, 2022 trade announcement, July 13 extension announcement, and October 11 opening-night roster were the sources for the Leddy sample. Store the URL and `published_on` in the manifest `source`. An announcement date is not a contract's legal start date.

## League references

- The Premier League stadium guide corroborates grounds and localities (City Ground → West Bridgford).
- Club media guides (e.g. Buffalo's 2024 NFL media guide) can establish venue moves.

## College athletics sites (Sidearm)

Most schools' roster pages live at `/sports/{mens,womens}-basketball/roster/{YYYY-YY}`. Two templates exist:

- **Classic**: embeds the roster as schema.org `Person` items in `application/ld+json`. This allows a check in both directions: ESPN-only players and official-only players.
- **Newer**: a Nuxt page without structured roster data. Confirm that each provider name appears in the page text, and record that extra official names can't be detected.

Check the page `<title>` says it's a basketball roster before trusting it. A provider-listed player who is missing from the official page is a discrepancy: keep the observation, but withhold the Activation and number.

## Unavailable

Harvard's `gocrimson.com` returned an Incapsula bot-protection page (a tiny HTML body with `_Incapsula_Resource`). Record it as unavailable.

NBA Store product pages and the LockerVision uniform API blocked or refused capture. Record them as unavailable; do not work around them.
