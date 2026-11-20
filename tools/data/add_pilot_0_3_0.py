"""0.2.0 참조를 0.3.0으로 복사하고 추천 문항과 미리보기 규칙만 추가한다.

검토 통합 문서는 data/source에 넣지 않는다. 이미 0.3.0 진단이 있으면 다시 쓰지 않는다.
"""

from pathlib import Path

from openpyxl import load_workbook

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "data" / "source"
REVIEW = ROOT / "docs" / "LookAtYou_QuestionData_Review_v0.3.xlsx"
AXES = {"H": "happiness", "M": "meaning", "R": "richness"}
MAPPINGS = (
    ("balance", None, None, "tr10"),
    ("dominant", "happiness", None, "tr07"),
    ("dominant", "meaning", None, "tr04"),
    ("dominant", "richness", None, "tr01"),
    ("mixed", "happiness", "meaning", "tr08"),
    ("mixed", "happiness", "richness", "tr09"),
    ("mixed", "meaning", "happiness", "tr06"),
    ("mixed", "meaning", "richness", "tr05"),
    ("mixed", "richness", "happiness", "tr03"),
    ("mixed", "richness", "meaning", "tr02"),
)


def main():
    if _has_version(SOURCE / "QuizData.xlsx", "Quizzes", "0.3.0"):
        print("0.3.0 진단이 이미 있어 원본을 바꾸지 않았습니다.")
        return 0
    questions = _recommended_questions()
    scale_id = _scale_id()
    _copy_workbook(
        "QuizData.xlsx",
        {"Quizzes": _quiz_patch, "Dimensions": None},
    )
    _copy_questions(questions, scale_id)
    _copy_workbook("ResultTypeData.xlsx", {"ResultTypes": None})
    _copy_strings(questions)
    _write_rules()
    print("added data version 0.3.0")
    return 0


def _recommended_questions():
    workbook = load_workbook(REVIEW, data_only=True, read_only=True)
    try:
        rows = list(workbook["Work_문항추천"].iter_rows(values_only=True))
    finally:
        workbook.close()
    header = rows[0]
    index = {name: position for position, name in enumerate(header)}
    found = []
    for row in rows[1:]:
        if not row or not row[index["신규 ID 후보"]]:
            continue
        found.append(
            {
                "id": str(row[index["신규 ID 후보"]]).strip(),
                "axis": AXES[str(row[index["축"]]).strip()],
                "text": str(row[index["추천 문항 (파일럿용)"]]).strip(),
            }
        )
    expected = [f"lt_vp{number:02d}" for number in range(1, 19)]
    if [item["id"] for item in found] != expected:
        raise SystemExit("추천 문항 ID가 lt_vp01…18 순서와 다릅니다.")
    return found


def _scale_id():
    workbook = load_workbook(SOURCE / "QuestionData.xlsx", data_only=True, read_only=True)
    try:
        rows = list(workbook["Questions"].iter_rows(values_only=True))
    finally:
        workbook.close()
    header = {name: position for position, name in enumerate(rows[0])}
    for row in rows[1:]:
        if row[header["QuizId"]] == "life_tactics" and row[header["DataVersion"]] == "0.2.0":
            return row[header["ScaleId"]]
    raise SystemExit("0.2.0 life_tactics 척도를 찾지 못했습니다.")


def _copy_workbook(filename, patches):
    path = SOURCE / filename
    workbook = load_workbook(path)
    try:
        for sheet_name, patch in patches.items():
            worksheet = workbook[sheet_name]
            header = [cell.value for cell in worksheet[1]]
            version_at = header.index("DataVersion")
            copies = []
            for cells in worksheet.iter_rows(min_row=2, values_only=True):
                if cells[version_at] != "0.2.0":
                    continue
                row = list(cells[: len(header)])
                row[version_at] = "0.3.0"
                if patch:
                    patch(header, row)
                copies.append(row)
            for row in copies:
                worksheet.append(row)
        workbook.save(path)
    finally:
        workbook.close()


def _quiz_patch(header, row):
    if row[header.index("QuizId")] == "life_tactics":
        row[header.index("QuestionCount")] = 18


def _copy_questions(questions, scale_id):
    path = SOURCE / "QuestionData.xlsx"
    workbook = load_workbook(path)
    try:
        options = workbook["Options"]
        header = [cell.value for cell in options[1]]
        version_at = header.index("DataVersion")
        for cells in list(options.iter_rows(min_row=2, values_only=True)):
            if cells[version_at] != "0.2.0":
                continue
            row = list(cells[: len(header)])
            row[version_at] = "0.3.0"
            options.append(row)

        sheet = workbook["Questions"]
        question_header = [cell.value for cell in sheet[1]]
        for order, item in enumerate(questions, start=1):
            values = {name: None for name in question_header}
            values.update(
                {
                    "QuestionId": item["id"],
                    "QuizId": "life_tactics",
                    "DataVersion": "0.3.0",
                    "SortOrder": order,
                    "IsActive": True,
                    "PromptTextKey": f"life_tactics.question.{item['id']}",
                    "ScaleId": scale_id,
                    "DimensionId": item["axis"],
                    "Weight": 1,
                    "Reverse": False,
                    "ReviewStatus": "draft",
                }
            )
            sheet.append([values[name] for name in question_header])
        workbook.save(path)
    finally:
        workbook.close()


def _copy_strings(questions):
    path = SOURCE / "Localization.xlsx"
    workbook = load_workbook(path)
    try:
        sheet = workbook["Strings"]
        header = [cell.value for cell in sheet[1]]
        version_at = header.index("DataVersion")
        order_at = header.index("SortOrder")
        quiz_at = header.index("QuizId")
        next_order = {}
        copies = []
        for cells in sheet.iter_rows(min_row=2, values_only=True):
            if cells[version_at] != "0.2.0":
                continue
            row = list(cells[: len(header)])
            row[version_at] = "0.3.0"
            quiz_id = row[quiz_at]
            order = row[order_at] or 0
            next_order[quiz_id] = max(next_order.get(quiz_id, 0), order)
            copies.append(row)
        for row in copies:
            sheet.append(row)

        def add(key, quiz_id, korean):
            next_order[quiz_id] = next_order.get(quiz_id, 0) + 1
            values = {name: None for name in header}
            values.update(
                {
                    "Key": key,
                    "ko": korean,
                    "QuizId": quiz_id,
                    "DataVersion": "0.3.0",
                    "SortOrder": next_order[quiz_id],
                    "IsActive": True,
                    "koStatus": "draft",
                    "enStatus": "missing",
                    "jaStatus": "missing",
                    "pt-BRStatus": "missing",
                }
            )
            sheet.append([values[name] for name in header])

        for item in questions:
            add(f"life_tactics.question.{item['id']}", "life_tactics", item["text"])
        add(
            "life_tactics.result.balance.note",
            "life_tactics",
            "이번 응답에서는 세 성향의 점수 차이가 작았어요.",
        )
        add(
            "life_tactics.result.preview.banner",
            "life_tactics",
            "미리보기 판정입니다. 출시 결과와 공유 이력에는 들어가지 않습니다.",
        )
        add(
            "life_tactics.result.boundary.note",
            "life_tactics",
            "경계 응답입니다. 답을 한 단계만 바꿔도 다른 전술이 나올 수 있습니다.",
        )
        add(
            "life_tactics.result.tie.note",
            "life_tactics",
            "동점인 성향은 나란히 둡니다. 순서는 강도의 차이가 아닙니다.",
        )
        workbook.save(path)
    finally:
        workbook.close()


def _write_rules():
    path = SOURCE / "ResultTypeData.xlsx"
    workbook = load_workbook(path)
    try:
        if "RuleSets" in workbook.sheetnames or "RuleMappings" in workbook.sheetnames:
            raise SystemExit("규칙 시트가 이미 있습니다.")
        rules = workbook.create_sheet("RuleSets")
        rules.append(
            [
                "QuizId",
                "DataVersion",
                "RuleVersion",
                "Strategy",
                "BalanceMaxRange",
                "DominanceMinGap",
                "TiePriority",
            ]
        )
        rules.append(
            [
                "life_tactics",
                "0.3.0",
                "life_rank_v1_preview",
                "range_gap_rank",
                12,
                20,
                "happiness,meaning,richness",
            ]
        )
        mappings = workbook.create_sheet("RuleMappings")
        mappings.append(
            [
                "QuizId",
                "DataVersion",
                "RuleVersion",
                "Kind",
                "FirstDimensionId",
                "SecondDimensionId",
                "ResultTypeId",
            ]
        )
        for kind, first, second, result_id in MAPPINGS:
            mappings.append(
                [
                    "life_tactics",
                    "0.3.0",
                    "life_rank_v1_preview",
                    kind,
                    first,
                    second,
                    result_id,
                ]
            )
        workbook.save(path)
    finally:
        workbook.close()


def _has_version(path, sheet_name, version):
    if not path.is_file():
        return False
    workbook = load_workbook(path, read_only=True, data_only=True)
    try:
        rows = workbook[sheet_name].iter_rows(values_only=True)
        header = next(rows)
        version_at = list(header).index("DataVersion")
        return any(row and row[version_at] == version for row in rows)
    finally:
        workbook.close()


if __name__ == "__main__":
    raise SystemExit(main())
