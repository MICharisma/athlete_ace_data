---
name: seed-curation
description: Entry point for gathering sports facts from the web and turning them into AthleteAce seed manifests. Use at the start of any data job (adding a league, season, roster, venue set, history sample, or visual assets) to plan the capture → build → validate → import → replay → ship loop and pick the specialist skills. Not for app feature work or live scores.
---

# Seed curation

AthleteAce seeds are curated facts with recorded provenance, not scraped dumps. Every job follows the same loop, and every step leaves something reviewable in Git.

## Locate the repositories

The data repository (`athlete_ace_data`) is mounted at `db/seeds/athlete_ace_data` inside the AthleteAce application checkout. Paths in these skills are relative to the data repository unless they say "the application's". Run Ruby scripts and Rails tasks from the application root with `mise exec -- bundle exec …`. If either checkout is missing, find it before prescribing commands; the Python validator is the only check that works without the application.

## The loop

1. **Scope the claim.** Write down what the batch asserts: which league, which season label, which record types, and what each list means (see `source-evidence`). Check what already exists under `yaml/` and `sources/` first — reuse codes, don't duplicate.
2. **Capture.** Fetch from the source chosen for that claim (see `sports-seed-sources`) into a normalized JSON capture under `sources/<batch>/`. Captures keep provider IDs, URLs, the observation date, and the complete selected listing. They live outside `yaml/`, so the importer never reads them. HTTP caches stay in ignored directories.
3. **Review identities.** Map provider IDs to catalog codes in a reviewed registry or bindings file (see `seed-identity`, `geography-and-venues`). Ambiguity stops generation; it is never guessed away.
4. **Build offline.** A `scripts/build_*.rb` generator turns the capture into manifests under `yaml/<batch>/` with no network access. Generators must support `--check` (nonzero exit when committed output differs) and be byte-for-byte deterministic.
5. **Write the batch README.** `sources/<batch>/README.md` states sources, what each list means, rejected sources and why, reviewed corrections, and regeneration commands. That README is the worked example; the skills hold the reusable method.
6. **Validate.**
   - Structure: `.venv/bin/python tools/validate_seeds.py [paths]` (setup in `CONTRIBUTING.md`).
   - Semantics: `rails seeds:validate` must print positive file and record counts. It is read-only and not a full dry run.
7. **Import and replay.** `rails db:seed`, inspect the conflict report, then run it again. **A same-capture replay must create zero records and report zero conflicts.** Anything else is a bug in the batch.
8. **Review the diff** of captures, registries, and manifests before committing. Commit data-repo changes in the data repository, then bump the submodule pointer in the application.
9. **Update the Dockerfile pin.** The application's `Dockerfile` downloads the data repository at a fixed commit (`ADD https://github.com/MICharisma/athlete_ace_data.git#<sha> …`) instead of reading the submodule. Set that SHA to the new submodule commit, in the same application commit as the pointer bump or the next one, and check that `git ls-tree HEAD db/seeds/athlete_ace_data` agrees with it. Push the data repository's branch before the application's `main`: staging deploys automatically from `main`, and its build fails if the pinned commit isn't on GitHub yet. Staging runs with `SKIP_SEEDS=1`, so a deploy ships the new manifests without importing them (see the application's `docs/railway.md`).

## Pick the specialist skill

| Situation | Skill |
| --- | --- |
| Does this source actually support the claim? | `source-evidence` |
| Fetching NHL, MLB, ESPN, Basketball Reference, or club pages | `sports-seed-sources` |
| Choosing codes, aliases, Figures, resolving name collisions | `seed-identity` |
| Writing or editing a `micharisma-seeds/v1` manifest | `manifest-authoring` |
| Stadiums, cities, states, countries, home venues | `geography-and-venues` |
| Trades, contracts, stints, rosters over time, numbers, game stats | `historical-claims` |
| Logos, uniforms, kits, team colors | `team-visuals` |

## Ground rules for every batch

- Seeding is additive. Import creates missing records, preserves existing values, and reports differences. Omitted rows never delete anything. Don't write a manifest that depends on "last file wins".
- Use the actual observation date (`--as-of`) for a capture. It never selects the target season.
- Don't fabricate: no invented surnames, dates, scores, appearances, contracts, or number periods. Unknown stays unknown (NULL / omitted).
- Respect sources that refuse automated access. Record them as unavailable; never work around authentication, rate limits, or bot controls.
- Seeding never calls Rizz. Figure and place code adoption are separate `rizz:*` tasks.

## Mistakes we've made

Add to this list when a batch reveals a cross-cutting trap; source-specific traps go in the relevant skill.

- Treating a season-shaped URL or echoed year as proof of historical data. Always check a known historical player or transfer.
- Trusting a provider's filter parameter (ESPN `teams?groups=`) without counting the result against the known membership.
- Forgetting that `CurrentTeamImporter` assigns a current team from roster entries as well as activations. A RosterEntry kept for an unconfirmed player still gives that player a current team.
- Reading captures without `encoding: "UTF-8"`. The default can be US-ASCII, which fails on accented names.
- Bumping the submodule but not the Dockerfile pin. Staging would have built the previous catalog without any error.
- Expecting `db:seed` to apply refreshed values. Preservation keeps old values; explicit tasks (e.g. `seeds:refresh_nhl_schedule`) or reconciliation are required.

## References

- Application: `docs/yaml-seed-library.md` (contract and replay), `docs/seed-library-2026.md` (2026 commands), `docs/entity-code-decisions.md` (policy decisions).
- Data repository: `CONTRIBUTING.md`, `schemas/README.md`, `sources/*/README.md` (worked examples).
