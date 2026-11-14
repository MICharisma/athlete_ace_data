"""Check the generated pseudo catalog without Rails or network access."""
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1] / "pseudo"


class PseudoCatalogTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.records = [record for path in sorted(ROOT.glob("*.yml"))
                       for record in yaml.safe_load(path.read_text())["records"]]
        cls.by_code = {record["code"]: record for record in cls.records}
        cls.by_type = defaultdict(list)
        for record in cls.records:
            cls.by_type[record["type"]].append(record)

    def test_coverage_and_unique_resolvable_codes(self):
        self.assertEqual(len(self.records), len(self.by_code))
        expected = {"League": 3, "Season": 9, "Team": 24, "Conference": 6,
                    "Division": 12, "Campaign": 72, "Player": 472,
                    "Contract": 1416, "Activation": 1416, "Stint": 1416,
                    "Game": 567, "ContestGame": 567, "TitleAward": 18,
                    "Roster": 390, "RosterEntry": 4680, "Appearance": 3510,
                    "JerseyNumberAssignment": 128}
        for kind, count in expected.items():
            self.assertEqual(len(self.by_type[kind]), count, kind)
        for record in self.records:
            for reference in record["references"].values():
                self.assertIn(reference, self.by_code, record["code"])

    def test_rosters_contracts_and_assignments_cover_every_season(self):
        memberships = Counter()
        histories = defaultdict(list)
        for activation in self.by_type["Activation"]:
            refs = activation["references"]
            campaign = self.by_code[refs["campaign"]]
            contract = self.by_code[refs["contract"]]
            player = self.by_code[refs["player"]]
            team = campaign["references"]["team"]
            self.assertEqual(contract["references"]["player"], player["code"])
            self.assertEqual(contract["references"]["team"], team)
            season = self.by_code[campaign["references"]["season"]]
            for field in ("start_date", "end_date"):
                self.assertEqual(activation["attributes"][field], contract["attributes"][field])
            self.assertLessEqual(contract["attributes"]["start_date"], season["attributes"]["start_date"])
            self.assertGreaterEqual(contract["attributes"]["end_date"], season["attributes"]["playoff_end_date"])
            memberships[campaign["code"]] += 1
            histories[player["code"]].append(team)
        self.assertEqual(set(memberships), {r["code"] for r in self.by_type["Campaign"]})
        self.assertEqual(Counter(memberships.values()), {12: 24, 24: 24, 23: 24})
        self.assertTrue(all(len(teams) == 3 for teams in histories.values()))
        self.assertEqual(sum(len(set(teams)) > 1 for teams in histories.values()), 48)
        for campaign in self.by_type["Campaign"]:
            division = self.by_code[campaign["references"]["division"]]
            self.assertEqual(division["references"]["conference"], campaign["references"]["conference"])

    def test_regular_schedules_have_every_pair_home_and_away_without_double_booking(self):
        entries = defaultdict(list)
        links = defaultdict(list)
        for entry in self.by_type["Contestant"]:
            entries[entry["references"]["contest"]].append(entry)
        for link in self.by_type["ContestGame"]:
            links[link["references"]["contest"]].append(link)
        for contest in self.by_type["Contest"]:
            if contest["attributes"]["kind"] != "regular_season":
                continue
            self.assertEqual(len(links[contest["code"]]), 56)
            pairs = Counter()
            bookings = set()
            for link in links[contest["code"]]:
                game = self.by_code[link["references"]["game"]]
                game_entries = entries[game["code"]]
                self.assertEqual(len(game_entries), 2)
                sides = {entry["attributes"]["tiebreakers"]["side"]: entry["references"]["campaign"]
                         for entry in game_entries}
                self.assertNotEqual(sides["home"], sides["away"])
                pairs[(sides["home"], sides["away"])] += 1
                for campaign in sides.values():
                    booking = (campaign, game["attributes"]["begin_date"])
                    self.assertNotIn(booking, bookings)
                    bookings.add(booking)
                    self.assertEqual(game["references"]["season"], self.by_code[campaign]["references"]["season"])
            self.assertEqual(len(pairs), 56)
            self.assertEqual(set(pairs.values()), {1})

    def test_game_membership_dates_rounds_and_title_winners(self):
        for link in self.by_type["ContestGame"]:
            game = self.by_code[link["references"]["game"]]
            contest = self.by_code[link["references"]["contest"]]
            played_on = date.fromisoformat(game["attributes"]["begin_date"])
            self.assertGreaterEqual(played_on, date.fromisoformat(contest["attributes"]["begin_date"]))
            self.assertLessEqual(played_on, date.fromisoformat(contest["attributes"]["end_date"]))
            if contest["attributes"]["kind"] == "playoffs":
                self.assertIn(link["attributes"]["metadata"]["round"],
                              [r["key"] for r in contest["attributes"]["format_rules"]["rounds"]])
        for award in self.by_type["TitleAward"]:
            winner = self.by_code[award["references"]["winner"]]
            self.assertEqual(winner["references"]["contest"], award["references"]["contest"])


    def test_game_rosters_match_the_assignment_player_and_game_date(self):
        rosters = {r["code"]: r for r in self.by_type["Roster"]}
        by_roster = defaultdict(list)
        for entry in self.by_type["RosterEntry"]:
            refs = entry["references"]
            roster = rosters[refs["roster"]]
            stint = self.by_code[refs["stint"]]
            self.assertEqual(refs["player"], stint["references"]["player"])
            campaign = self.by_code[roster["references"]["campaign"]]
            self.assertEqual(campaign["references"]["team"], stint["references"]["team"])
            date_on = roster["attributes"]["effective_on"]
            self.assertLessEqual(stint["attributes"]["start_date"], date_on)
            self.assertGreaterEqual(stint["attributes"]["end_date"], date_on)
            by_roster[roster["code"]].append(entry)
        for roster in rosters.values():
            details = roster["attributes"]["details"]
            contestant = self.by_code[details["contestant_code"]]
            game = self.by_code[details["game_code"]]
            self.assertEqual(contestant["references"]["contest"], game["code"])
            self.assertEqual(contestant["references"]["campaign"], roster["references"]["campaign"])
            self.assertEqual(game["attributes"]["begin_date"], roster["attributes"]["effective_on"])
            entries = by_roster[roster["code"]]
            self.assertEqual(len(entries), 12)
            self.assertEqual(len({e["references"]["player"] for e in entries}), 12)
            self.assertEqual(Counter(e["attributes"]["status"] for e in entries), {"active": 10, "inactive": 2})

    def test_box_scores_match_rosters_points_minutes_and_starters(self):
        appearances = defaultdict(list)
        for appearance in self.by_type["Appearance"]:
            appearances[appearance["references"]["contestant"]].append(appearance)
            stats = appearance["attributes"]["statistics"]
            self.assertTrue(all(isinstance(value, int) and value >= 0 for value in stats.values()))
            self.assertGreater(stats["minutes"], 0)
            self.assertLessEqual(stats["minutes"], 48)
            for made, attempted in (("field_goals_made", "field_goals_attempted"),
                                    ("three_pointers_made", "three_pointers_attempted"),
                                    ("free_throws_made", "free_throws_attempted")):
                self.assertLessEqual(stats[made], stats[attempted])
            self.assertLessEqual(stats["three_pointers_made"], stats["field_goals_made"])
            self.assertLessEqual(stats["three_pointers_attempted"], stats["field_goals_attempted"])
            self.assertLessEqual(stats["field_goals_made"] - stats["three_pointers_made"],
                                 stats["field_goals_attempted"] - stats["three_pointers_attempted"])
            self.assertEqual(stats["points"], 2 * stats["field_goals_made"] +
                             stats["three_pointers_made"] + stats["free_throws_made"])
        entries = defaultdict(list)
        for entry in self.by_type["RosterEntry"]:
            entries[entry["references"]["roster"]].append(entry)
        for roster in self.by_type["Roster"]:
            contestant_code = roster["attributes"]["details"]["contestant_code"]
            actual = appearances[contestant_code]
            self.assertEqual(len(actual), 9)
            self.assertEqual(sum(a["attributes"]["starter"] for a in actual), 5)
            self.assertEqual(sum(a["attributes"]["statistics"]["minutes"] for a in actual), 240)
            self.assertEqual(sum(a["attributes"]["statistics"]["points"] for a in actual),
                             self.by_code[contestant_code]["attributes"]["tiebreakers"]["score"])
            players = {a["references"]["player"]: a for a in actual}
            dnp_count = 0
            for entry in entries[roster["code"]]:
                player = entry["references"]["player"]
                if player in players:
                    self.assertEqual(entry["attributes"]["status"], "active")
                    self.assertEqual(entry["attributes"]["details"]["participation"], "played")
                    self.assertEqual(entry["references"]["stint"], players[player]["references"]["stint"])
                    self.assertNotIn("jersey_number", entry["attributes"])
                    self.assertNotIn("jersey_number", players[player]["attributes"])
                else:
                    self.assertEqual(entry["attributes"]["details"]["participation"], "did_not_play")
                    dnp_count += entry["attributes"]["status"] == "active"
            self.assertEqual(dnp_count, 1)
        self.assertEqual(len(appearances), 390)

    def test_jersey_numbers_persist_across_seasons_without_game_copies(self):
        periods = defaultdict(list)
        for assignment in self.by_type["JerseyNumberAssignment"]:
            refs = assignment["references"]
            periods[(refs["team"], refs["player"])].append(assignment["attributes"])
        for entry in self.by_type["RosterEntry"]:
            roster = self.by_code[entry["references"]["roster"]]
            campaign = self.by_code[roster["references"]["campaign"]]
            key = (campaign["references"]["team"], entry["references"]["player"])
            observed_on = roster["attributes"]["effective_on"]
            matching = [period for period in periods[key]
                        if period["start_date"] <= observed_on <= period["end_date"]]
            self.assertEqual(len(matching), 1, entry["code"])
            self.assertIsInstance(matching[0]["number"], str)
        self.assertTrue(any(period["start_date"] == "2022-01-01" and period["end_date"] == "2024-12-31"
                            for group in periods.values() for period in group))

    def test_injured_players_return_under_the_same_contract_and_stint(self):
        timelines = defaultdict(list)
        for entry in self.by_type["RosterEntry"]:
            roster = self.by_code[entry["references"]["roster"]]
            timelines[entry["references"]["stint"]].append((roster["attributes"]["effective_on"], entry))
        returned = 0
        for stint, timeline in timelines.items():
            injured = [day for day, entry in timeline
                       if entry["attributes"]["details"].get("reason") == "ankle_soreness"]
            if injured:
                played = [day for day, entry in timeline
                          if entry["attributes"]["details"]["participation"] == "played"]
                if played and max(played) > min(injured):
                    self.assertIn("contract", self.by_code[stint]["references"])
                    returned += 1
        self.assertGreaterEqual(returned, 200)


if __name__ == "__main__":
    unittest.main()
