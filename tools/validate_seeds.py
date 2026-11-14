#!/usr/bin/env python3
"""Offline structural checks for community PRs; no Rails/private library required."""

import argparse
import datetime
import json
import math
from pathlib import Path
import sys

import yaml
from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parents[1]
SCHEMAS = ROOT / "schemas" / "v1"


class StrictLoader(yaml.SafeLoader):
    def compose_node(self, parent, index):
        if self.check_event(yaml.AliasEvent):
            raise ValueError("YAML aliases are unsupported; use scope/groups")
        return super().compose_node(parent, index)

    def construct_mapping(self, node, deep=False):
        result = {}
        for key_node, value_node in node.value:
            if key_node.value == "<<":
                raise ValueError("YAML merge keys are unsupported; use scope/groups")
            key = self.construct_object(key_node, deep=deep)
            if type(key) not in (str, int):
                raise ValueError("mapping keys must be strings (registry numbers may be integers)")
            if key in result:
                raise ValueError(f"duplicate key {key!r} at line {key_node.start_mark.line + 1}")
            result[key] = self.construct_object(value_node, deep=deep)
        return result


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def portable(value, registry=False):
    if isinstance(value, dict):
        result = {}
        for key, item in value.items():
            if not isinstance(key, str) and not (registry and type(key) is int):
                raise ValueError("manifest mapping keys must be strings; quote numeric keys")
            key = str(key)
            if key in result:
                raise ValueError(f"duplicate normalized key {key!r}")
            result[key] = portable(item, registry=registry)
        return result
    if isinstance(value, list):
        return [portable(item, registry=registry) for item in value]
    if isinstance(value, (datetime.date, datetime.datetime)):
        return value.isoformat()
    if isinstance(value, float) and not math.isfinite(value):
        raise ValueError("non-finite numbers are unsupported")
    if type(value) not in (str, int, float, bool, type(None)):
        raise ValueError(f"unsupported value type {type(value).__name__}")
    return value


def load_document(path, registry=False):
    text = Path(path).read_text(encoding="utf-8")
    if "<%" in text:
        raise ValueError("ERB is unsupported")
    if Path(path).suffix.lower() == ".json":
        value = json.loads(text, object_pairs_hook=unique_object)
    else:
        value = yaml.load(text, Loader=StrictLoader)
    return portable(value, registry=registry)


def validator(name):
    schema = json.loads((SCHEMAS / name).read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, format_checker=FormatChecker())


def validate_file(path, schema, registry=False):
    document = load_document(path, registry=registry)
    errors = list(schema.iter_errors(document))
    if errors:
        diagnostics = []
        for error in errors:
            if error.validator == "oneOf" and isinstance(error.instance, dict):
                selected = next((i for i, branch in enumerate(error.schema["oneOf"])
                                 if branch.get("properties", {}).get("type", {}).get("const") == error.instance.get("type")), None)
                children = [child for child in error.context if child.schema_path[0] == selected]
                diagnostics.extend(children or [error])
            else:
                diagnostics.append(error)
        for error in diagnostics[:8]:
            pointer = "/" + "/".join(map(str, error.absolute_path))
            print(f"{path}:{pointer}: {error.message[:240]}", file=sys.stderr)
        raise ValueError(f"{len(errors)} schema violation(s)")
    return document


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", type=Path, default=[ROOT / "yaml"])
    parser.add_argument("--registry", type=Path, default=ROOT / "yaml" / "entity_sequences.yaml")
    parser.add_argument("--layout", choices=("strict", "report", "off"), default="strict",
                        help="library layout lint when validating the whole library (see tools/seed_layout.py)")
    args = parser.parse_args(argv)
    registry_schema = validator("entity-sequences.schema.json")
    manifest_schema = validator("ala.schema.json")
    failed = 0
    try:
        validate_file(args.registry, registry_schema, registry=True)
    except (ValueError, yaml.YAMLError, OSError) as error:
        print(f"{args.registry}: {error}", file=sys.stderr)
        failed += 1
    files = set()
    for path in args.paths:
        files.update(item for item in (path.rglob("*") if path.is_dir() else [path])
                     if item.suffix.lower() in {".json", ".yaml", ".yml"})
    files = sorted(path for path in files if path.resolve() != args.registry.resolve())
    if not files:
        print("No manifest files found.", file=sys.stderr)
        return 1
    for path in files:
        try:
            validate_file(path, manifest_schema)
        except (ValueError, yaml.YAMLError, OSError) as error:
            print(f"{path}: {error}", file=sys.stderr)
            failed += 1
    print(f"Checked {len(files)} manifest(s) and the sequence registry; {failed} failed. No data was imported.")
    library = (ROOT / "yaml").resolve()
    if args.layout != "off" and not failed and any(path.resolve() == library for path in args.paths):
        import seed_layout  # Imported lazily: it imports this module.
        report = seed_layout.lint(library)
        print(seed_layout.summary(report) + " Details: tools/seed_layout.py")
        if args.layout == "strict" and seed_layout.issue_count(report):
            return 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
