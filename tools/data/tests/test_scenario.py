"""상황 선택 집계는 전술 점수를 바꾸지 않는다."""

import itertools
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lookatyou.engine import score_integer_values
from lookatyou.scenario import ScenarioFailure, load_scenario_rows, summarize_scenarios

ROOT = Path(__file__).resolve().parents[3]
QUIZ = ROOT / "app" / "assets" / "data" / "0.3.0" / "preview" / "quizzes" / "life_tactics.json"
PILOT = ROOT / "app" / "assets" / "data" / "0.3.0" / "preview" / "pilots" / "life_tactics" / "scenario_v1.json"
ORDER = ["happiness", "meaning", "richness"]


class ScenarioTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.quiz = json.loads(QUIZ.read_text(encoding="utf-8"))
        cls.pilot = json.loads(PILOT.read_text(encoding="utf-8"))

    def test_all_fours_stay_balanced_when_every_scenario_picks_richness(self):
        scored = score_integer_values(self.quiz, [4] * 18, allow_pending=True)
        self.assertEqual(scored["resultTypeId"], "tr10")
        self.assertEqual(scored["displayScores"], {"happiness": "75.0", "meaning": "75.0", "richness": "75.0"})
        summary = summarize_scenarios(self.pilot, self._choices("richness"), ORDER)
        self.assertEqual(summary["counts"], {"happiness": 0, "meaning": 0, "richness": 6})
        self.assertEqual(summary["total"], 6)
        self.assertEqual(summary["kind"], "lead")
        self.assertEqual(summary["leaders"], ["richness"])
        self.assertEqual(scored["resultTypeId"], "tr10")

    def test_frequency_patterns_do_not_use_tie_priority(self):
        self.assertEqual(self._summary({"happiness": 2, "meaning": 2, "richness": 2})["kind"], "balanced")
        tie = self._summary({"happiness": 0, "meaning": 3, "richness": 3})
        self.assertEqual(tie["kind"], "tie")
        self.assertEqual(tie["leaders"], ["meaning", "richness"])
        lead = self._summary({"happiness": 3, "meaning": 2, "richness": 1})
        self.assertEqual(lead["kind"], "lead")
        self.assertEqual(lead["leaders"], ["happiness"])

    def test_replacing_one_answer_moves_one_vote(self):
        answers = self._choices("richness")
        before = summarize_scenarios(self.pilot, answers, ORDER)
        first = self.pilot["scenarios"][0]
        happiness = next(item["optionId"] for item in first["options"] if item["dimensionId"] == "happiness")
        answers[first["scenarioId"]] = happiness
        after = summarize_scenarios(self.pilot, answers, ORDER)
        self.assertEqual(before["counts"]["richness"] - after["counts"]["richness"], 1)
        self.assertEqual(after["counts"]["happiness"] - before["counts"]["happiness"], 1)
        self.assertEqual(after["total"], 6)
        self.assertEqual(before["total"], 6)

    def test_duplicate_and_foreign_options_are_not_counted(self):
        scenario = self.pilot["scenarios"][0]
        other = self.pilot["scenarios"][1]
        with self.assertRaises(ScenarioFailure) as duplicate:
            load_scenario_rows([
                {"scenarioId": scenario["scenarioId"], "optionId": scenario["options"][0]["optionId"]},
                {"scenarioId": scenario["scenarioId"], "optionId": scenario["options"][1]["optionId"]},
            ])
        self.assertEqual(duplicate.exception.code, "invalidAnswer")
        answers = self._choices("happiness")
        answers[scenario["scenarioId"]] = other["options"][0]["optionId"]
        with self.assertRaises(ScenarioFailure) as foreign:
            summarize_scenarios(self.pilot, answers, ORDER)
        self.assertEqual(foreign.exception.code, "invalidAnswer")
        answers[scenario["scenarioId"]] = "missing"
        with self.assertRaises(ScenarioFailure) as missing:
            summarize_scenarios(self.pilot, answers, ORDER)
        self.assertEqual(missing.exception.code, "invalidAnswer")

    def _choices(self, dimension_id):
        answers = {}
        for scenario in self.pilot["scenarios"]:
            answers[scenario["scenarioId"]] = next(
                item["optionId"] for item in scenario["options"] if item["dimensionId"] == dimension_id
            )
        return answers

    def _summary(self, counts):
        answers = {}
        remaining = dict(counts)
        for scenario in self.pilot["scenarios"]:
            dimension_id = next(key for key, value in remaining.items() if value)
            remaining[dimension_id] -= 1
            answers[scenario["scenarioId"]] = next(
                item["optionId"] for item in scenario["options"] if item["dimensionId"] == dimension_id
            )
        return summarize_scenarios(self.pilot, answers, ORDER)


class OptionPointTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = ROOT / "app" / "assets" / "data"
        cls.quiz = json.loads((root / "0.5.0" / "preview" / "quizzes" / "life_tactics.json").read_text(encoding="utf-8"))
        cls.pilot = json.loads((root / "0.5.0" / "preview" / "pilots" / "life_tactics" / "scenario_v2.json").read_text(encoding="utf-8"))
        cls.previous = json.loads((root / "0.4.0" / "preview" / "quizzes" / "life_tactics.json").read_text(encoding="utf-8"))

    def test_reverse_adjustment_and_all_fours(self):
        questions = self.quiz["questions"]
        high = [1 if item["reverse"] else 5 for item in questions]
        low = [5 if item["reverse"] else 1 for item in questions]
        self.assertEqual(set(score_integer_values(self.quiz, high, allow_pending=True)["displayScores"].values()), {"100.0"})
        self.assertEqual(set(score_integer_values(self.quiz, low, allow_pending=True)["displayScores"].values()), {"0.0"})
        fours = score_integer_values(self.quiz, [4] * 18, allow_pending=True)
        self.assertEqual(fours["resultTypeId"], "tr10")
        self.assertEqual(fours["displayScores"], {"happiness": "66.7", "meaning": "66.7", "richness": "66.7"})
        self.assertEqual(fours["dimensionScores"]["happiness"], {"denominator": 3, "numerator": 200})
        previous = score_integer_values(self.previous, [4] * 18, allow_pending=True)
        self.assertEqual(previous["displayScores"], {"happiness": "75.0", "meaning": "75.0", "richness": "75.0"})

    def test_same_slot_and_happiness_primary(self):
        for index in range(3):
            summary = summarize_scenarios(self.pilot, self._slot(index), ORDER)
            self.assertEqual(summary["counts"], {"happiness": 6, "meaning": 6, "richness": 6})
            self.assertEqual(summary["total"], 18)
            self.assertEqual(summary["kind"], "balanced")
        happiness = {}
        for scenario in self.pilot["scenarios"]:
            happiness[scenario["scenarioId"]] = next(
                item["optionId"] for item in scenario["options"] if item["dimensionId"] == "happiness"
            )
        summary = summarize_scenarios(self.pilot, happiness, ORDER)
        self.assertEqual(summary["counts"], {"happiness": 12, "meaning": 3, "richness": 3})
        self.assertEqual(summary["kind"], "lead")
        self.assertEqual(summary["leaders"], ["happiness"])

    def test_replacing_one_answer_resums_all_points(self):
        answers = self._slot(0)
        before = summarize_scenarios(self.pilot, answers, ORDER)
        scenario = self.pilot["scenarios"][0]
        answers[scenario["scenarioId"]] = scenario["options"][1]["optionId"]
        after = summarize_scenarios(self.pilot, answers, ORDER)
        self.assertEqual(after["total"], 18)
        self.assertNotEqual(before["counts"], after["counts"])

    def test_bad_mode_is_not_counted_as_frequency(self):
        broken = json.loads(json.dumps(self.pilot))
        broken["scoringMode"] = "unknown"
        with self.assertRaises(ScenarioFailure) as error:
            summarize_scenarios(broken, self._slot(0), ORDER)
        self.assertEqual(error.exception.code, "invalidDefinition")
        broken["scoringMode"] = "option_points"
        del broken["scenarios"][0]["options"][0]["pointsByDimension"]
        with self.assertRaises(ScenarioFailure) as damaged:
            summarize_scenarios(broken, self._slot(0), ORDER)
        self.assertEqual(damaged.exception.code, "invalidDefinition")

    def test_729_combinations_match_the_flutter_fixture(self):
        lines = []
        scenarios = self.pilot["scenarios"]
        choices = [[item["optionId"] for item in scenario["options"]] for scenario in scenarios]
        for combo in itertools.product(*choices):
            answers = {scenario["scenarioId"]: combo[index] for index, scenario in enumerate(scenarios)}
            summary = summarize_scenarios(self.pilot, answers, ORDER)
            counts = summary["counts"]
            lines.append(
                "|".join([
                    ",".join(combo),
                    f"{counts['happiness']},{counts['meaning']},{counts['richness']}",
                    str(summary["total"]),
                    ",".join(summary["leaders"]),
                    summary["kind"],
                ])
            )
        text = "\n".join(lines) + "\n"
        fixture = ROOT / "app" / "test" / "fixtures" / "scenario_v2_729.txt"
        self.assertEqual(fixture.read_text(encoding="utf-8"), text)

    def _slot(self, index):
        return {
            scenario["scenarioId"]: scenario["options"][index]["optionId"]
            for scenario in self.pilot["scenarios"]
        }
