"""검증된 모델을 미리보기·출시 JSON으로 원자적으로 교체한다."""

import json
import shutil
from pathlib import Path

from lookatyou import SCHEMA_VERSION
from lookatyou.errors import DataError
from lookatyou.validate import RELEASE_LANGUAGES

QUIZ_FIELDS = (
    "quizId",
    "titleTextKey",
    "introTextKey",
    "questionCount",
    "resultTemplateId",
    "sortOrder",
    "isActive",
    "scoreMode",
    "completionPolicy",
    "resultRuleStatus",
)
DIMENSION_FIELDS = (
    "dimensionId",
    "quizId",
    "dataVersion",
    "sortOrder",
    "isActive",
    "nameTextKey",
    "roleTextKey",
)
QUESTION_FIELDS = (
    "questionId",
    "quizId",
    "dataVersion",
    "sortOrder",
    "isActive",
    "promptTextKey",
    "scaleId",
    "dimensionId",
    "weight",
    "reverse",
    "reviewStatus",
)
OPTION_FIELDS = (
    "optionId",
    "quizId",
    "dataVersion",
    "sortOrder",
    "isActive",
    "scaleId",
    "labelTextKey",
    "scoreValue",
)
RESULT_FIELDS = (
    "resultTypeId",
    "quizId",
    "dataVersion",
    "sortOrder",
    "isActive",
    "nameTextKey",
    "formation",
    "shareTextKey",
    "designStatus",
    "descriptionKey",
    "catchphraseKey",
    "resultTemplateId",
)


def publish(versions, destination, warnings):
    """모든 버전을 임시 폴더에 쓴 뒤 기존 번들과 교체한다."""
    destination = Path(destination)
    staging_root = destination / ".staging"
    if staging_root.exists():
        shutil.rmtree(staging_root)
    staging_root.mkdir(parents=True)
    try:
        for version in sorted(versions):
            _write_version(staging_root / version, version, versions[version], warnings)
        for version in sorted(versions):
            _replace(staging_root / version, destination / version)
    except Exception:
        if staging_root.exists():
            shutil.rmtree(staging_root, ignore_errors=True)
        raise
    if staging_root.exists():
        shutil.rmtree(staging_root, ignore_errors=True)


def _write_version(folder, version, bundle, warnings):
    preview = folder / "preview"
    release = folder / "release"
    (preview / "quizzes").mkdir(parents=True)
    (preview / "locales").mkdir(parents=True)
    (release / "locales").mkdir(parents=True)
    schema = bundle.get("schemaVersion") or SCHEMA_VERSION

    quizzes = _sorted(bundle["quizzes"], "sortOrder", "quizId")
    _dump(preview / "catalog.json", _catalog(schema, version, "preview", quizzes))
    for quiz in quizzes:
        _dump(preview / "quizzes" / f"{quiz['quizId']}.json", _quiz_document(schema, version, quiz, bundle))
    for language in RELEASE_LANGUAGES:
        _dump(
            preview / "locales" / f"{language}.json",
            _locale(schema, version, language, bundle["strings"], reviewed_only=False),
        )

    released = [quiz for quiz in quizzes if not quiz.get("releaseReasons")]
    if released:
        (release / "quizzes").mkdir(parents=True)
    _dump(release / "catalog.json", _catalog(schema, version, "release", released))
    for quiz in released:
        _dump(release / "quizzes" / f"{quiz['quizId']}.json", _quiz_document(schema, version, quiz, bundle))
    for language in RELEASE_LANGUAGES:
        _dump(
            release / "locales" / f"{language}.json",
            _locale(schema, version, language, bundle["strings"], reviewed_only=True),
        )
    _dump(folder / "report.json", _report(schema, version, quizzes, bundle["strings"], warnings))


def _catalog(schema, version, channel, quizzes):
    return {
        "schemaVersion": schema,
        "dataVersion": version,
        "channel": channel,
        "quizzes": [_pick(quiz, QUIZ_FIELDS) for quiz in quizzes],
    }


def _quiz_document(schema, version, quiz, bundle):
    quiz_id = quiz["quizId"]
    document = {
        "schemaVersion": schema,
        "dataVersion": version,
        "quizId": quiz_id,
        "scoreMode": quiz["scoreMode"],
        "completionPolicy": quiz["completionPolicy"],
        "resultRuleStatus": quiz["resultRuleStatus"],
        "resultTemplateId": quiz["resultTemplateId"],
        "titleTextKey": quiz["titleTextKey"],
        "introTextKey": quiz["introTextKey"],
        "questionCount": quiz["questionCount"],
        "isActive": quiz["isActive"],
        "sortOrder": quiz["sortOrder"],
        "dimensions": [
            _pick(item, DIMENSION_FIELDS)
            for item in _sorted(
                [item for item in bundle["dimensions"] if item.get("quizId") == quiz_id],
                "sortOrder",
                "dimensionId",
            )
        ],
        "questions": [
            _pick(item, QUESTION_FIELDS)
            for item in _sorted(
                [item for item in bundle["questions"] if item.get("quizId") == quiz_id],
                "sortOrder",
                "questionId",
            )
        ],
        "options": [
            _pick(item, OPTION_FIELDS)
            for item in _sorted(
                [item for item in bundle["options"] if item.get("quizId") == quiz_id],
                "sortOrder",
                "optionId",
            )
        ],
        "resultTypes": [
            _pick(item, RESULT_FIELDS)
            for item in _sorted(
                [item for item in bundle["results"] if item.get("quizId") == quiz_id],
                "sortOrder",
                "resultTypeId",
            )
        ],
    }
    if schema >= 2:
        document["rule"] = quiz.get("rule")
    return document


def _locale(schema, version, language, strings, reviewed_only):
    values = {}
    statuses = {}
    origins = {}
    for item in sorted(strings, key=lambda record: record.get("key") or ""):
        if item.get("isActive") is not True or not item.get("key"):
            continue
        status = item.get("statuses", {}).get(language)
        text = item.get("values", {}).get(language)
        if reviewed_only and status != "reviewed":
            continue
        if not text:
            continue
        values[item["key"]] = text
        statuses[item["key"]] = status
        origin = item.get("origins", {}).get(language)
        if origin:
            origins[item["key"]] = origin
    document = {
        "schemaVersion": schema,
        "dataVersion": version,
        "locale": language,
        "strings": values,
        "statuses": statuses,
    }
    if origins:
        document["origins"] = origins
    return document


def _report(schema, version, quizzes, strings, warnings):
    unreviewed = {language: 0 for language in RELEASE_LANGUAGES}
    machine = 0
    for item in strings:
        for language in RELEASE_LANGUAGES:
            if item.get("statuses", {}).get(language) != "reviewed":
                unreviewed[language] += 1
            if item.get("origins", {}).get(language) == "machine":
                machine += 1
    return {
        "schemaVersion": schema,
        "dataVersion": version,
        "releaseQuizIds": [quiz["quizId"] for quiz in quizzes if not quiz.get("releaseReasons")],
        "excluded": [
            {"quizId": quiz["quizId"], "reasons": list(quiz.get("releaseReasons") or [])}
            for quiz in quizzes
            if quiz.get("releaseReasons")
        ],
        "unreviewedKeys": unreviewed,
        "machineDraftValues": machine,
        "warnings": [str(item) for item in warnings if isinstance(item, DataError)],
    }


def _pick(record, fields):
    return {field: record.get(field) for field in fields}


def _sorted(records, order_field, id_field):
    return sorted(records, key=lambda item: (item.get(order_field) or 0, item.get(id_field) or ""))


def _dump(path, document):
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    path.write_text(text, encoding="utf-8", newline="\n")


def _replace(staging, destination):
    backup = destination.with_name(destination.name + ".replacing")
    if backup.exists():
        shutil.rmtree(backup)
    if destination.exists():
        destination.rename(backup)
    try:
        staging.rename(destination)
    except Exception:
        if backup.exists() and not destination.exists():
            backup.rename(destination)
        raise
    if backup.exists():
        shutil.rmtree(backup)
