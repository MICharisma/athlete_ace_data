#!/usr/bin/env python3
"""Seed library layout lint: every code defined once, identities in their canonical file.

Identity records (places, venues, sports, leagues, teams, seasons, campaigns,
players, figures, positions) are shared by many batches, so each has exactly
one canonical file under yaml/catalog/, computed from its code. Batches hold
observations (rosters, numbers, games, results, titles) and reference
identities without defining them. See CONTRIBUTING.md, "Library layout".

Report mode (default) prints the findings and exits 0. --strict exits 1 when
there are any, for use once the library has been restructured.
"""

import argparse
from collections import Counter, defaultdict
from pathlib import Path
import re
import sys

from validate_seeds import ROOT, load_document

LIBRARY = ROOT / "yaml"
CATALOG = "catalog"
REGISTRY = "entity_sequences.yaml"


class UnplacedCode(ValueError):
    """An identity code whose shape has no canonical file rule yet."""


def initial(name):
    letter = name[:1]
    return letter if letter.isalpha() else "0"


def league_parts(code):
    parts = code.split("-")
    if len(parts) < 3:
        raise UnplacedCode(code)
    return parts


def canonical_path(record_type, code):
    """The catalog file that owns an identity record, or None for an observation."""
    parts = code.split("-")
    if record_type == "Year":
        return f"{CATALOG}/years.yaml"
    if record_type in ("Country", "State", "City"):
        return f"{CATALOG}/places/{parts[1]}.yaml"
    if record_type == "Stadium":
        return f"{CATALOG}/venues/{parts[1]}.yaml"
    if record_type == "Federation":
        return f"{CATALOG}/federations.yaml"
    if record_type == "Sport":
        return f"{CATALOG}/{parts[1]}/sport.yaml"
    if record_type == "Position":
        return f"{CATALOG}/{parts[0]}/positions.yaml"
    if record_type == "Figure":
        return f"{CATALOG}/figures/{initial(parts[-1])}.yaml"
    if record_type == "League":
        if len(parts) != 3 or parts[1] != "LEAGUE":
            raise UnplacedCode(code)
        return f"{CATALOG}/{parts[0]}/{parts[2]}/league.yaml"
    if record_type in ("Conference", "Division"):
        sport, league = league_parts(code)[:2]
        return f"{CATALOG}/{sport}/{league}/league.yaml"
    if record_type == "Team":
        if len(parts) >= 3 and parts[1] == "CLUB":  # Clubs shared across competitions.
            return f"{CATALOG}/{parts[0]}/clubs.yaml"
        if len(parts) >= 4 and parts[2] == "TEAM":
            return f"{CATALOG}/{parts[0]}/{parts[1]}/teams.yaml"
        raise UnplacedCode(code)
    if record_type == "Organization":
        if len(parts) >= 4 and parts[2] == "ORG":
            return f"{CATALOG}/{parts[0]}/{parts[1]}/organizations.yaml"
        return f"{CATALOG}/organizations.yaml"
    if record_type == "Season":
        if len(parts) != 3 or not parts[2].startswith("SEASON_"):
            raise UnplacedCode(code)
        return f"{CATALOG}/{parts[0]}/{parts[1]}/seasons.yaml"
    if record_type == "Campaign":
        if len(parts) < 5 or not parts[2].startswith("SEASON_") or parts[3] != "TEAM":
            raise UnplacedCode(code)
        return f"{CATALOG}/{parts[0]}/{parts[1]}/campaigns/{parts[2].removeprefix('SEASON_')}.yaml"
    if record_type == "Player":
        if len(parts) == 2:  # A sport-less person code such as PLAYER-KERR_STEVE.
            return f"{CATALOG}/players/{initial(parts[1])}.yaml"
        sport, league = league_parts(code)[:2]
        return f"{CATALOG}/{sport}/{league}/players/{initial(parts[-1])}.yaml"
    return None


def walk(node):
    yield from node.get("records", [])
    for group in node.get("groups", []):
        yield from walk(group)


def manifest_files(root):
    return sorted(path for path in root.rglob("*")
                  if path.suffix.lower() in {".json", ".yaml", ".yml"} and path.name != REGISTRY)


def lint(root=LIBRARY):
    definitions = defaultdict(set)  # code (or alias) -> files that define it
    types = {}
    misplaced = []
    unplaced = []
    catalog_observations = []
    for path in manifest_files(root):
        relative = path.relative_to(root).as_posix()
        for record in walk(load_document(path)):
            record_type, code = record["type"], record["code"]
            for name in [code, *record.get("aliases", [])]:
                definitions[name].add(relative)
                types.setdefault(name, record_type)
            try:
                expected = canonical_path(record_type, code)
            except UnplacedCode:
                unplaced.append((relative, record_type, code))
                continue
            if expected is None:
                if relative.startswith(f"{CATALOG}/"):
                    catalog_observations.append((relative, record_type, code))
            elif relative != expected:
                misplaced.append((relative, record_type, code, expected))
    duplicates = {code: sorted(files) for code, files in definitions.items() if len(files) > 1}
    return {"duplicates": duplicates, "types": types, "misplaced": misplaced,
            "unplaced": unplaced, "catalog_observations": catalog_observations}


def issue_count(report):
    return sum(len(report[key]) for key in ("duplicates", "misplaced", "unplaced", "catalog_observations"))


def summary(report):
    return (f"Layout: {len(report['duplicates'])} code(s) defined in more than one file, "
            f"{len(report['misplaced'])} identity record(s) outside their catalog file, "
            f"{len(report['unplaced'])} identity code(s) with no catalog rule, "
            f"{len(report['catalog_observations'])} observation(s) inside the catalog.")


def print_report(report, limit, out=None):
    out = out or sys.stdout
    print(summary(report), file=out)
    if report["duplicates"]:
        print("\nCodes defined in more than one file, by type:", file=out)
        for record_type, count in Counter(report["types"][code] for code in report["duplicates"]).most_common():
            print(f"  {count:6}  {record_type}", file=out)
        print("  File sets:", file=out)
        for files, count in Counter(" + ".join(files) for files in report["duplicates"].values()).most_common(limit):
            print(f"  {count:6}  {files}", file=out)
    if report["misplaced"]:
        print("\nIdentity records outside their catalog file, by current file:", file=out)
        for (current, record_type), count in Counter((row[0], row[1]) for row in report["misplaced"]).most_common(limit):
            print(f"  {count:6}  {record_type:<14} {current}", file=out)
    for key, title in (("unplaced", "Identity codes with no catalog rule"), ("catalog_observations", "Observations inside the catalog")):
        if report[key]:
            print(f"\n{title}:", file=out)
            for current, record_type, code in report[key][:limit]:
                print(f"  {record_type:<14} {code}  ({current})", file=out)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", type=Path, default=LIBRARY, help="library root (default: yaml/)")
    parser.add_argument("--strict", action="store_true", help="exit 1 when there are findings")
    parser.add_argument("--limit", type=int, default=15, help="rows to print per section")
    args = parser.parse_args(argv)
    report = lint(args.root)
    print_report(report, args.limit)
    return 1 if args.strict and issue_count(report) else 0


if __name__ == "__main__":
    sys.exit(main())
