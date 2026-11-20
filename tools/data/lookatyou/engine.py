"""위젯과 문구에 의존하지 않는 채점·판정.

비교는 반올림 전 유리수다. 표시값만 소수 첫째 자리 half-up이다.
문항 수, 포메이션, 결과 문구는 넣지 않는다.
"""

from decimal import Decimal, ROUND_HALF_UP
from fractions import Fraction


class QuizFailure(Exception):
    def __init__(self, code, message):
        self.code = code
        super().__init__(f"{code}: {message}")


def score_answers(quiz, answers, allow_pending=False):
    """QuestionId → OptionId 맵을 채점한다. 무효면 점수를 만들지 않는다."""
    _require_runnable(quiz, allow_pending)
    questions = _active_questions(quiz)
    missing = [item["questionId"] for item in questions if item["questionId"] not in answers]
    invalid = []
    normalized = {}
    for item in questions:
        question_id = item["questionId"]
        if question_id not in answers:
            continue
        option_id = answers[question_id]
        option = _option(quiz, item, option_id)
        if option is None:
            invalid.append(question_id)
            continue
        normalized[question_id] = option
    if invalid:
        raise QuizFailure("invalidAnswer", "선택지가 문항의 활성 척도에 없습니다.")
    if missing:
        raise QuizFailure("incomplete", "필수 문항이 비어 있습니다.")
    scores, raws = _dimension_math(quiz, questions, normalized)
    return _finish(quiz, scores, raws)


def score_integer_values(quiz, values, allow_pending=False):
    """문항 순서의 정수 응답. bool·소수·문자열은 거절한다."""
    questions = _active_questions(quiz)
    if len(values) != len(questions):
        raise QuizFailure("invalidAnswer", "응답 수가 활성 문항 수와 다릅니다.")
    answers = {}
    missing = False
    for item, value in zip(questions, values):
        if value is None:
            missing = True
            continue
        if isinstance(value, bool) or not isinstance(value, int):
            raise QuizFailure("invalidAnswer", "정수 응답만 받을 수 있습니다.")
        option = _option_for_score(quiz, item, value)
        if option is None:
            raise QuizFailure("invalidAnswer", "점수에 해당하는 활성 선택지가 없습니다.")
        answers[item["questionId"]] = option["optionId"]
    if missing:
        raise QuizFailure("incomplete", "필수 문항이 비어 있습니다.")
    return score_answers(quiz, answers, allow_pending=allow_pending)


def judge_scores(quiz, scores, allow_pending=False):
    """이미 계산된 축 점수로 판정만 한다. 값은 정수·소수 문자열·Fraction이다."""
    _require_runnable(quiz, allow_pending)
    parsed = {}
    for axis in _axes(quiz):
        if axis not in scores:
            raise QuizFailure("invalidDefinition", "필수 축 점수가 없습니다.")
        parsed[axis] = _as_fraction(scores[axis])
    return _finish(quiz, parsed, {})


def progress(quiz, answers):
    questions = _active_questions(quiz)
    missing = [item["questionId"] for item in questions if item["questionId"] not in answers]
    return {"answered": len(questions) - len(missing), "missing": missing}


def adjacent_changes(quiz, answers, allow_pending=False):
    """한 문항의 인접 점수 선택지로 결과 ID가 바뀌면 True."""
    current = score_answers(quiz, answers, allow_pending=allow_pending)
    questions = _active_questions(quiz)
    for item in questions:
        chosen = answers[item["questionId"]]
        for option_id in _neighbor_options(quiz, item, chosen):
            trial = dict(answers)
            trial[item["questionId"]] = option_id
            other = score_answers(quiz, trial, allow_pending=allow_pending)
            if other["resultTypeId"] != current["resultTypeId"]:
                return True
    return False


def load_answer_rows(rows):
    """외부 배열의 중복 QuestionId를 맵으로 바꾸기 전에 찾는다."""
    seen = set()
    answers = {}
    for row in rows:
        question_id = row.get("questionId") if isinstance(row, dict) else row[0]
        option_id = row.get("optionId") if isinstance(row, dict) else row[1]
        if question_id in seen:
            raise QuizFailure("invalidAnswer", "응답 ID가 중복입니다.")
        seen.add(question_id)
        answers[question_id] = option_id
    return answers


def _finish(quiz, scores, raws):
    rule = quiz["rule"]
    order = _rank(scores, rule["tiePriority"])
    first, second, third = order
    span = scores[first] - scores[third]
    gap = scores[first] - scores[second]
    balance = Fraction(rule["balanceMaxRange"])
    dominance = Fraction(rule["dominanceMinGap"])
    if span <= balance:
        kind = "balance"
        key = ("balance", None, None)
    elif gap >= dominance:
        kind = "dominant"
        key = ("dominant", first, None)
    else:
        kind = "mixed"
        key = ("mixed", first, second)
    mapping = None
    for item in rule["mappings"]:
        if (item["kind"], item.get("firstDimensionId"), item.get("secondDimensionId")) == key:
            mapping = item
            break
    if mapping is None:
        raise QuizFailure("invalidDefinition", "판정 키에 해당하는 매핑이 없습니다.")
    tied = [axis for axis in order if any(scores[axis] == scores[other] and axis != other for other in order)]
    return {
        "quizId": quiz["quizId"],
        "dataVersion": quiz["dataVersion"],
        "ruleVersion": rule["ruleVersion"],
        "resultTypeId": mapping["resultTypeId"],
        "dimensionScores": {axis: _ratio(scores[axis]) for axis in order},
        "displayScores": {axis: display_tenth(scores[axis]) for axis in order},
        "rawTotals": raws,
        "path": kind,
        "tiedDimensionIds": tied,
        "rank": order,
        "preview": quiz.get("resultRuleStatus") != "approved",
    }


def _dimension_math(quiz, questions, options_by_question):
    totals = {}
    weights = {}
    raws = {}
    for item in questions:
        axis = item["dimensionId"]
        scale = _scale(quiz, item["scaleId"])
        low = min(option["scoreValue"] for option in scale)
        high = max(option["scoreValue"] for option in scale)
        if high == low:
            raise QuizFailure("invalidDefinition", "척도 폭이 0입니다.")
        values = [option["scoreValue"] for option in scale]
        if len(values) != len(set(values)):
            raise QuizFailure("invalidDefinition", "ScoreValue가 중복입니다.")
        if item["dimensionId"] not in set(_axes(quiz)):
            raise QuizFailure("invalidDefinition", "문항에 규칙 밖의 축이 있습니다.")
        weight = Fraction(item["weight"])
        if weight <= 0:
            raise QuizFailure("invalidDefinition", "가중치가 0 이하입니다.")
        chosen = options_by_question[item["questionId"]]["scoreValue"]
        adjusted = (low + high - chosen) if item["reverse"] else chosen
        totals[axis] = totals.get(axis, Fraction(0)) + weight * Fraction(adjusted - low, high - low)
        weights[axis] = weights.get(axis, Fraction(0)) + weight
        raws[axis] = raws.get(axis, Fraction(0)) + weight * Fraction(adjusted)
    scores = {}
    for axis in _axes(quiz):
        if axis not in weights or weights[axis] == 0:
            raise QuizFailure("invalidDefinition", "필수 축에 문항이 없습니다.")
        scores[axis] = Fraction(100) * totals[axis] / weights[axis]
    return scores, {axis: _ratio(raws[axis]) for axis in scores}


def _require_runnable(quiz, allow_pending):
    if quiz.get("dataVersion") is None or quiz.get("quizId") is None:
        raise QuizFailure("versionMismatch", "진단 버전이 없습니다.")
    if quiz.get("scoreMode") != "independent_sum":
        raise QuizFailure("unsupportedStrategy", "지원하지 않는 채점 방식입니다.")
    rule = quiz.get("rule")
    if not rule:
        raise QuizFailure("ruleUnavailable", "이 버전에는 판정 규칙이 없습니다.")
    if rule.get("strategy") != "range_gap_rank":
        raise QuizFailure("unsupportedStrategy", "지원하지 않는 판정 전략입니다.")
    if quiz.get("resultRuleStatus") != "approved" and not allow_pending:
        raise QuizFailure("ruleUnavailable", "승인 전 규칙은 파일럿 세션에서만 실행합니다.")


def _active_questions(quiz):
    items = [item for item in quiz["questions"] if item.get("isActive") is True]
    return sorted(items, key=lambda item: (item.get("sortOrder") or 0, item["questionId"]))


def _axes(quiz):
    return list(quiz["rule"]["tiePriority"])


def _scale(quiz, scale_id):
    return [
        item for item in quiz["options"]
        if item.get("scaleId") == scale_id and item.get("isActive") is True
    ]


def _option(quiz, question, option_id):
    for item in _scale(quiz, question["scaleId"]):
        if item.get("optionId") == option_id:
            return item
    return None


def _option_for_score(quiz, question, score):
    matches = [item for item in _scale(quiz, question["scaleId"]) if item.get("scoreValue") == score]
    if len(matches) != 1:
        return None
    return matches[0]


def _neighbor_options(quiz, question, option_id):
    scale = sorted(_scale(quiz, question["scaleId"]), key=lambda item: (item["scoreValue"], item["optionId"]))
    index = next(position for position, item in enumerate(scale) if item["optionId"] == option_id)
    neighbors = []
    if index > 0:
        neighbors.append(scale[index - 1]["optionId"])
    if index + 1 < len(scale):
        neighbors.append(scale[index + 1]["optionId"])
    return neighbors


def _rank(scores, priority):
    order = {axis: index for index, axis in enumerate(priority)}
    return sorted(priority, key=lambda axis: (-scores[axis], order[axis]))


def _as_fraction(value):
    if isinstance(value, bool) or isinstance(value, float):
        raise QuizFailure("invalidAnswer", "축 점수는 정수 또는 소수 문자열이어야 합니다.")
    if isinstance(value, int):
        return Fraction(value)
    if isinstance(value, Fraction):
        return value
    if isinstance(value, str):
        return Fraction(Decimal(value))
    raise QuizFailure("invalidAnswer", "축 점수의 자료형이 올바르지 않습니다.")


def _ratio(value):
    return {"numerator": value.numerator, "denominator": value.denominator}


def display_tenth(value):
    if not isinstance(value, Fraction):
        value = Fraction(value)
    number = Decimal(value.numerator) / Decimal(value.denominator)
    text = format(number.quantize(Decimal("0.1"), rounding=ROUND_HALF_UP), "f")
    return text


class QuizSession:
    """한 QuizId·DataVersion에 고정된 응답. 언어 변경과 무관하다."""

    def __init__(self, quiz, allow_pending=False):
        self.quiz = quiz
        self.allow_pending = allow_pending
        self.answers = {}
        questions = _active_questions(quiz)
        self.position_id = questions[0]["questionId"] if questions else None

    @property
    def quiz_id(self):
        return self.quiz["quizId"]

    @property
    def data_version(self):
        return self.quiz["dataVersion"]

    def select(self, question_id, option_id):
        question = self._question(question_id)
        if _option(self.quiz, question, option_id) is None:
            raise QuizFailure("invalidAnswer", "선택지가 문항의 활성 척도에 없습니다.")
        self.answers[question_id] = option_id

    def move_to(self, question_id):
        self._question(question_id)
        self.position_id = question_id

    def import_rows(self, data_version, rows):
        if data_version != self.data_version:
            raise QuizFailure("versionMismatch", "다른 데이터 버전의 응답은 합치지 않습니다.")
        loaded = load_answer_rows(rows)
        for question_id, option_id in loaded.items():
            question = self._question(question_id)
            if _option(self.quiz, question, option_id) is None:
                raise QuizFailure("invalidAnswer", "선택지가 문항의 활성 척도에 없습니다.")
        self.answers.update(loaded)

    def complete(self):
        return score_answers(self.quiz, self.answers, allow_pending=self.allow_pending)

    def _question(self, question_id):
        for item in _active_questions(self.quiz):
            if item["questionId"] == question_id:
                return item
        raise QuizFailure("invalidAnswer", "활성 문항이 아닙니다.")
