# Contributing seed data

The `pseudo` branch also includes a [generated fictional league bundle](pseudo/README.md). It is selected explicitly and has separate validation commands.

Prefer `.yml` for new maintained seeds. `.yaml` and `.json` are equally accepted inputs using the same `micharisma-seeds/v1` structure. Add manifests beneath `yaml/`; directory and file names only organize input, never determine entity identity. Existing legacy JSON files elsewhere are a separate format and are not checked by this workflow.

Use `scope` once per file or nested group for shared context. Use semantic codes in `references`, not numeric database IDs. URLs and timestamps are optional. Do not add ERB, custom YAML tags, aliases/merge keys, duplicate mapping keys, or multiple YAML documents. Quote date/identifier strings when their interpretation could be ambiguous.

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

## Curated player groups

Use `PlayerGroup` for a named list and `PlayerGroupMembership` for each explicit player. See [the Brunson/Hart example](yaml/player_groups/knicks_names.yaml). References use `player_group` and `player` codes. Members can be inactive or belong to different teams or sports. Groups do not evaluate queries or infer starter status.

Import replay preserves edited group fields, adds missing memberships, and does not remove memberships omitted from a manifest. Removing a seeded member requires both a manifest edit and an explicit removal from the application.

## Figure identities

Use `Figure` for a shared identity and its names. Player and StaffTenure records refer to it through `references.figure` or inherited `scope.figure`. See [Steve Kerr's athletic and staff history](yaml/figures/steve_kerr.yaml).

Use `FIGURE-` for provisional Figure codes. Do not use `Person`, `person` references, or reverse Figure-to-Player references. Player records can still supply name attributes when they do not need an explicitly shared Figure.
