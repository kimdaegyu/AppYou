"""채점·판정과 첨부 기준선의 교차 검증."""

import json
import sys
import unittest
from decimal import Decimal, ROUND_HALF_UP
from fractions import Fraction
from pathlib import Path

from openpyxl import load_workbook

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lookatyou.engine import QuizFailure, QuizSession, judge_scores, load_answer_rows, score_integer_values
from simulate import BASELINE_PROFILE, PUBLISHED_BASELINE, load_quiz, run_profile

ROOT = Path(__file__).resolve().parents[3]
QUIZ_PATH = ROOT / "app" / "assets" / "data" / "0.3.0" / "preview" / "quizzes" / "life_tactics.json"
REVIEW = ROOT / "docs" / "LookAtYou_QuestionData_Review_v0.3.xlsx"
RESULT = {
    "4-2-4": "tr01",
    "3-4-3": "tr02",
    "4-3-3": "tr03",
    "3-6-1": "tr04",
    "3-5-2": "tr05",
    "4-5-1": "tr06",
    "6-3-1": "tr07",
    "5-4-1": "tr08",
    "5-3-2": "tr09",
    "4-4-2": "tr10",
}


class EngineTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.quiz = json.loads(QUIZ_PATH.read_text(encoding="utf-8"))

    def test_schema_split_and_release_block(self):
        old = json.loads((ROOT / "app/assets/data/0.2.0/preview/quizzes/life_tactics.json").read_text(encoding="utf-8"))
        self.assertEqual(old["schemaVersion"], 1)
        self.assertNotIn("rule", old)
        self.assertEqual(self.quiz["schemaVersion"], 2)
        self.assertEqual([item["questionId"] for item in self.quiz["questions"]], [f"lt_vp{i:02d}" for i in range(1, 19)])
        release = json.loads((ROOT / "app/assets/data/0.3.0/release/catalog.json").read_text(encoding="utf-8"))
        self.assertEqual(release["quizzes"], [])
        with self.assertRaises(QuizFailure) as blocked:
            score_integer_values(self.quiz, [3] * 18, allow_pending=False)
        self.assertEqual(blocked.exception.code, "ruleUnavailable")

    def test_review_cases_and_hand_examples(self):
        for case in _review_cases():
            with self.subTest(case=case["id"]):
                try:
                    outcome = score_integer_values(self.quiz, case["answers"], allow_pending=True)
                except QuizFailure as error:
                    self.assertEqual(error.code, case["code"], case["answers"])
                    continue
                self.assertEqual(outcome["resultTypeId"], case["code"], outcome["displayScores"])
                for axis, raw in zip(("happiness", "meaning", "richness"), case["raws"]):
                    self.assertEqual(outcome["displayScores"][axis], _display(raw))

        summed = [4, 3, 3, 4, 3, 3, 4, 3, 3, 4, 3, 3, 3, 3, 3, 3, 3, 3]
        self.assertEqual(score_integer_values(self.quiz, summed, allow_pending=True)["resultTypeId"], "tr08")
        self.assertEqual(judge_scores(self.quiz, {"happiness": "75", "meaning": "75", "richness": "25"}, allow_pending=True)["resultTypeId"], "tr08")
        self.assertEqual(judge_scores(self.quiz, {"happiness": "25", "meaning": "75", "richness": "75"}, allow_pending=True)["resultTypeId"], "tr05")
        self.assertEqual(judge_scores(self.quiz, {"happiness": "75", "meaning": "25", "richness": "25"}, allow_pending=True)["resultTypeId"], "tr07")
        self.assertEqual(judge_scores(self.quiz, {"happiness": "62", "meaning": "56", "richness": "50"}, allow_pending=True)["resultTypeId"], "tr10")
        self.assertEqual(judge_scores(self.quiz, {"happiness": "62.01", "meaning": "56", "richness": "50"}, allow_pending=True)["resultTypeId"], "tr08")
        self.assertEqual(judge_scores(self.quiz, {"happiness": "70", "meaning": "50", "richness": "45"}, allow_pending=True)["resultTypeId"], "tr07")
        self.assertEqual(judge_scores(self.quiz, {"happiness": "69.99", "meaning": "50", "richness": "45"}, allow_pending=True)["resultTypeId"], "tr08")

    def test_lattice_and_adjacent_edges(self):
        seen = set()
        changed = 0
        edges = 0
        for happiness in range(6, 31):
            for meaning in range(6, 31):
                for richness in range(6, 31):
                    current = _judge_raw(self.quiz, happiness, meaning, richness)
                    seen.add(current)
                    for axis, value in (("happiness", happiness), ("meaning", meaning), ("richness", richness)):
                        if value == 30:
                            continue
                        edges += 1
                        moved = {"happiness": happiness, "meaning": meaning, "richness": richness}
                        moved[axis] = value + 1
                        if _judge_raw(self.quiz, moved["happiness"], moved["meaning"], moved["richness"]) != current:
                            changed += 1
        self.assertEqual(edges, 45000)
        self.assertEqual(changed, 4824)
        self.assertEqual(seen, set(RESULT.values()))

    def test_weight_reverse_and_rejections(self):
        quiz = _mini_quiz()
        outcome = score_integer_values(quiz, [2, 2, 3, 3], allow_pending=True)
        self.assertEqual(outcome["displayScores"]["happiness"], "62.5")
        forward = json.loads(json.dumps(quiz))
        forward["questions"][0]["reverse"] = True
        forward["questions"][1]["reverse"] = True
        reversed_score = score_integer_values(forward, [1, 5, 3, 3], allow_pending=True)
        plain = json.loads(json.dumps(quiz))
        plain["questions"][0]["reverse"] = False
        plain["questions"][1]["reverse"] = False
        forward_score = score_integer_values(plain, [5, 1, 3, 3], allow_pending=True)
        self.assertEqual(reversed_score["dimensionScores"]["happiness"], forward_score["dimensionScores"]["happiness"])
        session = QuizSession(self.quiz, allow_pending=True)
        with self.assertRaises(QuizFailure) as mismatch:
            session.import_rows("0.2.0", [{"questionId": "lt_vp01", "optionId": "a3"}])
        self.assertEqual(mismatch.exception.code, "versionMismatch")
        self.assertEqual(session.answers, {})
        with self.assertRaises(QuizFailure) as duplicate:
            load_answer_rows([
                {"questionId": "lt_vp01", "optionId": "a1"},
                {"questionId": "lt_vp01", "optionId": "a2"},
            ])
        self.assertEqual(duplicate.exception.code, "invalidAnswer")
        with self.assertRaises(QuizFailure) as boolean:
            score_integer_values(self.quiz, [True, *([3] * 17)], allow_pending=True)
        self.assertEqual(boolean.exception.code, "invalidAnswer")
        with self.assertRaises(QuizFailure) as decimal:
            score_integer_values(self.quiz, [1.5, *([3] * 17)], allow_pending=True)
        self.assertEqual(decimal.exception.code, "invalidAnswer")
        first = score_integer_values(self.quiz, [3] * 18, allow_pending=True)
        second = score_integer_values(self.quiz, [3] * 18, allow_pending=True)
        self.assertEqual(first["resultTypeId"], second["resultTypeId"])

    def test_baseline_population(self):
        formations = {item["resultTypeId"]: item["formation"] for item in self.quiz["resultTypes"]}
        report = run_profile(self.quiz, BASELINE_PROFILE, lambda result_id: formations[result_id])
        self.assertEqual(report["dataVersion"], "0.3.0")
        self.assertEqual(report["seed"], 20261120)
        self.assertEqual(report["formations"], PUBLISHED_BASELINE["formations"])
        self.assertEqual(report["sensitivity"], PUBLISHED_BASELINE["sensitivity"])
        self.assertEqual(sum(report["formations"].values()), 100000)


def _review_cases():
    workbook = load_workbook(REVIEW, data_only=True, read_only=True)
    try:
        rows = list(workbook["가상테스트_케이스"].iter_rows(values_only=True))
    finally:
        workbook.close()
    cases = []
    for row in rows[4:]:
        if not row or not isinstance(row[0], str) or row[0].startswith("주의"):
            continue
        answers = list(row[3:21])
        expected = row[24]
        if expected in RESULT:
            code = RESULT[expected]
            raws = (_axis_raw(answers, 0), _axis_raw(answers, 1), _axis_raw(answers, 2))
        elif expected == "미완료":
            code = "incomplete"
            raws = None
        else:
            code = "invalidAnswer"
            raws = None
        cases.append({"id": row[0], "answers": answers, "code": code, "raws": raws})
    if len(cases) != 31:
        raise AssertionError(len(cases))
    return cases


def _axis_raw(answers, offset):
    return sum(answers[index] for index in range(offset, 18, 3))


def _display(raw):
    value = Decimal(100 * (raw - 6)) / Decimal(24)
    return format(value.quantize(Decimal("0.1"), rounding=ROUND_HALF_UP), "f")


def _judge_raw(quiz, happiness, meaning, richness):
    scores = {
        "happiness": Fraction(100 * (happiness - 6), 24),
        "meaning": Fraction(100 * (meaning - 6), 24),
        "richness": Fraction(100 * (richness - 6), 24),
    }
    return judge_scores(quiz, scores, allow_pending=True)["resultTypeId"]


def _mini_quiz():
    def question(question_id, axis, weight, reverse, order):
        return {
            "questionId": question_id,
            "dimensionId": axis,
            "scaleId": "agreement5",
            "weight": weight,
            "reverse": reverse,
            "sortOrder": order,
            "isActive": True,
        }

    options = [
        {"optionId": f"a{score}", "scaleId": "agreement5", "scoreValue": score, "isActive": True}
        for score in range(1, 6)
    ]
    return {
        "quizId": "mini",
        "dataVersion": "9.9.9",
        "scoreMode": "independent_sum",
        "resultRuleStatus": "pending",
        "questions": [
            question("h1", "happiness", 1, False, 1),
            question("h2", "happiness", 3, True, 2),
            question("m1", "meaning", 1, False, 3),
            question("r1", "richness", 1, False, 4),
        ],
        "options": options,
        "rule": json.loads(QUIZ_PATH.read_text(encoding="utf-8"))["rule"],
    }


if __name__ == "__main__":
    unittest.main()
