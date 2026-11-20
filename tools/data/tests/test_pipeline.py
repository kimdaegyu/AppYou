"""Excel 검증과 JSON 생성. 실패하면 이전 생성 파일을 바꾸지 않는다."""

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

from openpyxl import Workbook, load_workbook

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lookatyou.cli import build_main, validate_main

ROOT = Path(__file__).resolve().parents[3]


class PipelineTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)

    def test_real_source_has_no_structural_errors(self):
        code = validate_main(["--source", str(ROOT / "data" / "source")])
        self.assertEqual(code, 0)

    def test_real_source_is_not_release_ready(self):
        code = validate_main(
            ["--source", str(ROOT / "data" / "source"), "--strict-release"]
        )
        self.assertEqual(code, 1)

    def test_duplicate_id(self):
        source = self._source()
        workbook = load_workbook(source / "QuestionData.xlsx")
        workbook["Questions"].append([
            "tq01", "life_tactics", "0.2.0", 2, True,
            "life_tactics.question.tq01", "agreement5", "happiness", 1, False, "draft",
        ])
        workbook.save(source / "QuestionData.xlsx")
        workbook.close()
        self.assertIn("QuestionId tq01가 같은 범위에서 중복", self._errors(source))

    def test_missing_text_key(self):
        source = self._source()
        self._set(source, "QuestionData.xlsx", "Questions", 2, "PromptTextKey", "life_tactics.question.missing")
        message = self._errors(source)
        self.assertIn("문구 키 life_tactics.question.missing가 Strings에 없습니다", message)
        self.assertIn("PromptTextKey", message)

    def test_broken_reference(self):
        source = self._source()
        self._set(source, "QuestionData.xlsx", "Questions", 2, "DimensionId", "missing-axis")
        message = self._errors(source)
        self.assertIn("축 missing-axis", message)
        self.assertIn("QuestionData.xlsx", message)
        self.assertIn("Questions", message)
        self.assertIn("DimensionId", message)

    def test_missing_translation_status(self):
        source = self._source()
        self._set(source, "Localization.xlsx", "Strings", 2, "enStatus", "reviewed")
        message = self._errors(source)
        self.assertIn("reviewed인데 칸이 비어 있습니다", message)
        self.assertIn("Localization.xlsx", message)

    def test_placeholder_mismatch(self):
        source = self._source()
        self._set(source, "Localization.xlsx", "Strings", 2, "ko", "안녕 {current}")
        self._set(source, "Localization.xlsx", "Strings", 2, "en", "Hello")
        self._set(source, "Localization.xlsx", "Strings", 2, "enStatus", "draft")
        self.assertIn("치환 변수", self._errors(source))

    def test_bad_type(self):
        source = self._source()
        self._set(source, "QuestionData.xlsx", "Questions", 2, "Weight", "heavy")
        message = self._errors(source)
        self.assertIn("유한한 수가 아닙니다", message)
        self.assertIn("Weight", message)

    def test_formula_is_rejected(self):
        source = self._source()
        workbook = load_workbook(source / "QuestionData.xlsx")
        workbook["Questions"]["I2"] = "=1+1"
        workbook.save(source / "QuestionData.xlsx")
        workbook.close()
        self.assertIn("수식 셀은 허용하지 않습니다", self._errors(source))

    def test_repeat_build_is_identical(self):
        source = self._source()
        first = source.parent / "out-a"
        second = source.parent / "out-b"
        self.assertEqual(build_main(["--source", str(source), "--destination", str(first)]), 0)
        self.assertEqual(build_main(["--source", str(source), "--destination", str(second)]), 0)
        self.assertEqual(self._files(first), self._files(second))
        catalog = json.loads((first / "0.2.0" / "preview" / "catalog.json").read_text(encoding="utf-8"))
        self.assertEqual(catalog["schemaVersion"], 1)
        self.assertEqual(catalog["dataVersion"], "0.2.0")
        self.assertFalse((first / "0.2.0" / "preview" / "pilots").exists())
        release = json.loads((first / "0.2.0" / "release" / "catalog.json").read_text(encoding="utf-8"))
        self.assertEqual(release["quizzes"], [])

    def test_failed_build_keeps_existing_output(self):
        source = self._source()
        destination = source.parent / "out"
        self.assertEqual(build_main(["--source", str(source), "--destination", str(destination)]), 0)
        kept = destination / "0.2.0" / "preview" / "catalog.json"
        original = kept.read_text(encoding="utf-8")
        (source / "QuizData.xlsx").unlink()
        code = build_main(["--source", str(source), "--destination", str(destination)])
        self.assertEqual(code, 1)
        self.assertEqual(kept.read_text(encoding="utf-8"), original)

    def test_reviewed_quiz_enters_release_without_draft_text(self):
        source = self._source(release=True)
        destination = source.parent / "out"
        self.assertEqual(build_main(["--source", str(source), "--destination", str(destination)]), 0)
        catalog = json.loads((destination / "0.2.0" / "release" / "catalog.json").read_text(encoding="utf-8"))
        self.assertEqual([item["quizId"] for item in catalog["quizzes"]], ["life_tactics"])
        locale = json.loads((destination / "0.2.0" / "release" / "locales" / "en.json").read_text(encoding="utf-8"))
        self.assertEqual(locale["strings"]["life_tactics.title"], "life_tactics.title en")
        self.assertNotIn("life_tactics.note", locale["strings"])

    def test_real_pilot_is_preview_only(self):
        source = self._real()
        destination = source.parent / "pilot-out"
        self.assertEqual(build_main(["--source", str(source), "--destination", str(destination)]), 0)
        pilot = destination / "0.3.0" / "preview" / "pilots" / "life_tactics" / "scenario_v1.json"
        document = json.loads(pilot.read_text(encoding="utf-8"))
        self.assertEqual(document["pilotVersion"], "scenario_v1")
        self.assertEqual(len(document["scenarios"]), 6)
        self.assertEqual(len(document["scenarios"][0]["options"]), 3)
        self.assertFalse((destination / "0.3.0" / "release" / "pilots").exists())
        quiz = json.loads((destination / "0.3.0" / "preview" / "quizzes" / "life_tactics.json").read_text(encoding="utf-8"))
        self.assertEqual(quiz["questionCount"], 18)
        self.assertNotIn("scenarios", quiz)
        self.assertNotIn("scoringMode", document)
        scored = destination / "0.5.0" / "preview" / "pilots" / "life_tactics" / "scenario_v2.json"
        v2 = json.loads(scored.read_text(encoding="utf-8"))
        self.assertEqual(v2["scoringMode"], "option_points")
        self.assertEqual(v2["scenarios"][0]["options"][0]["pointsByDimension"], {"happiness": 2, "meaning": 1, "richness": 0})
        self.assertFalse((destination / "0.5.0" / "release" / "pilots").exists())
        previous = json.loads((destination / "0.5.0" / "preview" / "quizzes" / "life_tactics.json").read_text(encoding="utf-8"))
        self.assertIn("lt_rev_r01", [item["questionId"] for item in previous["questions"]])
        revised = destination / "0.6.0" / "preview" / "pilots" / "life_tactics" / "scenario_v2.json"
        v6 = json.loads(revised.read_text(encoding="utf-8"))
        self.assertEqual(v6["scoringMode"], "option_points")
        self.assertEqual(v6["scenarios"][0]["scenarioId"], "lt_s6_01")
        self.assertEqual(sum(len(scene["options"]) for scene in v6["scenarios"]), 18)
        self.assertEqual(v6["scenarios"][0]["options"][0]["pointsByDimension"], {"happiness": 2, "meaning": 1, "richness": 0})
        quiz6 = json.loads((destination / "0.6.0" / "preview" / "quizzes" / "life_tactics.json").read_text(encoding="utf-8"))
        ninth = quiz6["questions"][8]
        self.assertEqual(ninth["questionId"], "lt_r6_depth")
        self.assertTrue(ninth["reverse"])
        self.assertFalse((destination / "0.6.0" / "release" / "pilots").exists())
        plain = destination / "0.7.0" / "preview" / "pilots" / "life_tactics" / "scenario_v2.json"
        v7 = json.loads(plain.read_text(encoding="utf-8"))
        self.assertEqual(v7["scoringMode"], "option_points")
        self.assertEqual(v7["scenarios"][0]["scenarioId"], "lt_s7_01")
        self.assertEqual(sum(len(scene["options"]) for scene in v7["scenarios"]), 18)
        self.assertEqual(v7["scenarios"][0]["options"][0]["pointsByDimension"], {"happiness": 2, "meaning": 1, "richness": 0})
        quiz7 = json.loads((destination / "0.7.0" / "preview" / "quizzes" / "life_tactics.json").read_text(encoding="utf-8"))
        self.assertEqual(quiz7["questions"][0]["questionId"], "lt_q7_01")
        self.assertEqual(quiz7["questions"][8]["questionId"], "lt_q7_09")
        self.assertTrue(quiz7["questions"][8]["reverse"])
        self.assertFalse((destination / "0.7.0" / "release" / "pilots").exists())
        ko70 = json.loads((destination / "0.7.0" / "preview" / "locales" / "ko.json").read_text(encoding="utf-8"))
        self.assertEqual(
            ko70["strings"]["life_tactics.question.lt_q7_13"],
            "여럿이 만든 안내판을 누가 썼다면, 길을 찾는 데 도움이 됐는지 먼저 듣고 싶다.",
        )
        wording = destination / "0.7.1" / "preview"
        ko71 = json.loads((wording / "locales" / "ko.json").read_text(encoding="utf-8"))
        self.assertEqual(
            ko71["strings"]["life_tactics.question.lt_q7_13"],
            "우리가 만든 안내판을 본 사람에게 길을 쉽게 찾았는지 먼저 물어보고 싶다.",
        )
        quiz71 = json.loads((wording / "quizzes" / "life_tactics.json").read_text(encoding="utf-8"))
        self.assertEqual(quiz71["dataVersion"], "0.7.1")
        self.assertEqual(
            [item["questionId"] for item in quiz71["questions"]],
            [item["questionId"] for item in quiz7["questions"]],
        )
        v71 = json.loads((wording / "pilots" / "life_tactics" / "scenario_v2.json").read_text(encoding="utf-8"))
        self.assertEqual(v71["baseDataVersion"], "0.7.1")
        self.assertEqual(v71["scoringMode"], "option_points")
        self.assertEqual(
            v71["locales"]["ko"]["strings"]["life_tactics.scenario.lt_s7_03"],
            "여럿이 모이는 방에서 의자 자리를 바꿔 봐요. 어떻게 하고 싶나요?",
        )
        self.assertFalse((destination / "0.7.1" / "release" / "pilots").exists())
        directed = destination / "0.8.0" / "preview"
        quiz8 = json.loads((directed / "quizzes" / "life_tactics.json").read_text(encoding="utf-8"))
        self.assertEqual(quiz8["dataVersion"], "0.8.0")
        self.assertEqual([item["questionId"] for item in quiz8["questions"] if item["reverse"]], [
            "lt_q8_06", "lt_q7_09", "lt_q7_10", "lt_q8_14", "lt_q7_15", "lt_q8_17",
        ])
        self.assertEqual(quiz8["questions"][12]["questionId"], "lt_q8_13")
        self.assertFalse(quiz8["questions"][12]["reverse"])
        self.assertTrue(quiz8["questions"][16]["reverse"])
        ko80 = json.loads((directed / "locales" / "ko.json").read_text(encoding="utf-8"))
        self.assertEqual(
            ko80["strings"]["life_tactics.question.lt_q8_13"],
            "우리가 만든 안내판을 본 사람에게 한 가지만 물을 수 있다. 나는 글씨가 잘 보였는지보다 길을 쉽게 찾았는지 묻고 싶다.",
        )
        self.assertEqual(
            ko80["strings"]["life_tactics.question.lt_q8_17"],
            "바쁜 하루가 끝나면 잠깐 쉬기보다 내일 할 일을 미리 정리하고 싶다.",
        )
        v8 = json.loads((directed / "pilots" / "life_tactics" / "scenario_v2.json").read_text(encoding="utf-8"))
        self.assertEqual(v8["scoringMode"], "option_points")
        scenes = v8["locales"]["ko"]["strings"]
        self.assertEqual(scenes["life_tactics.scenario.lt_s8_02"], "친구와 함께한 날을 떠올려요. 서로 질문 하나씩 하기로 했어요. 무엇을 물을까요?")
        self.assertEqual(scenes["life_tactics.scenario.lt_s8_03"], "여럿이 모일 방에 의자를 놓아요. 의자를 하나 옮긴다면 어디에 놓을까요?")
        self.assertEqual(scenes["life_tactics.scenario.lt_s8_05"], "모임이 끝났어요. 다음에 올 사람에게 한 줄을 남긴다면 무엇을 적을까요?")
        self.assertFalse((destination / "0.8.0" / "release" / "pilots").exists())
        refreshed = destination / "0.9.0" / "preview"
        quiz9 = json.loads((refreshed / "quizzes" / "life_tactics.json").read_text(encoding="utf-8"))
        self.assertEqual(quiz9["dataVersion"], "0.9.0")
        self.assertEqual([item["questionId"] for item in quiz9["questions"] if item["reverse"]], [
            "lt_q9_06", "lt_q9_09", "lt_q9_15",
        ])
        self.assertEqual(quiz9["questions"][12]["questionId"], "lt_q9_13")
        self.assertFalse(quiz9["questions"][12]["reverse"])
        ko90 = json.loads((refreshed / "locales" / "ko.json").read_text(encoding="utf-8"))
        self.assertTrue(ko90["strings"]["life_tactics.question.lt_q9_13"].startswith("한 시간 동안 하고 싶은 일을 고를 수 있다."))
        v9 = json.loads((refreshed / "pilots" / "life_tactics" / "scenario_v2.json").read_text(encoding="utf-8"))
        self.assertEqual(v9["scoringMode"], "option_points")
        scenes9 = v9["locales"]["ko"]["strings"]
        self.assertEqual(scenes9["life_tactics.scenario.lt_s9_02"], "친구와 함께 보낸 하루를 떠올려요. 어떤 이야기를 나누고 싶나요?")
        self.assertEqual(scenes9["life_tactics.scenario.lt_s9_03"], "오늘 모임을 사진 한 장으로 남겨요. 어떤 순간을 담고 싶나요?")
        self.assertEqual(scenes9["life_tactics.scenario.lt_s9_06"], "오늘 일기에는 한 장면만 담을 자리가 있어요. 무엇을 남길까요?")
        self.assertFalse((destination / "0.9.0" / "release" / "pilots").exists())
        self.assertFalse((destination / "0.4.0" / "release" / "pilots").exists())

    def test_partial_pilot_sheet_fails(self):
        source = self._real()
        workbook = load_workbook(source / "Localization.xlsx")
        del workbook["PilotStrings"]
        workbook.save(source / "Localization.xlsx")
        workbook.close()
        message = self._errors(source)
        self.assertIn("시트가 없습니다", message)
        self.assertIn("PilotStrings", message)

    def test_inactive_scenario_is_not_enough(self):
        source = self._real()
        self._set(source, "QuestionData.xlsx", "Scenarios", 7, "IsActive", False)
        self.assertIn("활성 장면이 5개입니다", self._errors(source))

    def test_blank_scenario_points_are_not_zero(self):
        source = self._real()
        self._set(source, "QuestionData.xlsx", "ScenarioOptionScores", 4, "Points", "")
        self.assertIn("값이 비어 있습니다", self._errors(source))

    def test_scenario_points_must_match_primary_axis(self):
        source = self._real()
        self._set(source, "QuestionData.xlsx", "ScenarioOptionScores", 2, "Points", 1)
        self.assertIn("배점 합계 또는 주축", self._errors(source))

    def test_empty_pilot_korean_fails(self):
        source = self._real()
        self._set(source, "Localization.xlsx", "PilotStrings", 2, "ko", "")
        self.assertIn("한국어가 비어 있습니다", self._errors(source))

    def _errors(self, source):
        from io import StringIO
        from contextlib import redirect_stderr

        buffer = StringIO()
        with redirect_stderr(buffer):
            code = validate_main(["--source", str(source)])
        self.assertEqual(code, 1, buffer.getvalue())
        return buffer.getvalue()

    def _files(self, folder):
        return {
            path.relative_to(folder).as_posix(): path.read_bytes()
            for path in sorted(folder.rglob("*"))
            if path.is_file() and ".replacing" not in path.parts and ".staging" not in path.parts
        }

    def _set(self, source, filename, sheet, row, column_name, value):
        path = source / filename
        workbook = load_workbook(path)
        worksheet = workbook[sheet]
        headers = {cell.value: cell.column for cell in worksheet[1]}
        worksheet.cell(row, headers[column_name], value)
        workbook.save(path)
        workbook.close()

    def _real(self):
        source = Path(self._tmp.name) / self.id().split(".")[-1]
        shutil.copytree(ROOT / "data" / "source", source)
        return source

    def _source(self, release=False):
        folder = Path(self.id().split(".")[-1])
        source = Path(self._tmp.name) / folder
        source.mkdir()
        active = True if release else False
        rule = "approved" if release else "pending"
        question_review = "reviewed" if release else "draft"
        result_active = True if release else False
        design = "approved" if release else "candidate"
        title_status = "reviewed" if release else "draft"
        self._book(
            source / "QuizData.xlsx",
            {
                "Quizzes": [
                    ["QuizId", "DataVersion", "SortOrder", "IsActive", "TitleTextKey", "IntroTextKey", "ScoreMode", "CompletionPolicy", "ResultRuleStatus", "ResultTemplateId", "QuestionCount"],
                    ["life_tactics", "0.2.0", 1, active, "life_tactics.title", "life_tactics.intro", "independent_sum", "all_required", rule, "football_formation", 1],
                ],
                "Dimensions": [
                    ["DimensionId", "QuizId", "DataVersion", "SortOrder", "IsActive", "NameTextKey", "RoleTextKey"],
                    ["happiness", "life_tactics", "0.2.0", 1, True, "life_tactics.axis.happiness", "life_tactics.role.happiness"],
                ],
            },
        )
        self._book(
            source / "QuestionData.xlsx",
            {
                "Questions": [
                    ["QuestionId", "QuizId", "DataVersion", "SortOrder", "IsActive", "PromptTextKey", "ScaleId", "DimensionId", "Weight", "Reverse", "ReviewStatus"],
                    ["tq01", "life_tactics", "0.2.0", 1, True, "life_tactics.question.tq01", "agreement5", "happiness", 1, False, question_review],
                ],
                "Options": [
                    ["OptionId", "QuizId", "DataVersion", "SortOrder", "IsActive", "ScaleId", "LabelTextKey", "ScoreValue"],
                    ["a1", "life_tactics", "0.2.0", 1, True, "agreement5", "life_tactics.answer.a1", 1],
                ],
            },
        )
        self._book(
            source / "ResultTypeData.xlsx",
            {
                "ResultTypes": [
                    ["ResultTypeId", "QuizId", "DataVersion", "SortOrder", "IsActive", "NameTextKey", "Formation", "ShareTextKey", "DesignStatus", "DescriptionKey", "CatchphraseKey", "ResultTemplateId"],
                    ["tr01", "life_tactics", "0.2.0", 1, result_active, "life_tactics.result.tr01.name", "4-2-4", "life_tactics.result.tr01.share", design, "life_tactics.result.tr01.description", "life_tactics.result.tr01.catchphrase", "football_formation"],
                ],
            },
        )
        strings = [
            ["Key", "ko", "en", "ja", "pt-BR", "QuizId", "DataVersion", "SortOrder", "IsActive", "koStatus", "enStatus", "jaStatus", "pt-BRStatus"],
        ]
        rows = [
            ("life_tactics.title", "나의 인생 전술", "life_tactics"),
            ("life_tactics.intro", "소개", "life_tactics"),
            ("life_tactics.axis.happiness", "행복", "life_tactics"),
            ("life_tactics.role.happiness", "수비수", "life_tactics"),
            ("life_tactics.question.tq01", "문항", "life_tactics"),
            ("life_tactics.answer.a1", "전혀 그렇지 않다", "life_tactics"),
            ("life_tactics.result.tr01.name", "불꽃 모험가", "life_tactics"),
            ("life_tactics.result.tr01.share", "공유", "life_tactics"),
            ("life_tactics.result.tr01.description", "설명", "life_tactics"),
            ("life_tactics.result.tr01.catchphrase", "한 줄", "life_tactics"),
        ]
        for index, (key, ko, quiz_id) in enumerate(rows, start=1):
            if release:
                strings.append([
                    key, ko, f"{key} en", f"{key} ja", f"{key} pt", quiz_id,
                    "0.2.0", index, True, "reviewed", "reviewed", "reviewed", "reviewed",
                ])
            else:
                strings.append([
                    key, ko, None, None, None, quiz_id,
                    "0.2.0", index, True, "draft", "missing", "missing", "missing",
                ])
        if release:
            strings.append([
                "life_tactics.note", "메모", None, None, None, "life_tactics",
                "0.2.0", len(strings), True, "draft", "missing", "missing", "missing",
            ])
        self._book(source / "Localization.xlsx", {"Strings": strings})
        return source

    def _book(self, path, sheets):
        workbook = Workbook()
        first = True
        for name, rows in sheets.items():
            worksheet = workbook.active if first else workbook.create_sheet()
            first = False
            worksheet.title = name
            for row in rows:
                worksheet.append(row)
        workbook.save(path)
        workbook.close()


if __name__ == "__main__":
    unittest.main()
