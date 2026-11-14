---
name: historical-claims
description: Record AthleteAce history — season memberships, stints, roster observations, trades, contracts, jersey-number periods, league/division memberships, games and appearances — without inventing dates or facts. Use when a batch asserts anything about who belonged where and when, or what happened in a game. Not for current-season roster capture mechanics (see sports-seed-sources).
---

# Historical claims

Each record type establishes exactly one kind of fact. Pick the weakest record that the evidence fully supports, and never promote a coarse fact into a finer one.

## Which record for which evidence

| Evidence | Record | Does **not** establish |
| --- | --- | --- |
| Player was on a team at some point in a season | `Activation` (Player ↔ Campaign) | Dates, opening-day presence, games |
| Continuous assignment with known bounds | `Stint` | Contract terms |
| A published list on a date | `Roster` + `RosterEntry` (category, effective date, completeness) | Removal of absent players from a partial list |
| A trade or signing announcement | `Transaction` + `TransactionPlayer` | Stints, contract dates, roster changes |
| An agreement with a club organization | `Contract` (requires `Organization`) | Team assignment; legal bounds from an announcement |
| Played in a specific game | `Appearance` via `Contestant` (kind `game`) | Starter status unless stated |
| Wore a number over a period | `JerseyNumberAssignment` | Anything outside its dated bounds |
| Team in a league/conference/division | `Membership` | Current status — `active` is set explicitly |

A traded player can have whole-season Activations on both teams. A loan can keep the parent organization's Contract while the Activation belongs to the borrowing team.

## Dates

- Bounds are inclusive dates and optional. Unknown stays NULL; an unknown end date does not mean "current".
- An announcement's `published_on` is a source date, not a contract or stint boundary. The Leddy sample keeps the July 13 extension's legal bounds unknown.
- Don't substitute observation/capture dates for unknown effective dates.
- Same-day moves stay separate events; keep exact times in `source`/`details`.

## Rosters and completeness

Completeness (`unknown`, `partial`, `complete`) applies only to the list's stated category and effective date. Partial transaction coverage is explicitly marked; omitted participants are not deletion instructions.

## Games and statistics

- `Appearance.statistics` holds sourced per-game stats. **Season totals never become invented games** or get copied onto appearances.
- Scheduled fixtures carry no scores, lineups, or appearances.
- Jersey numbers are strings (`"0"` ≠ `"00"`).

## Jersey numbers

- Current roster captures seed an assignment starting on the observation date with an open end. That records current knowledge, not the real introduction date.
- A later capture with the same number reuses a covering period and reports differences; it never rewrites the period.
- A changed number needs the old assignment closed explicitly (last day) before the new one starts (next day).
- Disagreements within a capture generate no assignment.
- MLB inventories and NBA appearance tables never manufacture number periods.

## League memberships

When a team changes league: deactivate the old membership, change `Team.league`, then create the new membership. Existing Campaigns keep their recorded season, conference, and division. A club's code doesn't change (Fulham stays `SOC-EPL-TEAM-FUL` in the Championship). An additional title (a cup) is a competition award, not another primary membership.

## Contracts

Never infer the contracting Organization from today's team affiliation, corporate ownership, or an appearance. Supply verified organization mappings.

## Mistakes we've made

- Treating a season stats table as a roster. It's an appearance union.
- Expecting a later capture to correct an earlier number period automatically.

## References

The application's `docs/roster-history-proposal.md`, `docs/jersey-numbers.md`, `docs/league-memberships.md`, `docs/competition-games.md`. Worked examples: `yaml/participation/nhl_leddy_history.yaml`, `yaml/nba_hart_2022_2023.yaml`, `yaml/nfl_sanders_2019.yaml`. Identities they reference live in `yaml/catalog/`.
