# Contributing seed data

The `pseudo` branch also includes a [generated fictional league bundle](pseudo/README.md). It is selected explicitly and has separate validation commands.

Prefer `.yml` for new maintained seeds. `.yaml` and `.json` are equally accepted inputs using the same `micharisma-seeds/v1` structure. Add manifests beneath `yaml/`; directory and file names only organize input, never determine entity identity. Existing legacy JSON files elsewhere are a separate format and are not checked by this workflow.

Use `scope` once per file or nested group for shared context. Use semantic codes in `references`, not numeric database IDs. URLs and timestamps are optional. Do not add ERB, custom YAML tags, aliases/merge keys, duplicate mapping keys, or multiple YAML documents. Quote date/identifier strings when their interpretation could be ambiguous.

Agents and curators gathering data from the web should follow the [curation skills](skills/README.md), starting with `seed-curation`. [COVERAGE.md](COVERAGE.md) defines full coverage and lists the batches to collect next.

## Check a pull request locally

```sh
python3 -m venv .venv
.venv/bin/pip install -r tools/requirements.txt
.venv/bin/python -m unittest discover -s tools -p 'test_*.py'
.venv/bin/python tools/validate_seeds.py
```

To check particular files, pass their paths to the last command. The PR workflow checks the full manifest library and registry. It needs no Rails database, private submodules, API keys, or tokens.

The [published schemas](schemas/README.md) provide field completion, descriptions, and structural checks for YAML and JSON. VS Code associations are included; YAML support requires the Red Hat YAML extension. The same schema files work with other JSON Schema 2020-12 tools. Source data need not contain a `$schema` property (the seed reader rejects unknown envelope fields).

Passing these checks verifies document structure, catalog field names/types, and code syntax. It does not establish factual accuracy, resolve references or people, apply inherited defaults, validate staged sequence choices, or prove replay behavior. Maintainers run the application's semantic validation and import tests before accepting changes that affect those rules.

## Library layout

File names never decide identity, but they do decide who owns a record. A code defined in two files is a maintenance hazard: two definitions can quietly disagree, and generators that skip codes defined elsewhere produce different output depending on which other batches exist. The library has two layers:

- **Catalog (`yaml/catalog/`)** holds identity records that many batches share, each in exactly one file computed from its code:

  | Records | File |
  | --- | --- |
  | Years | `catalog/years.yml` |
  | Countries, subdivisions, cities | `catalog/places/{COUNTRY}.yml` |
  | Stadiums | `catalog/venues/{COUNTRY}.yml` |
  | Federations | `catalog/federations.yml` |
  | Sport | `catalog/{SPORT}/sport.yml` |
  | Positions | `catalog/{SPORT}/positions.yml` |
  | League, conferences, divisions | `catalog/{SPORT}/{LEAGUE}/league.yml` |
  | Teams | `catalog/{SPORT}/{LEAGUE}/teams.yml` (clubs shared across competitions: `catalog/{SPORT}/clubs.yml`) |
  | Organizations | `catalog/{SPORT}/{LEAGUE}/organizations.yml` |
  | Seasons | `catalog/{SPORT}/{LEAGUE}/seasons.yml` |
  | Campaigns | `catalog/{SPORT}/{LEAGUE}/campaigns/{SEASON_LABEL}.yml` |
  | Players | `catalog/{SPORT}/{LEAGUE}/players/{INITIAL}.yml`, by the first letter of the code's last segment |
  | Figures | `catalog/figures/{INITIAL}.yml` |

- **Batches** hold observations: rosters and roster entries, activations, number periods, stints, contracts, memberships, games and entries, appearances, titles, and position assignments. They are named by what was captured, for example `yaml/batches/{SPORT}/{LEAGUE}/{SEASON}/{source}_{date}/`. A batch references identities by code and never defines them.

`tools/seed_layout.py` lists every code defined in more than one file, identity records outside their catalog file, identity codes no rule covers, and observations placed in the catalog. `tools/validate_seeds.py` runs it when checking the whole library and fails on any finding (`--layout report` only prints the summary).

Add identities to their catalog file, sorted by code, merged with any definition already there; never add a second definition elsewhere. A catalog record stands alone: it carries its own `source` and only the `scope` keys the importer reads for its type. Put observations in a batch directory.

- **Generators** write through `SeedCatalog::Writer` (`scripts/lib/seed_catalog.rb`). It sends identities to their catalog file, merging with what is there and failing on a contradiction, writes the rest to the batch file, and in `--check` mode verifies both without writing. `finish(codes_path:)` records the catalog codes the generator writes in `sources/<batch>/catalog_codes*.json`.
- **Hand-maintained batches** list, in the same kind of file, any catalog codes they contribute that their own observations do not reference (for example a Figure's Player).
- The application's `Seeds::BatchClosure` uses those lists to import one batch with the catalog records it needs, for tasks like `seeds:championship_history` and for tests.

`scripts/convert_layout.rb` performed the one-time restructure (757 duplicate definitions merged; a replay created and conflicted nothing). Running it again moves anything misplaced.

## Curated player groups

Use `PlayerGroup` for a named list and `PlayerGroupMembership` for each explicit player. See [the Brunson/Hart example](yaml/player_groups/knicks_names.yaml). References use `player_group` and `player` codes. Members can be inactive or belong to different teams or sports. Groups do not evaluate queries or infer starter status.

Import replay preserves edited group fields, adds missing memberships, and does not remove memberships omitted from a manifest. Removing a seeded member requires both a manifest edit and an explicit removal from the application.

## Figure identities

Use `Figure` for a shared identity and its names. Player and StaffTenure records refer to it through `references.figure` or inherited `scope.figure`. See [Steve Kerr's athletic and staff history](yaml/figures/steve_kerr.yaml).

Use `FIGURE-` for provisional Figure codes. Do not use `Person`, `person` references, or reverse Figure-to-Player references. Player records can still supply name attributes when they do not need an explicitly shared Figure.
