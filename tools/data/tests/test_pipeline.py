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
