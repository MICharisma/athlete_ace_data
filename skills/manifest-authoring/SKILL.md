---
name: manifest-authoring
description: Write or edit AthleteAce seed manifests in the micharisma-seeds/v1 YAML/JSON envelope — scope inheritance, references by code, source metadata, player groups — and run the structural validator. Use when hand-authoring a manifest or writing a generator that emits one. Not for choosing codes (see seed-identity).
---

# Manifest authoring

Manifests live under `yaml/` and use the `micharisma-seeds/v1` envelope. Prefer `.yml` for new hand-written files; `.yaml` and `.json` are equally valid. Generated manifests should come from a `scripts/build_*.rb` generator, never be hand-edited after generation.

## Shape

```yaml
format: micharisma-seeds/v1
namespace: MIC
catalog: ALA
source:                       # optional, inherited
  url: https://www.nba.com/knicks/news/new-york-knicks-acquire-josh-hart
  published_on: "2023-02-09"
scope:                        # optional, inherited
  sport: SPORT-BKT
  league: BKT-LEAGUE-NBA
  year: YEAR-2022
groups:
  - scope: {team: BKT-NBA-TEAM-NYK}
    records:
      - type: Campaign
        code: BKT-NBA-SEASON_2022_2023-TEAM-NYK
        attributes:
          display_name: New York Knicks
          abbreviation: NYK
      - type: Activation
        code: BKT-NBA-SEASON_2022_2023-TEAM-NYK-PLAYER-HART_JOSH
        references:
          player: BKT-NBA-LAL-2017-HART_JOSH
```

A file can use top-level `records`, `groups`, or both; groups nest. Each record has `type`, `code`, and optional `attributes`, `references`, `aliases`, and `source`.

## Rules

- **Scope** merges file → group → row; explicit `references` override scope. Use scope once for shared context instead of repeating it.
- **Relationships use codes** in `references`. Database IDs and foreign-key attributes are rejected.
- **Envelope fields are closed**: unknown top-level keys (including `$schema`) are rejected. Don't invent `replay_policy` or similar — per-attribute update policy is not implemented.
- **Plain YAML only**: no ERB, custom tags, anchors/aliases/merge keys, duplicate keys, or multiple documents.
- **Quote ambiguous scalars**: dates (`"2023-02-09"`), jersey numbers (`"00"`), and identifiers that look numeric.
- **Unknown is omitted**, not filled with placeholders. Leave contract bounds, starter status, end dates unset when the source doesn't establish them.
- **Self-contained catalog**: references stay inside `ALA`. Cross-catalog references belong in documentation only.
- **Order doesn't matter** across files or within a file; the importer resolves dependencies. A complete bundle must still define every referenced parent somewhere.
- **Source metadata** is optional and inherited. Persisted on models with a `source` column; older tables use `details.source`.

Use `entity_sequence` (e.g. `"05_22"`) only when positional lookup genuinely saves effort; exact codes resolve directly. The installed recipes are listed in the application's `docs/yaml-seed-library.md`.

## Record-type notes

- **Campaign** holds annual display facts (name, abbreviation, colors, stadium, conference, division). Team holds the continuing franchise.
- **Activation** is a whole-season membership, not a dated stint or game appearance (see `historical-claims`).
- **Membership** accepts `league`, optional `conference`, optional `division`. A league-only membership is valid.
- **PlayerGroup / PlayerGroupMembership** define named practice lists. Replay adds missing memberships but never removes omitted ones — removal needs a manifest edit *and* an explicit app-side removal. See `yaml/player_groups/knicks_names.yaml`.
- **Figure / Player** — see `seed-identity`. Example: `yaml/figures/steve_kerr.yaml`.

## Validate

From the data repository:

```sh
python3 -m venv .venv
.venv/bin/pip install -r tools/requirements.txt
.venv/bin/python tools/validate_seeds.py path/to/file.yml
```

This checks envelope, field names and types, and code syntax against `schemas/v1/`. It does not check facts, reference existence, or replay. Then from the application root, `mise exec -- bundle exec rails seeds:validate`, followed by import and a zero-conflict replay (see `seed-curation`).

The schemas give editor completion (VS Code + Red Hat YAML extension). `schemas/ala.contract.json` and `schemas/v1/` are generated — never hand-edit them; see `schemas/README.md`.

## Mistakes we've made

- Using the retired `mic-seed-proposal/1` envelope. Only `micharisma-seeds/v1` is supported.
- Unquoted `00` jersey numbers and dates parsed as numbers/dates.

## References

`CONTRIBUTING.md`, `schemas/README.md`, the application's `docs/yaml-seed-library.md` (Manifest contract) and `docs/league-memberships.md`.
