"""openpyxl로 원본 시트를 읽는다. 수식은 계산하지 않는다."""

from pathlib import Path

from openpyxl import load_workbook

from lookatyou.errors import DataError

SOURCE_FILES = {
    "QuizData.xlsx": ("Quizzes", "Dimensions"),
    "QuestionData.xlsx": ("Questions", "Options"),
    "ResultTypeData.xlsx": ("ResultTypes",),
    "Localization.xlsx": ("Strings",),
}

# 규칙 시트는 있는 버전만 schema 2로 올린다. 둘 중 하나만 있으면 오류다.
OPTIONAL_SHEETS = {
    "ResultTypeData.xlsx": ("RuleSets", "RuleMappings"),
}

REQUIRED_COLUMNS = {
    ("QuizData.xlsx", "Quizzes"): (
        "QuizId",
        "DataVersion",
        "SortOrder",
        "IsActive",
        "TitleTextKey",
        "IntroTextKey",
        "ScoreMode",
        "CompletionPolicy",
        "ResultRuleStatus",
        "ResultTemplateId",
        "QuestionCount",
    ),
    ("QuizData.xlsx", "Dimensions"): (
        "DimensionId",
        "QuizId",
        "DataVersion",
        "SortOrder",
        "IsActive",
        "NameTextKey",
        "RoleTextKey",
    ),
    ("QuestionData.xlsx", "Questions"): (
        "QuestionId",
        "QuizId",
        "DataVersion",
        "SortOrder",
        "IsActive",
        "PromptTextKey",
        "ScaleId",
        "DimensionId",
        "Weight",
        "Reverse",
        "ReviewStatus",
    ),
    ("QuestionData.xlsx", "Options"): (
        "OptionId",
        "QuizId",
        "DataVersion",
        "SortOrder",
        "IsActive",
        "ScaleId",
        "LabelTextKey",
        "ScoreValue",
    ),
    ("ResultTypeData.xlsx", "ResultTypes"): (
        "ResultTypeId",
        "QuizId",
        "DataVersion",
        "SortOrder",
        "IsActive",
        "NameTextKey",
        "Formation",
        "ShareTextKey",
        "DesignStatus",
        "DescriptionKey",
        "CatchphraseKey",
        "ResultTemplateId",
    ),
    ("ResultTypeData.xlsx", "RuleSets"): (
        "QuizId",
        "DataVersion",
        "RuleVersion",
        "Strategy",
        "BalanceMaxRange",
        "DominanceMinGap",
        "TiePriority",
    ),
    ("ResultTypeData.xlsx", "RuleMappings"): (
        "QuizId",
        "DataVersion",
        "RuleVersion",
        "Kind",
        "FirstDimensionId",
        "SecondDimensionId",
        "ResultTypeId",
    ),
    ("Localization.xlsx", "Strings"): (
        "Key",
        "ko",
        "en",
        "ja",
        "pt-BR",
        "QuizId",
        "DataVersion",
        "SortOrder",
        "IsActive",
        "koStatus",
        "enStatus",
        "jaStatus",
        "pt-BRStatus",
    ),
}

OPTIONAL_COLUMNS = {
    ("Localization.xlsx", "Strings"): (
        "koOrigin",
        "enOrigin",
        "jaOrigin",
        "pt-BROrigin",
    ),
}


def read_sources(source_dir):
    """시트별 레코드 목록을 반환한다. 구조 오류는 예외 목록으로 모은다."""
    source_dir = Path(source_dir)
    tables = {}
    errors = []
    for filename, sheets in SOURCE_FILES.items():
        path = source_dir / filename
        if not path.is_file():
            errors.append(DataError("파일이 없습니다.", file=filename))
            continue
        try:
            workbook = load_workbook(path, data_only=False, read_only=False)
        except Exception as error:  # noqa: BLE001 - 파일 단위로 보고한다.
            errors.append(DataError(f"통합 문서를 열 수 없습니다. {error}", file=filename))
            continue
        try:
            for sheet_name in sheets:
                if sheet_name not in workbook.sheetnames:
                    errors.append(
                        DataError("시트가 없습니다.", file=filename, sheet=sheet_name)
                    )
                    continue
                records, sheet_errors = _read_sheet(
                    workbook[sheet_name], filename, sheet_name
                )
                errors.extend(sheet_errors)
                tables[(filename, sheet_name)] = records
            optional = OPTIONAL_SHEETS.get(filename, ())
            present = [name for name in optional if name in workbook.sheetnames]
            if present and len(present) != len(optional):
                for name in optional:
                    if name not in workbook.sheetnames:
                        errors.append(
                            DataError("시트가 없습니다.", file=filename, sheet=name)
                        )
            for sheet_name in present:
                records, sheet_errors = _read_sheet(
                    workbook[sheet_name], filename, sheet_name
                )
                errors.extend(sheet_errors)
                tables[(filename, sheet_name)] = records
        finally:
            workbook.close()
    return tables, errors


def _read_sheet(worksheet, filename, sheet_name):
    errors = []
    rows = list(worksheet.iter_rows())
    if not rows:
        return [], [DataError("헤더 행이 없습니다.", file=filename, sheet=sheet_name, row=1)]

    header = []
    for cell in rows[0]:
        if cell.data_type == "f":
            errors.append(
                DataError(
                    "수식 셀은 허용하지 않습니다. 계산 결과를 값으로 저장하세요.",
                    file=filename,
                    sheet=sheet_name,
                    row=cell.row,
                    column=_column_name(cell, header),
                )
            )
            header.append(None)
            continue
        if cell.value is None:
            break
        header.append(str(cell.value).strip())

    required = REQUIRED_COLUMNS[(filename, sheet_name)]
    optional = OPTIONAL_COLUMNS.get((filename, sheet_name), ())
    found = [name for name in header if name]
    missing = [name for name in required if name not in found]
    unknown = [name for name in found if name not in required and name not in optional]
    for name in missing:
        errors.append(
            DataError("필수 열이 없습니다.", file=filename, sheet=sheet_name, row=1, column=name)
        )
    for name in unknown:
        errors.append(
            DataError("알 수 없는 열입니다.", file=filename, sheet=sheet_name, row=1, column=name)
        )
    if missing or unknown or any(name is None for name in header):
        return [], errors

    records = []
    width = len(header)
    for row in rows[1:]:
        cells = list(row[:width])
        if all(cell.value is None and cell.data_type != "f" for cell in cells):
            continue
        record = {"__row": row[0].row}
        for name, cell in zip(header, cells):
            if cell.data_type == "f":
                errors.append(
                    DataError(
                        "수식 셀은 허용하지 않습니다. 계산 결과를 값으로 저장하세요.",
                        file=filename,
                        sheet=sheet_name,
                        row=cell.row,
                        column=name,
                    )
                )
                record[name] = None
                continue
            record[name] = cell.value
        records.append(record)
    return records, errors


def _column_name(cell, header):
    index = cell.column - 1
    if 0 <= index < len(header) and header[index]:
        return header[index]
    return cell.coordinate
