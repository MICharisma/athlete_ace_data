# Team palettes, 2026

Primary and secondary colors for the 23 Premier League clubs in the catalog and for the Utah Mammoth, captured on 2026-11-22. Palette enrichment (`Seeds::TeamPaletteImporter` in the application) reads the results from:

- `sports/soccer/united_kingdom/Premier_League/team_palettes.json` (22 clubs)
- `sports/hockey/USA/NHL/teams.json` (the `UTA` entry)

`capture.json` keeps the evidence for every club: the crest URL, byte size, SHA-256, every hex value found in the crest markup with its occurrence count, and the selected pair.

## What the colors assert

Each hex value is a color that appears in the league's published crest artwork for that club. The colors are **not** taken from a club brand guide, because no club in the batch publishes hex values that we could find.

Choosing which two crest colors become the primary and secondary is **editorial**. The rule used: the primary is the crest color that matches the club's home shirt, and the secondary is the crest's other main color. Where the crest has only one main color, the secondary is white. These choices are marked `"basis": "editorial"` in `capture.json` and are the part a reviewer should check.

## Sources

- **Premier League crests**: `https://resources.premierleague.com/premierleague/badges/t{id}.svg`, the full-colour set. The badge id for each club was confirmed against the image alt text on `https://www.premierleague.com/en/clubs` on the capture date.
- **Utah Mammoth logo**: `https://assets.nhle.com/logos/nhl/svg/UTA_light.svg` supplies `#010101`, `#6CACE4`, and white. The club's [naming release](https://www.nhl.com/utah/news/utah-s-nhl-franchise-officially-named-the-utah-mammoth-release-5-7-25) (2025-05-07) names the colors Rock Black, Salt White, and Mountain Blue, and gives Rock Black as the home jersey. The release gives no hex values, so matching the names to the logo values is inferred from the hues. Rock Black is the primary and Mountain Blue the secondary.

## Withheld

- **Coventry City**: the crest's vector paths contain only white and red. The rest of the artwork is 64 embedded raster images, so its colors can't be read from the markup. Coventry keeps the neutral fallback.

## Rejected sources

- `premierleague25/badges-alt/{id}.svg` on the same host: an alternate set meant for dark backgrounds (Tottenham's is white only), and Liverpool and Nottingham Forest are raster images.
- teamcolorcodes.com: states that it is not affiliated with any team, and describes its values as estimates. Used only as a cross-check.
- ESPN team feeds (`color`/`alternateColor`): not reachable from the capture environment.

## Regenerating

The capture was made by hand in a browser; there is no generator. To refresh, fetch each crest URL in `capture.json`, compare its SHA-256, and re-read the colors if the file changed.
