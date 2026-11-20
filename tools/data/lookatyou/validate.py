"""스키마 0.2.0 원본의 구조와 출시 조건을 검사한다."""

import math
import re
from datetime import date, datetime

from lookatyou.errors import DataError

VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+$")
PLACEHOLDER_PATTERN = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*)\}")
RELEASE_LANGUAGES = ("ko", "en", "ja", "pt-BR")
STATUS_COLUMNS = {
    "ko": "koStatus",
    "en": "enStatus",
    "ja": "jaStatus",
    "pt-BR": "pt-BRStatus",
}
ORIGIN_COLUMNS = {
    "ko": "koOrigin",
    "en": "enOrigin",
    "ja": "jaOrigin",
    "pt-BR": "pt-BROrigin",
}
SCORE_MODES = {"independent_sum", "pending"}
COMPLETION_POLICIES = {"all_required", "pending"}
RULE_STATUSES = {"pending", "approved"}
REVIEW_STATUSES = {"draft", "reviewed"}
DESIGN_STATUSES = {"candidate", "approved"}
STRING_STATUSES = {"missing", "draft", "reviewed"}
ORIGINS = {"human", "machine"}
RULE_STRATEGIES = {"range_gap_rank"}
RULE_KINDS = {"balance", "dominant", "mixed"}
# 화면 템플릿이 앱에 연결된 뒤에만 출시 목록에 넣는다.
RELEASE_TEMPLATES = {"football_formation"}


def validate_tables(tables):
    """구조 오류와 출시 경고, 버전별 모델을 반환한다."""
    errors = []
    warnings = []
    if any(key not in tables for key in (
        ("QuizData.xlsx", "Quizzes"),
        ("QuizData.xlsx", "Dimensions"),
        ("QuestionData.xlsx", "Questions"),
        ("QuestionData.xlsx", "Options"),
        ("ResultTypeData.xlsx", "ResultTypes"),
        ("Localization.xlsx", "Strings"),
    )):
        return errors, warnings, {}

    quizzes = _models(tables[("QuizData.xlsx", "Quizzes")], "QuizData.xlsx", "Quizzes", errors)
    dimensions = _models(tables[("QuizData.xlsx", "Dimensions")], "QuizData.xlsx", "Dimensions", errors)
    questions = _models(tables[("QuestionData.xlsx", "Questions")], "QuestionData.xlsx", "Questions", errors)
    options = _models(tables[("QuestionData.xlsx", "Options")], "QuestionData.xlsx", "Options", errors)
    results = _models(tables[("ResultTypeData.xlsx", "ResultTypes")], "ResultTypeData.xlsx", "ResultTypes", errors)
    strings = _models(tables[("Localization.xlsx", "Strings")], "Localization.xlsx", "Strings", errors)
    rule_sets = _models(
        tables.get(("ResultTypeData.xlsx", "RuleSets"), []),
        "ResultTypeData.xlsx",
        "RuleSets",
        errors,
    )
    rule_mappings = _models(
        tables.get(("ResultTypeData.xlsx", "RuleMappings"), []),
        "ResultTypeData.xlsx",
        "RuleMappings",
        errors,
    )

    versions = {}
    groups = (
        ("quizzes", quizzes),
        ("dimensions", dimensions),
        ("questions", questions),
        ("options", options),
        ("results", results),
        ("strings", strings),
        ("ruleSets", rule_sets),
        ("ruleMappings", rule_mappings),
    )
    for name, records in groups:
        for record in records:
            version = record.get("dataVersion")
            if not version:
                continue
            versions.setdefault(version, {key: [] for key, _ in groups})
            versions[version][name].append(record)

    for version, bundle in versions.items():
        _validate_version(version, bundle, errors, warnings)
    return errors, warnings, versions


def _models(records, filename, sheet, errors):
    models = []
    for record in records:
        row = record["__row"]
        location = {"file": filename, "sheet": sheet, "row": row}
        model = {"row": row, "file": filename, "sheet": sheet}
        if sheet == "Quizzes":
            model.update(_quiz(record, location, errors))
        elif sheet == "Dimensions":
            model.update(_dimension(record, location, errors))
        elif sheet == "Questions":
            model.update(_question(record, location, errors))
        elif sheet == "Options":
            model.update(_option(record, location, errors))
        elif sheet == "ResultTypes":
            model.update(_result(record, location, errors))
        elif sheet == "RuleSets":
            model.update(_rule_set(record, location, errors))
        elif sheet == "RuleMappings":
            model.update(_rule_mapping(record, location, errors))
        else:
            model.update(_string(record, location, errors))
        models.append(model)
    return models


def _validate_version(version, bundle, errors, warnings):
    quizzes = bundle["quizzes"]
    quiz_ids = _unique(
        quizzes,
        lambda item: item.get("quizId"),
        "QuizId",
        errors,
    )
    _unique_order(quizzes, lambda item: item.get("quizId") or "", "Quizzes", errors)

    for dimension in bundle["dimensions"]:
        _require_quiz(dimension, quiz_ids, errors)
    for question in bundle["questions"]:
        _require_quiz(question, quiz_ids, errors)
    for option in bundle["options"]:
        _require_quiz(option, quiz_ids, errors)
    for result in bundle["results"]:
        _require_quiz(result, quiz_ids, errors)

    _unique_within(bundle["dimensions"], ("quizId", "dimensionId"), "DimensionId", errors)
    _unique_within(bundle["questions"], ("quizId", "questionId"), "QuestionId", errors)
    _unique_within(bundle["options"], ("quizId", "scaleId", "optionId"), "OptionId", errors)
    _unique_within(bundle["results"], ("quizId", "resultTypeId"), "ResultTypeId", errors)
    _unique(bundle["strings"], lambda item: item.get("key"), "Key", errors)

    _unique_order_within(bundle["dimensions"], "quizId", "Dimensions", errors)
    _unique_order_within(bundle["questions"], "quizId", "Questions", errors)
    _unique_order_within(bundle["options"], ("quizId", "scaleId"), "Options", errors)
    _unique_order_within(bundle["results"], "quizId", "ResultTypes", errors)
    _unique_order_within(bundle["strings"], "quizId", "Strings", errors)

    string_by_key = {}
    for item in bundle["strings"]:
        key = item.get("key")
        if key:
            string_by_key.setdefault(key, item)
            _check_key_scope(item, errors)

    dimensions_by_quiz = _group(bundle["dimensions"], "quizId")
    questions_by_quiz = _group(bundle["questions"], "quizId")
    options_by_quiz = _group(bundle["options"], "quizId")
    results_by_quiz = _group(bundle["results"], "quizId")

    for quiz in quizzes:
        quiz_id = quiz.get("quizId")
        if not quiz_id:
            continue
        reasons = _quiz_links(
            quiz,
            dimensions_by_quiz.get(quiz_id, []),
            questions_by_quiz.get(quiz_id, []),
            options_by_quiz.get(quiz_id, []),
            results_by_quiz.get(quiz_id, []),
            string_by_key,
            errors,
            warnings,
        )
        quiz["releaseReasons"] = reasons
        if reasons:
            warnings.append(
                DataError(
                    "출시 목록에서 제외합니다. " + "; ".join(reasons),
                    file="QuizData.xlsx",
                    sheet="Quizzes",
                    row=quiz["row"],
                    column="QuizId",
                )
            )
    _validate_rules(version, bundle, errors)
    bundle["schemaVersion"] = 2 if bundle.get("ruleSets") else 1


def _validate_rules(version, bundle, errors):
    """규칙이 있는 버전만 schema 2다. 규칙 행이 없는 진단에는 전략을 넣지 않는다."""
    quizzes = {item.get("quizId"): item for item in bundle["quizzes"] if item.get("quizId")}
    for quiz in bundle["quizzes"]:
        quiz["rule"] = None
    sets_by_quiz = {}
    for item in bundle.get("ruleSets", []):
        quiz_id = item.get("quizId")
        if quiz_id in sets_by_quiz:
            errors.append(
                DataError(
                    f"QuizId {quiz_id}의 규칙 세트가 둘 이상입니다.",
                    file=item["file"],
                    sheet=item["sheet"],
                    row=item["row"],
                    column="QuizId",
                )
            )
            continue
        sets_by_quiz[quiz_id] = item
        if quiz_id not in quizzes:
            errors.append(
                DataError(
                    f"규칙의 QuizId {quiz_id}가 이 버전에 없습니다.",
                    file=item["file"],
                    sheet=item["sheet"],
                    row=item["row"],
                    column="QuizId",
                )
            )

    mappings_by_quiz = {}
    for item in bundle.get("ruleMappings", []):
        quiz_id = item.get("quizId")
        mappings_by_quiz.setdefault(quiz_id, []).append(item)
        rule_set = sets_by_quiz.get(quiz_id)
        if rule_set is None:
            errors.append(
                DataError(
                    f"매핑의 QuizId {quiz_id}에 규칙 세트가 없습니다.",
                    file=item["file"],
                    sheet=item["sheet"],
                    row=item["row"],
                    column="QuizId",
                )
            )
            continue
        if item.get("ruleVersion") != rule_set.get("ruleVersion"):
            errors.append(
                DataError(
                    "매핑의 RuleVersion이 규칙 세트와 다릅니다.",
                    file=item["file"],
                    sheet=item["sheet"],
                    row=item["row"],
                    column="RuleVersion",
                )
            )

    for quiz_id, rule_set in sets_by_quiz.items():
        quiz = quizzes.get(quiz_id)
        if quiz is None or rule_set.get("strategy") != "range_gap_rank":
            continue
        dimension_ids = [
            item["dimensionId"]
            for item in bundle["dimensions"]
            if item.get("quizId") == quiz_id and item.get("isActive") is True and item.get("dimensionId")
        ]
        results = {
            item.get("resultTypeId"): item
            for item in bundle["results"]
            if item.get("quizId") == quiz_id and item.get("resultTypeId")
        }
        mappings = mappings_by_quiz.get(quiz_id, [])
        _rule_shape(rule_set, dimension_ids, results, mappings, errors)
        quiz["rule"] = {
            "ruleVersion": rule_set.get("ruleVersion"),
            "strategy": rule_set.get("strategy"),
            "balanceMaxRange": rule_set.get("balanceMaxRange"),
            "dominanceMinGap": rule_set.get("dominanceMinGap"),
            "tiePriority": list(rule_set.get("tiePriority") or []),
            "mappings": [
                {
                    "kind": item.get("kind"),
                    "firstDimensionId": item.get("firstDimensionId"),
                    "secondDimensionId": item.get("secondDimensionId"),
                    "resultTypeId": item.get("resultTypeId"),
                }
                for item in sorted(
                    mappings,
                    key=lambda record: (
                        record.get("kind") or "",
                        record.get("firstDimensionId") or "",
                        record.get("secondDimensionId") or "",
                        record.get("resultTypeId") or "",
                    ),
                )
            ],
        }


def _rule_shape(rule_set, dimension_ids, results, mappings, errors):
    balance = rule_set.get("balanceMaxRange")
    dominance = rule_set.get("dominanceMinGap")
    if (
        isinstance(balance, (int, float))
        and isinstance(dominance, (int, float))
        and not isinstance(balance, bool)
        and not isinstance(dominance, bool)
        and not (0 <= balance < dominance <= 100)
    ):
        errors.append(
            DataError(
                "임계값은 0 이상, 균형 상한은 단독 하한보다 작고, 단독 하한은 100 이하여야 합니다.",
                file=rule_set["file"],
                sheet=rule_set["sheet"],
                row=rule_set["row"],
                column="BalanceMaxRange",
            )
        )
    priority = rule_set.get("tiePriority") or []
    if sorted(priority) != sorted(dimension_ids) or len(priority) != len(set(priority)):
        errors.append(
            DataError(
                "TiePriority는 활성 축을 한 번씩만 포함해야 합니다.",
                file=rule_set["file"],
                sheet=rule_set["sheet"],
                row=rule_set["row"],
                column="TiePriority",
            )
        )
    if len(set(dimension_ids)) != 3 or len(dimension_ids) != 3:
        errors.append(
            DataError(
                "range_gap_rank는 활성 축 3개인 진단에만 사용할 수 있습니다.",
                file=rule_set["file"],
                sheet=rule_set["sheet"],
                row=rule_set["row"],
                column="Strategy",
            )
        )
    seen_keys = set()
    seen_results = set()
    counts = {"balance": 0, "dominant": 0, "mixed": 0}
    for item in mappings:
        kind = item.get("kind")
        first = item.get("firstDimensionId")
        second = item.get("secondDimensionId")
        result_id = item.get("resultTypeId")
        if kind in counts:
            counts[kind] += 1
        key = (kind, first, second)
        if key in seen_keys:
            errors.append(
                DataError(
                    "같은 판정 키가 중복입니다.",
                    file=item["file"],
                    sheet=item["sheet"],
                    row=item["row"],
                    column="Kind",
                )
            )
        seen_keys.add(key)
        if result_id in seen_results:
            errors.append(
                DataError(
                    f"결과 {result_id}가 규칙 안에서 중복입니다.",
                    file=item["file"],
                    sheet=item["sheet"],
                    row=item["row"],
                    column="ResultTypeId",
                )
            )
        if result_id:
            seen_results.add(result_id)
        if result_id and result_id not in results:
            errors.append(
                DataError(
                    f"결과 {result_id}가 이 진단에 없습니다.",
                    file=item["file"],
                    sheet=item["sheet"],
                    row=item["row"],
                    column="ResultTypeId",
                )
            )
        for axis, column in ((first, "FirstDimensionId"), (second, "SecondDimensionId")):
            if axis and axis not in dimension_ids:
                errors.append(
                    DataError(
                        f"축 {axis}가 이 진단의 활성 축이 아닙니다.",
                        file=item["file"],
                        sheet=item["sheet"],
                        row=item["row"],
                        column=column,
                    )
                )
        if kind == "balance" and (first or second):
            errors.append(
                DataError(
                    "균형 매핑의 두 축은 비워야 합니다.",
                    file=item["file"],
                    sheet=item["sheet"],
                    row=item["row"],
                    column="FirstDimensionId",
                )
            )
        if kind == "dominant" and (not first or second):
            errors.append(
                DataError(
                    "단독 매핑은 첫째 축만 채웁니다.",
                    file=item["file"],
                    sheet=item["sheet"],
                    row=item["row"],
                    column="SecondDimensionId",
                )
            )
        if kind == "mixed" and (not first or not second or first == second):
            errors.append(
                DataError(
                    "혼합 매핑은 서로 다른 두 축이 필요합니다.",
                    file=item["file"],
                    sheet=item["sheet"],
                    row=item["row"],
                    column="SecondDimensionId",
                )
            )
    if len(set(dimension_ids)) == 3 and counts != {"balance": 1, "dominant": 3, "mixed": 6}:
        errors.append(
            DataError(
                "3축 규칙은 균형 1, 단독 3, 순서 있는 혼합 6이 모두 있어야 합니다.",
                file=rule_set["file"],
                sheet=rule_set["sheet"],
                row=rule_set["row"],
                column="Strategy",
            )
        )


def _quiz_links(quiz, dimensions, questions, options, results, string_by_key, errors, warnings):
    quiz_id = quiz["quizId"]
    active_questions = [item for item in questions if item.get("isActive") is True]
    if quiz.get("questionCount") is not None and quiz["questionCount"] != len(active_questions):
        errors.append(
            DataError(
                f"QuestionCount {quiz['questionCount']}와 활성 문항 수 {len(active_questions)}가 다릅니다.",
                file=quiz["file"],
                sheet=quiz["sheet"],
                row=quiz["row"],
                column="QuestionCount",
            )
        )

    dimension_ids = {
        item["dimensionId"]
        for item in dimensions
        if item.get("dimensionId")
    }
    scales = {}
    for option in options:
        scales.setdefault(option.get("scaleId"), []).append(option)

    used_dimensions = set()
    used_scales = set()
    used_keys = []
    for key_name in ("titleTextKey", "introTextKey"):
        used_keys.append((quiz, key_name, quiz.get(key_name)))

    for dimension in dimensions:
        used_keys.append((dimension, "nameTextKey", dimension.get("nameTextKey")))
        if dimension.get("roleTextKey"):
            used_keys.append((dimension, "roleTextKey", dimension.get("roleTextKey")))

    for question in questions:
        if question.get("dimensionId") and question["dimensionId"] not in dimension_ids:
            errors.append(
                DataError(
                    f"축 {question['dimensionId']}가 이 진단에 없습니다.",
                    file=question["file"],
                    sheet=question["sheet"],
                    row=question["row"],
                    column="DimensionId",
                )
            )
        scale_id = question.get("scaleId")
        if scale_id and scale_id not in scales:
            errors.append(
                DataError(
                    f"척도 {scale_id}의 선택지가 없습니다.",
                    file=question["file"],
                    sheet=question["sheet"],
                    row=question["row"],
                    column="ScaleId",
                )
            )
        if question.get("isActive") is True:
            if question.get("dimensionId"):
                used_dimensions.add(question["dimensionId"])
            if scale_id:
                used_scales.add(scale_id)
        used_keys.append((question, "promptTextKey", question.get("promptTextKey")))

    for option in options:
        used_keys.append((option, "labelTextKey", option.get("labelTextKey")))
        if option.get("scaleId") and option["scaleId"] not in used_scales and questions:
            # 문항이 있는 진단에서 어떤 문항도 쓰지 않는 척도만 고아로 본다.
            pass
    for scale_id, scale_options in scales.items():
        active_values = [
            item.get("scoreValue")
            for item in scale_options
            if item.get("isActive") is True and isinstance(item.get("scoreValue"), (int, float)) and not isinstance(item.get("scoreValue"), bool)
        ]
        if len(active_values) >= 2 and len(active_values) != len(set(active_values)):
            sample = scale_options[0]
            errors.append(
                DataError(
                    f"척도 {scale_id}의 ScoreValue가 중복입니다.",
                    file=sample["file"],
                    sheet=sample["sheet"],
                    row=sample["row"],
                    column="ScoreValue",
                )
            )
        if len(active_values) >= 2 and min(active_values) == max(active_values):
            sample = scale_options[0]
            errors.append(
                DataError(
                    f"척도 {scale_id}의 점수 폭이 0입니다.",
                    file=sample["file"],
                    sheet=sample["sheet"],
                    row=sample["row"],
                    column="ScoreValue",
                )
            )

    orphan_scales = set(scales) - {question.get("scaleId") for question in questions}
    for scale_id in sorted(item for item in orphan_scales if item):
        sample = scales[scale_id][0]
        errors.append(
            DataError(
                f"척도 {scale_id}를 쓰는 문항이 없습니다.",
                file=sample["file"],
                sheet=sample["sheet"],
                row=sample["row"],
                column="ScaleId",
            )
        )

    if active_questions:
        for dimension in dimensions:
            if dimension.get("isActive") is True and dimension.get("dimensionId") not in used_dimensions:
                warnings.append(
                    DataError(
                        f"활성 축 {dimension['dimensionId']}에 연결된 활성 문항이 없습니다.",
                        file=dimension["file"],
                        sheet=dimension["sheet"],
                        row=dimension["row"],
                        column="DimensionId",
                    )
                )

    for result in results:
        if result.get("resultTemplateId") and quiz.get("resultTemplateId") and result["resultTemplateId"] != quiz["resultTemplateId"]:
            errors.append(
                DataError(
                    "결과 화면 ID가 진단의 ResultTemplateId와 다릅니다.",
                    file=result["file"],
                    sheet=result["sheet"],
                    row=result["row"],
                    column="ResultTemplateId",
                )
            )
        for key_name in ("nameTextKey", "shareTextKey", "descriptionKey", "catchphraseKey"):
            used_keys.append((result, key_name, result.get(key_name)))

    referenced = []
    for owner, field, key in used_keys:
        if not key:
            continue
        referenced.append(key)
        item = string_by_key.get(key)
        column = _field_column(field)
        if item is None:
            errors.append(
                DataError(
                    f"문구 키 {key}가 Strings에 없습니다.",
                    file=owner["file"],
                    sheet=owner["sheet"],
                    row=owner["row"],
                    column=column,
                )
            )
            continue
        if item.get("quizId") not in {quiz_id, "common"}:
            errors.append(
                DataError(
                    f"문구 키 {key}의 QuizId가 진단 {quiz_id} 또는 common이 아닙니다.",
                    file=item["file"],
                    sheet=item["sheet"],
                    row=item["row"],
                    column="QuizId",
                )
            )
        if item.get("isActive") is not True:
            errors.append(
                DataError(
                    f"참조된 문구 키 {key}가 비활성입니다.",
                    file=item["file"],
                    sheet=item["sheet"],
                    row=item["row"],
                    column="IsActive",
                )
            )
        if not _text(item.get("values", {}).get("ko")):
            errors.append(
                DataError(
                    f"참조된 문구 키 {key}의 한국어 원문이 비어 있습니다.",
                    file=item["file"],
                    sheet=item["sheet"],
                    row=item["row"],
                    column="ko",
                )
            )

    reasons = []
    if quiz.get("isActive") is not True:
        reasons.append("진단이 비활성")
    if quiz.get("scoreMode") != "independent_sum":
        reasons.append("ScoreMode가 independent_sum이 아님")
    if quiz.get("completionPolicy") != "all_required":
        reasons.append("CompletionPolicy가 all_required가 아님")
    if quiz.get("resultRuleStatus") != "approved":
        reasons.append("판정 규칙이 승인 전")
    if quiz.get("resultTemplateId") not in RELEASE_TEMPLATES:
        reasons.append("출시용 화면 템플릿이 아님")
    if any(item.get("reviewStatus") != "reviewed" for item in active_questions):
        reasons.append("활성 문항이 검수 완료가 아님")
    active_results = [item for item in results if item.get("isActive") is True]
    if not active_results or any(item.get("designStatus") != "approved" for item in active_results):
        reasons.append("승인된 활성 결과 타입이 없음")
    if _unreviewed_release_text(referenced, string_by_key):
        reasons.append("출시 언어 번역이 검수 완료가 아님")
    return reasons


def _unreviewed_release_text(keys, string_by_key):
    for key in keys:
        item = string_by_key.get(key)
        if item is None:
            return True
        for language in RELEASE_LANGUAGES:
            status = item.get("statuses", {}).get(language)
            value = _text(item.get("values", {}).get(language))
            if status != "reviewed" or not value:
                return True
    return False


def _check_key_scope(item, errors):
    key = item.get("key") or ""
    quiz_id = item.get("quizId")
    if quiz_id == "common":
        if not key.startswith("common."):
            errors.append(
                DataError(
                    "common 범위의 키는 common.으로 시작해야 합니다.",
                    file=item["file"],
                    sheet=item["sheet"],
                    row=item["row"],
                    column="Key",
                )
            )
        return
    if quiz_id and not key.startswith(quiz_id + "."):
        errors.append(
            DataError(
                "키 접두사가 QuizId와 다릅니다.",
                file=item["file"],
                sheet=item["sheet"],
                row=item["row"],
                column="Key",
            )
        )


def _require_quiz(record, quiz_ids, errors):
    quiz_id = record.get("quizId")
    if quiz_id and quiz_id not in quiz_ids:
        errors.append(
            DataError(
                f"QuizId {quiz_id}가 Quizzes에 없습니다.",
                file=record["file"],
                sheet=record["sheet"],
                row=record["row"],
                column="QuizId",
            )
        )


def _unique(records, key_of, column, errors):
    seen = {}
    for record in records:
        key = key_of(record)
        if not key:
            continue
        if key in seen:
            errors.append(
                DataError(
                    f"{column} {key}가 중복입니다. 첫 행은 {seen[key]}행입니다.",
                    file=record["file"],
                    sheet=record["sheet"],
                    row=record["row"],
                    column=column,
                )
            )
        else:
            seen[key] = record["row"]
    return set(seen)


def _unique_within(records, fields, column, errors):
    seen = {}
    for record in records:
        key = tuple(record.get(field) for field in fields)
        if any(part in (None, "") for part in key):
            continue
        if key in seen:
            errors.append(
                DataError(
                    f"{column} {key[-1]}가 같은 범위에서 중복입니다. 첫 행은 {seen[key]}행입니다.",
                    file=record["file"],
                    sheet=record["sheet"],
                    row=record["row"],
                    column=column,
                )
            )
        else:
            seen[key] = record["row"]


def _unique_order(records, identity, sheet, errors):
    seen = {}
    for record in records:
        order = record.get("sortOrder")
        if not isinstance(order, int):
            continue
        if order in seen:
            errors.append(
                DataError(
                    f"SortOrder {order}가 중복입니다.",
                    file=record["file"],
                    sheet=record["sheet"],
                    row=record["row"],
                    column="SortOrder",
                )
            )
        else:
            seen[order] = identity(record)


def _unique_order_within(records, group, sheet, errors):
    seen = {}
    for record in records:
        order = record.get("sortOrder")
        if not isinstance(order, int):
            continue
        if isinstance(group, tuple):
            scope = tuple(record.get(field) for field in group)
        else:
            scope = (record.get(group),)
        key = (*scope, order)
        if key in seen:
            errors.append(
                DataError(
                    f"SortOrder {order}가 같은 범위에서 중복입니다.",
                    file=record["file"],
                    sheet=record["sheet"],
                    row=record["row"],
                    column="SortOrder",
                )
            )
        else:
            seen[key] = record["row"]


def _group(records, field):
    grouped = {}
    for record in records:
        grouped.setdefault(record.get(field), []).append(record)
    return grouped


def _quiz(record, location, errors):
    return {
        "quizId": _identifier(record, "QuizId", location, errors),
        "dataVersion": _version(record, location, errors),
        "sortOrder": _order(record, location, errors),
        "isActive": _bool(record, "IsActive", location, errors),
        "titleTextKey": _required_text(record, "TitleTextKey", location, errors),
        "introTextKey": _required_text(record, "IntroTextKey", location, errors),
        "scoreMode": _choice(record, "ScoreMode", SCORE_MODES, location, errors),
        "completionPolicy": _choice(record, "CompletionPolicy", COMPLETION_POLICIES, location, errors),
        "resultRuleStatus": _choice(record, "ResultRuleStatus", RULE_STATUSES, location, errors),
        "resultTemplateId": _required_text(record, "ResultTemplateId", location, errors),
        "questionCount": _whole(record, "QuestionCount", location, errors, minimum=0),
    }


def _dimension(record, location, errors):
    return {
        "dimensionId": _identifier(record, "DimensionId", location, errors),
        "quizId": _identifier(record, "QuizId", location, errors),
        "dataVersion": _version(record, location, errors),
        "sortOrder": _order(record, location, errors),
        "isActive": _bool(record, "IsActive", location, errors),
        "nameTextKey": _required_text(record, "NameTextKey", location, errors),
        "roleTextKey": _optional_text(record.get("RoleTextKey"), "RoleTextKey", location, errors),
    }


def _question(record, location, errors):
    return {
        "questionId": _identifier(record, "QuestionId", location, errors),
        "quizId": _identifier(record, "QuizId", location, errors),
        "dataVersion": _version(record, location, errors),
        "sortOrder": _order(record, location, errors),
        "isActive": _bool(record, "IsActive", location, errors),
        "promptTextKey": _required_text(record, "PromptTextKey", location, errors),
        "scaleId": _identifier(record, "ScaleId", location, errors),
        "dimensionId": _identifier(record, "DimensionId", location, errors),
        "weight": _positive_number(record, "Weight", location, errors),
        "reverse": _bool(record, "Reverse", location, errors),
        "reviewStatus": _choice(record, "ReviewStatus", REVIEW_STATUSES, location, errors),
    }


def _option(record, location, errors):
    return {
        "optionId": _identifier(record, "OptionId", location, errors),
        "quizId": _identifier(record, "QuizId", location, errors),
        "dataVersion": _version(record, location, errors),
        "sortOrder": _order(record, location, errors),
        "isActive": _bool(record, "IsActive", location, errors),
        "scaleId": _identifier(record, "ScaleId", location, errors),
        "labelTextKey": _required_text(record, "LabelTextKey", location, errors),
        "scoreValue": _number(record, "ScoreValue", location, errors),
    }


def _result(record, location, errors):
    return {
        "resultTypeId": _identifier(record, "ResultTypeId", location, errors),
        "quizId": _identifier(record, "QuizId", location, errors),
        "dataVersion": _version(record, location, errors),
        "sortOrder": _order(record, location, errors),
        "isActive": _bool(record, "IsActive", location, errors),
        "nameTextKey": _required_text(record, "NameTextKey", location, errors),
        "formation": _formation(record, location, errors),
        "shareTextKey": _required_text(record, "ShareTextKey", location, errors),
        "designStatus": _choice(record, "DesignStatus", DESIGN_STATUSES, location, errors),
        "descriptionKey": _required_text(record, "DescriptionKey", location, errors),
        "catchphraseKey": _required_text(record, "CatchphraseKey", location, errors),
        "resultTemplateId": _required_text(record, "ResultTemplateId", location, errors),
    }


def _rule_set(record, location, errors):
    return {
        "quizId": _identifier(record, "QuizId", location, errors),
        "dataVersion": _version(record, location, errors),
        "ruleVersion": _required_text(record, "RuleVersion", location, errors),
        "strategy": _choice(record, "Strategy", RULE_STRATEGIES, location, errors),
        "balanceMaxRange": _number(record, "BalanceMaxRange", location, errors),
        "dominanceMinGap": _number(record, "DominanceMinGap", location, errors),
        "tiePriority": _tie_priority(record, location, errors),
    }


def _rule_mapping(record, location, errors):
    return {
        "quizId": _identifier(record, "QuizId", location, errors),
        "dataVersion": _version(record, location, errors),
        "ruleVersion": _required_text(record, "RuleVersion", location, errors),
        "kind": _choice(record, "Kind", RULE_KINDS, location, errors),
        "firstDimensionId": _optional_identifier(record, "FirstDimensionId", location, errors),
        "secondDimensionId": _optional_identifier(record, "SecondDimensionId", location, errors),
        "resultTypeId": _identifier(record, "ResultTypeId", location, errors),
    }


def _tie_priority(record, location, errors):
    text = _required_text(record, "TiePriority", location, errors)
    if not text:
        return []
    parts = [part.strip() for part in text.split(",")]
    if any(not part for part in parts):
        errors.append(
            DataError(
                "TiePriority 항목이 비어 있습니다.",
                **location,
                column="TiePriority",
            )
        )
    return [part for part in parts if part]


def _optional_identifier(record, column, location, errors):
    value = record.get(column)
    if value is None or value == "":
        return None
    if not isinstance(value, str):
        errors.append(DataError("문자열이거나 빈 칸이어야 합니다.", **location, column=column))
        return None
    text = value.strip()
    if not text:
        return None
    if any(character.isspace() for character in text):
        errors.append(DataError("ID에 공백이 있습니다.", **location, column=column))
    return text


def _string(record, location, errors):
    values = {}
    statuses = {}
    origins = {}
    for language in RELEASE_LANGUAGES:
        values[language] = _optional_text(record.get(language), language, location, errors)
        statuses[language] = _choice(record, STATUS_COLUMNS[language], STRING_STATUSES, location, errors)
        origin_column = ORIGIN_COLUMNS[language]
        if origin_column in record and record.get(origin_column) not in (None, ""):
            origins[language] = _choice(record, origin_column, ORIGINS, location, errors)
        _status_matches(values[language], statuses[language], language, location, errors)
    ko_placeholders = _placeholders(values.get("ko"))
    for language in RELEASE_LANGUAGES:
        if language == "ko" or not values.get(language):
            continue
        other = _placeholders(values[language])
        if other != ko_placeholders:
            errors.append(
                DataError(
                    f"치환 변수 {_format_placeholders(other)}가 한국어 {_format_placeholders(ko_placeholders)}와 다릅니다.",
                    **location,
                    column=language,
                )
            )
    return {
        "key": _required_text(record, "Key", location, errors),
        "quizId": _identifier(record, "QuizId", location, errors, allow_common=True),
        "dataVersion": _version(record, location, errors),
        "sortOrder": _order(record, location, errors),
        "isActive": _bool(record, "IsActive", location, errors),
        "values": values,
        "statuses": statuses,
        "origins": origins,
    }


def _status_matches(value, status, language, location, errors):
    if status is None:
        return
    empty = not value
    if status == "missing" and not empty:
        errors.append(
            DataError(
                "상태는 missing인데 칸에 문구가 있습니다.",
                **location,
                column=STATUS_COLUMNS[language],
            )
        )
    if status in {"draft", "reviewed"} and empty:
        errors.append(
            DataError(
                f"상태는 {status}인데 칸이 비어 있습니다.",
                **location,
                column=language,
            )
        )


def _placeholders(value):
    if not value:
        return set()
    return set(PLACEHOLDER_PATTERN.findall(value))


def _format_placeholders(names):
    if not names:
        return "(없음)"
    return ", ".join("{" + name + "}" for name in sorted(names))


def _identifier(record, column, location, errors, allow_common=False):
    value = _required_text(record, column, location, errors)
    if value is None:
        return None
    if any(character.isspace() for character in value):
        errors.append(DataError("ID에 공백이 있습니다.", **location, column=column))
    if value == "common" and not allow_common:
        errors.append(DataError("common은 문구 범위에만 쓸 수 있습니다.", **location, column=column))
    return value


def _version(record, location, errors):
    value = _required_text(record, "DataVersion", location, errors)
    if value is None:
        return None
    if not VERSION_PATTERN.fullmatch(value):
        errors.append(
            DataError(
                "DataVersion은 major.minor.patch 형식이어야 합니다.",
                **location,
                column="DataVersion",
            )
        )
    return value


def _order(record, location, errors):
    return _whole(record, "SortOrder", location, errors, minimum=1)


def _whole(record, column, location, errors, minimum):
    value = record.get(column)
    if isinstance(value, bool) or not isinstance(value, (int, float)) or isinstance(value, float) and not value.is_integer():
        errors.append(DataError("정수가 아닙니다.", **location, column=column))
        return None
    number = int(value)
    if number < minimum:
        errors.append(DataError(f"{minimum} 이상의 정수여야 합니다.", **location, column=column))
        return None
    return number


def _bool(record, column, location, errors):
    value = record.get(column)
    if not isinstance(value, bool):
        errors.append(DataError("Excel 불리언이어야 합니다.", **location, column=column))
        return None
    return value


def _choice(record, column, allowed, location, errors):
    value = _required_text(record, column, location, errors)
    if value is None:
        return None
    if value not in allowed:
        errors.append(
            DataError(
                f"허용된 값이 아닙니다. ({', '.join(sorted(allowed))})",
                **location,
                column=column,
            )
        )
    return value


def _required_text(record, column, location, errors):
    value = _optional_text(record.get(column), column, location, errors)
    if not value:
        errors.append(DataError("값이 비어 있습니다.", **location, column=column))
        return None
    return value


def _optional_text(value, column, location, errors):
    if value is None:
        return None
    if isinstance(value, (datetime, date)) or not isinstance(value, str):
        errors.append(DataError("문자열이어야 합니다. 날짜로 바뀐 값은 쓸 수 없습니다.", **location, column=column))
        return None
    text = value.strip()
    return text or None


def _formation(record, location, errors):
    value = record.get("Formation")
    if isinstance(value, (datetime, date)):
        errors.append(
            DataError(
                "포메이션이 날짜로 바뀌었습니다. 텍스트로 저장하세요.",
                **location,
                column="Formation",
            )
        )
        return None
    return _required_text(record, "Formation", location, errors)


def _number(record, column, location, errors):
    value = record.get(column)
    if isinstance(value, bool) or not isinstance(value, (int, float)) or isinstance(value, float) and not math.isfinite(value):
        errors.append(DataError("유한한 수가 아닙니다.", **location, column=column))
        return None
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return value


def _positive_number(record, column, location, errors):
    value = _number(record, column, location, errors)
    if value is None:
        return None
    if value <= 0:
        errors.append(DataError("0보다 큰 수여야 합니다.", **location, column=column))
        return None
    return value


def _text(value):
    return value or ""


def _field_column(field):
    return {
        "titleTextKey": "TitleTextKey",
        "introTextKey": "IntroTextKey",
        "nameTextKey": "NameTextKey",
        "roleTextKey": "RoleTextKey",
        "promptTextKey": "PromptTextKey",
        "labelTextKey": "LabelTextKey",
        "shareTextKey": "ShareTextKey",
        "descriptionKey": "DescriptionKey",
        "catchphraseKey": "CatchphraseKey",
    }[field]
