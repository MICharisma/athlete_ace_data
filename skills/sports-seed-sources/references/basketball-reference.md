# Basketball Reference

Use for historical NBA participant unions.

## Pages

`https://www.basketball-reference.com/leagues/NBA_{ENDING_YEAR}_per_game.html`. Inspect both tables: `per_game_stats` (regular season) and `per_game_stats_post` (playoffs). Check the HTML structure before relying on these selectors after a site change.

## Rules

- Retain team-specific rows. Exclude aggregate `TOT` and multi-team summary rows; the per-team rows preserve both sides of a trade.
- Bind players by Basketball Reference ID (e.g. `achiupr01`) in the identity bindings.
- Datasets are named by starting year (`nba_2023` = 2023/24).

## Meaning

**Appearance unions** for the regular season and playoffs. They are not complete contracts, rosters, or inventories — players who never appeared are absent. They don't establish jersey-number periods or membership dates.

Be a polite client: cache responses, avoid repeated refetches, and stop if the site rate-limits.
