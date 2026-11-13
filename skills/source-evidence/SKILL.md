---
name: source-evidence
description: Decide whether a web source supports a specific AthleteAce seed claim, label what a list actually means, and record provenance. Use before trusting any roster, schedule, venue, transaction, or asset source, and when writing a capture README. Not a list of endpoints (see sports-seed-sources).
---

# Source evidence

A source supports a *claim*, not a topic. "ESPN has Knicks data" is not evidence; "ESPN's 2026/27 season roster feed listed these 17 players on 26 October 2026" is.

## Match the source to the claim

Before fetching, name the claim type and pick the most direct source for it:

| Claim | Prefer | Insufficient on its own |
| --- | --- | --- |
| Who is on a roster now | League/club official feed for that season | A full-season inventory, a stats table |
| Who played in a season | Per-game appearance tables (regular and playoff) | A current roster, an end-of-season list |
| A trade or signing | Club or league announcement | A later roster that shows the player elsewhere |
| A venue | Season schedule home listings | Franchise-level venue fields |
| A locality | Venue's own address/directions page, postal authority | A provider's city field |
| A visual | Official brand or kit-launch page, exact image URL | Fan sites, store mockups |

Corroborate with a second independent source when the claim is surprising, the first source is known to be stale, or two sources disagree.

## Label what the list means

Every captured list carries an explicit meaning in its capture and README. Use these and keep them distinct:

- **Snapshot** — a roster as listed on the observation date. Absence later is not removal.
- **Inventory** — everyone who belonged at any point (e.g. MLB `fullSeason`). Not an active roster, not dates.
- **Appearance union** — everyone who appeared in games. Excludes members who never played.
- **Registration list** — a certified competition list with its own effective date (e.g. EPL senior lists).
- **Partial / complete** — completeness applies only to the stated category and effective date.

If you cannot say which one a source is, you cannot use it yet.

## Verify before trusting

- Confirm the returned season and team match the request. Providers silently return current data for old seasons.
- Spot-check a known fact: a traded player, a departed player, a renamed venue.
- Check counts against known league structure (teams per league, games per team) and fail loudly when they differ.
- Re-check HTML structure before relying on selectors after any site change.

## Record provenance

Captures record, per listing: URL, provider IDs, observation date, and the selection rule. Images also record the exact asset URL, checksum, and representation type. Manifests may carry an optional `source` mapping (`url`, `published_on`, `note`), shared through file or group scope. Per-record citation URLs are optional and their absence never blocks import.

Use the date the source itself establishes (publication or effective date) as a source date. Don't convert a capture date into a fabricated observation timestamp or an effective date.

## When sources disagree

- Preserve both values in the capture and report the disagreement; generate no assignment from a contested value.
- Don't silently pick one source. Record which you chose and why in the README.
- Normalize obvious typos in source text (e.g. "Tottenham Hostspur") and note the normalization.

## Access boundaries

Use public endpoints with ordinary browser-style request headers. If a source returns unauthorized, blocks automated access, or times out repeatedly, record it as unavailable for this capture and move on. Never bypass authentication, paywalls, CAPTCHAs, or rate limits. Logos and images remain their owners' works; manifests record sources without asserting a redistribution license.

## Mistakes we've made

- ESPN's historical site roster returned an empty list, and its old-season core team-athlete collection returned *current* players. Both looked like valid season responses.
- ESPN's `team.franchise.venue` still pointed the Warriors to Oracle Arena and Winnipeg to Atlanta.
- A provider's city field contained a stadium name (FC Dallas → "Toyota Stadium").
- The NFL year roster sitemap included reserve and offseason names; it does not establish active-game status.

## References

Worked examples: `sources/README.md`, `sources/coverage_2026/README.md`, `sources/geography_2026/README.md`. Policy: the application's `docs/entity-code-decisions.md` (Optional source URLs, Discrepancies).
