import copy
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest

import yaml

from validate_seeds import ROOT, main, validate_file, validator


class SeedSchemaTest(unittest.TestCase):
    def setUp(self):
        self.schema = validator("ala.schema.json")
        self.manifest = {
            "format": "micharisma-seeds/v1", "namespace": "MIC", "catalog": "ALA",
            "scope": {"sport": "SPORT-BKT", "league": "BKT-LEAGUE-NBA"},
            "groups": [{"scope": {"team": "BKT-NBA-TEAM-NYK"}, "groups": [{"records": [
                {"type": "Player", "code": "BKT-NBA-LAL-2017-HART_JOSH", "attributes": {"first_name": "Josh"}}
            ]}]}]
        }

    def check_text(self, text, suffix=".yml", schema=None):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ("unrelated-name" + suffix)
            path.write_text(text)
            return validate_file(path, schema or self.schema)

    def test_yaml_and_json_share_one_contract_and_allow_inherited_context(self):
        yaml_result = self.check_text(yaml.safe_dump(self.manifest))
        json_result = self.check_text(json.dumps(self.manifest), ".json")
        self.assertEqual(yaml_result, json_result)
        self.assertNotIn("references", json_result["groups"][0]["groups"][0]["records"][0])

    def test_unknown_envelope_type_attribute_reference_and_numeric_id_fail(self):
        for mutation in ("header", "type", "attribute", "reference", "id", "wrong_type"):
            document = copy.deepcopy(self.manifest)
            row = document["groups"][0]["groups"][0]["records"][0]
            if mutation == "header":
                document["replay_policy"] = "overwrite"
            elif mutation == "type":
                row["type"] = "NotAnEntity"
            elif mutation == "attribute":
                row["attributes"]["misspelled_name"] = "Josh"
            elif mutation == "reference":
                row["references"] = {"missing_association": "TEAM-NYK"}
            elif mutation == "id":
                row["attributes"]["team_id"] = 12
            else:
                row["attributes"]["first_name"] = 12
            with self.subTest(mutation=mutation), contextlib.redirect_stderr(io.StringIO()), self.assertRaises(ValueError):
                self.check_text(json.dumps(document), ".json")

    def test_optional_source_dates_and_numeric_or_named_sequences(self):
        for selection in ("05_22", [5, 22], ["athletes", "season_roster"], 5, "athletes"):
            document = copy.deepcopy(self.manifest)
            document["entity_sequence"] = selection
            # Completion of staged choices is a reader/registry check.
            self.check_text(json.dumps(document), ".json")
        text = yaml.safe_dump(self.manifest) + "source:\n  retrieved_on: 2024-10-01\n"
        self.assertEqual(self.check_text(text)["source"]["retrieved_on"], "2024-10-01")

    def test_duplicate_and_unsafe_yaml_never_reaches_schema_validation(self):
        for text in ("catalog: ALA\ncatalog: ASC\n", "a: &a [1]\nb: *a\n", "a: {<<: {b: 1}}\n",
                     "a: !ruby/object:Thing {}\n", "a: !!binary SGVsbG8=\n", "---\na: 1\n---\nb: 2\n",
                     "a: .inf\n", "a: <%= 1 %>\n"):
            with self.subTest(text=text), self.assertRaises((ValueError, yaml.YAMLError)):
                self.check_text(text)
        for text in ('{"a":1,"a":2}', '{"a":NaN}'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                self.check_text(text, ".json")

    def test_registry_accepts_numeric_keys_and_terminology(self):
        path = ROOT / "yaml" / "entity_sequences.yaml"
        self.assertIsInstance(validate_file(path, validator("entity-sequences.schema.json"), registry=True), dict)

    def test_schema_artifacts_match_exported_catalog_metadata(self):
        contract = json.loads((ROOT / "schemas" / "ala.contract.json").read_text())
        schema = json.loads((ROOT / "schemas" / "v1" / "ala.schema.json").read_text())
        branches = schema["$defs"]["record"]["oneOf"]
        self.assertEqual(len(branches), len(contract["entities"]))
        for branch in branches:
            properties = branch["properties"]
            entity = contract["entities"][properties["type"]["const"]]
            self.assertEqual(properties["attributes"]["properties"], entity["attributes"])
            self.assertEqual(sorted(properties["references"]["properties"]), entity["references"])

    def test_shared_schema_does_not_finalize_ascent_models(self):
        document = {"format": "micharisma-seeds/v1", "namespace": "MIC", "catalog": "ASC",
                    "records": [{"type": "Candidacy", "code": "CANDIDACY-EXAMPLE", "attributes": {"parties": ["Working Families"]}}]}
        self.check_text(json.dumps(document), ".json", validator("manifest.schema.json"))

    def test_cli_returns_failure_for_bad_contributions_and_does_not_write_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "community.json"
            path.write_text(json.dumps(self.manifest))
            before = path.read_bytes()
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(main([str(path)]), 0)
            self.assertEqual(path.read_bytes(), before)
            path.write_text('{"format":"wrong"}')
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(main([str(path)]), 1)


if __name__ == "__main__":
    unittest.main()
