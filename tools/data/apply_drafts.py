"""비어 있는 출시 언어 칸에만 기계 초안을 넣는다. 기존 문구와 reviewed 상태는 바꾸지 않는다."""

import sys
from pathlib import Path

from openpyxl import load_workbook

sys.path.insert(0, str(Path(__file__).resolve().parent))

from lookatyou.machine_drafts import DRAFTS

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "data" / "source" / "Localization.xlsx"
LANGUAGES = ("en", "ja", "pt-BR")
STATUS = {"en": "enStatus", "ja": "jaStatus", "pt-BR": "pt-BRStatus"}
ORIGIN = {"en": "enOrigin", "ja": "jaOrigin", "pt-BR": "pt-BROrigin"}


def apply_drafts(path=SOURCE):
    workbook = load_workbook(path)
    worksheet = workbook["Strings"]
    headers = {cell.value: cell.column for cell in worksheet[1] if cell.value}
    for column_name in (*STATUS.values(), *ORIGIN.values()):
        if column_name not in headers:
            column = worksheet.max_column + 1
            worksheet.cell(1, column, column_name)
            headers[column_name] = column
    filled = 0
    skipped = []
    for row in range(2, worksheet.max_row + 1):
        key = worksheet.cell(row, headers["Key"]).value
        if not key:
            continue
        for language in LANGUAGES:
            cell = worksheet.cell(row, headers[language])
            current = cell.value.strip() if isinstance(cell.value, str) else cell.value
            if current not in (None, ""):
                continue
            draft = DRAFTS.get(language, {}).get(key)
            if not draft:
                skipped.append(f"{key} {language}")
                continue
            status_cell = worksheet.cell(row, headers[STATUS[language]])
            if status_cell.value not in (None, "", "missing"):
                skipped.append(f"{key} {language} status={status_cell.value}")
                continue
            cell.value = draft
            status_cell.value = "draft"
            worksheet.cell(row, headers[ORIGIN[language]], "machine")
            filled += 1
    workbook.save(path)
    workbook.close()
    return filled, skipped


def main():
    filled, skipped = apply_drafts()
    print(f"filled: {filled}")
    if skipped:
        print("skipped:")
        for item in skipped:
            print(f"- {item}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
