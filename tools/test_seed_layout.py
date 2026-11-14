import contextlib
import io
from pathlib import Path
import tempfile
import unittest

import yaml

from seed_layout import UnplacedCode, canonical_path, issue_count, lint, main


def manifest(*records, groups=None):
    document = {"format": "micharisma-seeds/v1", "namespace": "MIC", "catalog": "ALA", "records": list(records)}
    if groups:
        document["groups"] = groups
    return document


def record(record_type, code, **extra):
    return {"type": record_type, "code": code, **extra}


class CanonicalPathTest(unittest.TestCase):
    def test_identity_codes_map_to_one_catalog_file(self):
        cases = {
            ("Year", "YEAR-2026"): "catalog/years.yml",
            ("Country", "COUNTRY-FI"): "catalog/places/FI.yml",
            ("State", "STATE-FI-18"): "catalog/places/FI.yml",
            ("City", "CITY-FI-18-HELSINKI"): "catalog/places/FI.yml",
            ("Stadium", "STADIUM-FI-18-HELSINKI-VEIKKAUS_ARENA"): "catalog/venues/FI.yml",
            ("Sport", "SPORT-MOT"): "catalog/MOT/sport.yml",
            ("Federation", "FEDERATION-FIA"): "catalog/federations.yml",
            ("League", "MOT-LEAGUE-F1"): "catalog/MOT/F1/league.yml",
            ("Conference", "BKT-NCAA_D1_MEN-CONFERENCE-IVY_LEAGUE"): "catalog/BKT/NCAA_D1_MEN/league.yml",
            ("Division", "HCK-NHL-DIVISION-2020_2021-CENTRAL"): "catalog/HCK/NHL/league.yml",
            ("Team", "BKT-NBA-TEAM-NYK"): "catalog/BKT/NBA/teams.yml",
            ("Team", "SOC-CLUB-ESPN_83"): "catalog/SOC/clubs.yml",
            ("Organization", "SOC-EPL-ORG-ARS"): "catalog/SOC/EPL/organizations.yml",
            ("Organization", "ORGANIZATION-TNT"): "catalog/organizations.yml",
            ("Season", "BKT-NBA-SEASON_2023_2024"): "catalog/BKT/NBA/seasons.yml",
            ("Campaign", "BKT-NBA-SEASON_2023_2024-TEAM-ATL"): "catalog/BKT/NBA/campaigns/2023_2024.yml",
            ("Campaign", "SOC-UCL-SEASON_2026_2027-TEAM-SOC-CLUB-ESPN_83"): "catalog/SOC/UCL/campaigns/2026_2027.yml",
            ("Player", "MOT-F1-PLAYER-HULKENBERG_NICO"): "catalog/MOT/F1/players/H.yml",
            ("Player", "BKT-NBA-LAL-2017-HART_JOSH"): "catalog/BKT/NBA/players/H.yml",
            ("Player", "PLAYER-KERR_STEVE"): "catalog/players/K.yml",
            ("Figure", "FIGURE-KERR_STEVE"): "catalog/figures/K.yml",
            ("Position", "BSB-POSITION-SS"): "catalog/BSB/positions.yml",
        }
        for (record_type, code), expected in cases.items():
            with self.subTest(code=code):
                self.assertEqual(canonical_path(record_type, code), expected)

    def test_observations_have_no_catalog_file(self):
        for record_type in ("RosterEntry", "Activation", "Game", "Appearance", "TitleAward", "PositionAssignment", "JerseyNumberAssignment"):
            self.assertIsNone(canonical_path(record_type, "BKT-NBA-ANYTHING"))

    def test_unrecognized_identity_shapes_are_reported_not_guessed(self):
        for record_type, code in (("League", "NBA"), ("Season", "BKT-NBA-2026"), ("Team", "NYK"), ("Campaign", "BKT-NBA-SEASON_2026-NYK")):
            with self.subTest(code=code), self.assertRaises(UnplacedCode):
                canonical_path(record_type, code)


class LintTest(unittest.TestCase):
    def library(self, files):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name)
        for name, document in files.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(yaml.safe_dump(document, allow_unicode=True))
        (root / "entity_sequences.yaml").write_text("{}\n")  # Never treated as a manifest.
        return root

    def test_a_restructured_library_is_clean(self):
        root = self.library({
            "catalog/BKT/NBA/teams.yml": manifest(record("Team", "BKT-NBA-TEAM-NYK")),
            "catalog/BKT/NBA/campaigns/2026_2027.yml": manifest(record("Campaign", "BKT-NBA-SEASON_2026_2027-TEAM-NYK")),
            "batches/BKT/NBA/2026_2027/espn_roster/roster.yaml": manifest(
                record("Roster", "BKT-NBA-SEASON_2026_2027-TEAM-NYK-ROSTER-2026_10_26")),
        })
        report = lint(root)
        self.assertEqual(issue_count(report), 0)

    def test_duplicates_across_files_including_aliases_and_groups(self):
        root = self.library({
            "coverage/a.yaml": manifest(record("Player", "BKT-NBA-PLAYER-BRUNSON_JALEN")),
            "history/b.yaml": manifest(groups=[{"records": [record("Player", "BKT-NBA-PLAYER-BRUNSON_JALEN")]}]),
            "catalog/BKT/NBA/teams.yml": manifest(record("Team", "BKT-NBA-TEAM-NYK", aliases=["BKT-NBA-TEAM-NY"])),
            "catalog/BKT/NBA/more_teams.yml": manifest(record("Team", "BKT-NBA-TEAM-NY")),
        })
        report = lint(root)
        self.assertEqual(report["duplicates"]["BKT-NBA-PLAYER-BRUNSON_JALEN"], ["coverage/a.yaml", "history/b.yaml"])
        self.assertEqual(report["duplicates"]["BKT-NBA-TEAM-NY"], ["catalog/BKT/NBA/more_teams.yml", "catalog/BKT/NBA/teams.yml"])
        self.assertIn(("catalog/BKT/NBA/more_teams.yml", "Team", "BKT-NBA-TEAM-NY", "catalog/BKT/NBA/teams.yml"), report["misplaced"])

    def test_identities_in_batches_and_observations_in_the_catalog_are_reported(self):
        root = self.library({
            "batches/f1.yaml": manifest(record("Stadium", "STADIUM-MY-14-KUALA_LUMPUR-SEPANG_INTERNATIONAL_CIRCUIT")),
            "catalog/MOT/F1/teams.yml": manifest(record("Game", "MOT-F1-SEASON_2026-ROUND_16-RACE")),
            "catalog/BKT/NBA/league.yml": manifest(record("League", "NBA")),
        })
        report = lint(root)
        self.assertEqual(report["misplaced"], [("batches/f1.yaml", "Stadium", "STADIUM-MY-14-KUALA_LUMPUR-SEPANG_INTERNATIONAL_CIRCUIT", "catalog/venues/MY.yml")])
        self.assertEqual(report["catalog_observations"], [("catalog/MOT/F1/teams.yml", "Game", "MOT-F1-SEASON_2026-ROUND_16-RACE")])
        self.assertEqual(report["unplaced"], [("catalog/BKT/NBA/league.yml", "League", "NBA")])

    def test_report_mode_exits_zero_and_strict_fails_on_findings(self):
        root = self.library({"a.yaml": manifest(record("Year", "YEAR-2026")), "b.yaml": manifest(record("Year", "YEAR-2026"))})
        with contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(main([str(root)]), 0)
            self.assertEqual(main([str(root), "--strict"]), 1)
        self.assertIn("1 code(s) defined in more than one file", output.getvalue())


if __name__ == "__main__":
    unittest.main()
