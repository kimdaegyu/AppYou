import '../catalog/content_models.dart';
import 'quiz_ratio.dart';

class QuizFailure implements Exception {
  const QuizFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

class QuizOutcome {
  const QuizOutcome({
    required this.quizId,
    required this.dataVersion,
    required this.ruleVersion,
    required this.resultTypeId,
    required this.dimensionScores,
    required this.displayScores,
    required this.rawTotals,
    required this.path,
    required this.tiedDimensionIds,
    required this.rank,
    required this.preview,
    required this.adjacentChanges,
  });

  final String quizId;
  final String dataVersion;
  final String ruleVersion;
  final String resultTypeId;
  final Map<String, QuizRatio> dimensionScores;
  final Map<String, String> displayScores;
  final Map<String, QuizRatio> rawTotals;
  final String path;
  final List<String> tiedDimensionIds;
  final List<String> rank;
  final bool preview;
  final bool adjacentChanges;
}

QuizOutcome scoreAnswers(
  QuizContent quiz,
  Map<String, String> answers, {
  bool allowPending = false,
  bool detectBoundary = false,
}) {
  _requireRunnable(quiz, allowPending);
  final questions = activeQuestions(quiz);
  final missing = [
    for (final question in questions)
      if (!answers.containsKey(question.questionId)) question.questionId,
  ];
  final invalid = <String>[];
  final chosen = <String, OptionContent>{};
  for (final question in questions) {
    final optionId = answers[question.questionId];
    if (optionId == null) {
      continue;
    }
    final option = _option(quiz, question, optionId);
    if (option == null) {
      invalid.add(question.questionId);
    } else {
      chosen[question.questionId] = option;
    }
  }
  if (invalid.isNotEmpty) {
    throw const QuizFailure('invalidAnswer', '선택지가 문항의 활성 척도에 없습니다.');
  }
  if (missing.isNotEmpty) {
    throw const QuizFailure('incomplete', '필수 문항이 비어 있습니다.');
  }
  final math = _dimensionMath(quiz, questions, chosen);
  final outcome = _finish(quiz, math.scores, math.raws, adjacentChanges: false);
  if (!detectBoundary) {
    return outcome;
  }
  return QuizOutcome(
    quizId: outcome.quizId,
    dataVersion: outcome.dataVersion,
    ruleVersion: outcome.ruleVersion,
    resultTypeId: outcome.resultTypeId,
    dimensionScores: outcome.dimensionScores,
    displayScores: outcome.displayScores,
    rawTotals: outcome.rawTotals,
    path: outcome.path,
    tiedDimensionIds: outcome.tiedDimensionIds,
    rank: outcome.rank,
    preview: outcome.preview,
    adjacentChanges: _adjacentChanges(quiz, answers, outcome.resultTypeId),
  );
}

QuizOutcome scoreIntegerValues(
  QuizContent quiz,
  List<Object?> values, {
  bool allowPending = false,
}) {
  final questions = activeQuestions(quiz);
  if (values.length != questions.length) {
    throw const QuizFailure('invalidAnswer', '응답 수가 활성 문항 수와 다릅니다.');
  }
  final answers = <String, String>{};
  var missing = false;
  for (var index = 0; index < questions.length; index++) {
    final value = values[index];
    if (value == null) {
      missing = true;
      continue;
    }
    if (value is! int) {
      throw const QuizFailure('invalidAnswer', '정수 응답만 받을 수 있습니다.');
    }
    final option = _optionForScore(quiz, questions[index], value);
    if (option == null) {
      throw const QuizFailure('invalidAnswer', '점수에 해당하는 활성 선택지가 없습니다.');
    }
    answers[questions[index].questionId] = option.optionId;
  }
  if (missing) {
    throw const QuizFailure('incomplete', '필수 문항이 비어 있습니다.');
  }
  return scoreAnswers(quiz, answers, allowPending: allowPending);
}

QuizOutcome judgeScores(
  QuizContent quiz,
  Map<String, String> scores, {
  bool allowPending = false,
}) {
  _requireRunnable(quiz, allowPending);
  final rule = quiz.rule!;
  final parsed = <String, QuizRatio>{};
  for (final axis in rule.tiePriority) {
    final value = scores[axis];
    if (value == null) {
      throw const QuizFailure('invalidDefinition', '필수 축 점수가 없습니다.');
    }
    try {
      parsed[axis] = QuizRatio.decimal(value);
    } on FormatException {
      throw const QuizFailure('invalidAnswer', '축 점수의 자료형이 올바르지 않습니다.');
    }
  }
  return _finish(quiz, parsed, const {}, adjacentChanges: false);
}

Map<String, String> loadAnswerRows(List<Map<String, String>> rows) {
  final answers = <String, String>{};
  for (final row in rows) {
    final questionId = row['questionId'];
    final optionId = row['optionId'];
    if (questionId == null || optionId == null) {
      throw const QuizFailure('invalidAnswer', '응답 ID가 없습니다.');
    }
    if (answers.containsKey(questionId)) {
      throw const QuizFailure('invalidAnswer', '응답 ID가 중복입니다.');
    }
    answers[questionId] = optionId;
  }
  return answers;
}

List<QuestionContent> activeQuestions(QuizContent quiz) {
  final items = [for (final item in quiz.questions) if (item.isActive) item];
  items.sort((a, b) {
    final order = a.sortOrder.compareTo(b.sortOrder);
    return order == 0 ? a.questionId.compareTo(b.questionId) : order;
  });
  return items;
}

class _Math {
  const _Math(this.scores, this.raws);

  final Map<String, QuizRatio> scores;
  final Map<String, QuizRatio> raws;
}

_Math _dimensionMath(
  QuizContent quiz,
  List<QuestionContent> questions,
  Map<String, OptionContent> chosen,
) {
  final axes = quiz.rule!.tiePriority.toSet();
  final totals = <String, QuizRatio>{};
  final weights = <String, QuizRatio>{};
  final raws = <String, QuizRatio>{};
  for (final question in questions) {
    if (!axes.contains(question.dimensionId)) {
      throw const QuizFailure('invalidDefinition', '문항에 규칙 밖의 축이 있습니다.');
    }
    final scale = _scale(quiz, question.scaleId);
    final values = [for (final option in scale) _exact(option.scoreValue)];
    if (values.toSet().length != values.length) {
      throw const QuizFailure('invalidDefinition', 'ScoreValue가 중복입니다.');
    }
    final low = values.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
    final high = values.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    if (high == low) {
      throw const QuizFailure('invalidDefinition', '척도 폭이 0입니다.');
    }
    final weight = _exact(question.weight);
    if (weight <= QuizRatio.integer(0)) {
      throw const QuizFailure('invalidDefinition', '가중치가 0 이하입니다.');
    }
    final score = _exact(chosen[question.questionId]!.scoreValue);
    final adjusted = question.reverse ? (low + high - score) : score;
    final axis = question.dimensionId;
    final zero = QuizRatio.integer(0);
    totals[axis] = (totals[axis] ?? zero) + weight * ((adjusted - low) / (high - low));
    weights[axis] = (weights[axis] ?? zero) + weight;
    raws[axis] = (raws[axis] ?? zero) + weight * adjusted;
  }
  final scores = <String, QuizRatio>{};
  for (final axis in quiz.rule!.tiePriority) {
    final weight = weights[axis];
    if (weight == null || weight == QuizRatio.integer(0)) {
      throw const QuizFailure('invalidDefinition', '필수 축에 문항이 없습니다.');
    }
    scores[axis] = QuizRatio.integer(100) * totals[axis]! / weight;
  }
  return _Math(scores, {for (final axis in scores.keys) axis: raws[axis]!});
}

QuizOutcome _finish(
  QuizContent quiz,
  Map<String, QuizRatio> scores,
  Map<String, QuizRatio> raws, {
  required bool adjacentChanges,
}) {
  final rule = quiz.rule!;
  final order = _rank(scores, rule.tiePriority);
  final first = order[0];
  final second = order[1];
  final third = order[2];
  final balance = QuizRatio.decimal(rule.balanceMaxRange);
  final dominance = QuizRatio.decimal(rule.dominanceMinGap);
  final String kind;
  final String? keyFirst;
  final String? keySecond;
  if ((scores[first]! - scores[third]!) <= balance) {
    kind = 'balance';
    keyFirst = null;
    keySecond = null;
  } else if ((scores[first]! - scores[second]!) >= dominance) {
    kind = 'dominant';
    keyFirst = first;
    keySecond = null;
  } else {
    kind = 'mixed';
    keyFirst = first;
    keySecond = second;
  }
  RuleMapping? mapping;
  for (final item in rule.mappings) {
    if (item.kind == kind && item.firstDimensionId == keyFirst && item.secondDimensionId == keySecond) {
      mapping = item;
      break;
    }
  }
  if (mapping == null) {
    throw const QuizFailure('invalidDefinition', '판정 키에 해당하는 매핑이 없습니다.');
  }
  final tied = [
    for (final axis in order)
      if (order.any((other) => other != axis && scores[axis] == scores[other])) axis,
  ];
  return QuizOutcome(
    quizId: quiz.quizId,
    dataVersion: quiz.dataVersion,
    ruleVersion: rule.ruleVersion,
    resultTypeId: mapping.resultTypeId,
    dimensionScores: {for (final axis in order) axis: scores[axis]!},
    displayScores: {for (final axis in order) axis: scores[axis]!.tenths},
    rawTotals: raws,
    path: kind,
    tiedDimensionIds: tied,
    rank: order,
    preview: quiz.resultRuleStatus != 'approved',
    adjacentChanges: adjacentChanges,
  );
}

bool _adjacentChanges(
  QuizContent quiz,
  Map<String, String> answers,
  String resultTypeId,
) {
  for (final question in activeQuestions(quiz)) {
    for (final optionId in _neighbors(quiz, question, answers[question.questionId]!)) {
      final trial = Map<String, String>.of(answers);
      trial[question.questionId] = optionId;
      final other = scoreAnswers(quiz, trial, allowPending: true);
      if (other.resultTypeId != resultTypeId) {
        return true;
      }
    }
  }
  return false;
}

void _requireRunnable(QuizContent quiz, bool allowPending) {
  if (quiz.scoreMode != 'independent_sum') {
    throw const QuizFailure('unsupportedStrategy', '지원하지 않는 채점 방식입니다.');
  }
  final rule = quiz.rule;
  if (rule == null) {
    throw const QuizFailure('ruleUnavailable', '이 버전에는 판정 규칙이 없습니다.');
  }
  if (rule.strategy != 'range_gap_rank') {
    throw const QuizFailure('unsupportedStrategy', '지원하지 않는 판정 전략입니다.');
  }
  if (quiz.resultRuleStatus != 'approved' && !allowPending) {
    throw const QuizFailure('ruleUnavailable', '승인 전 규칙은 파일럿 세션에서만 실행합니다.');
  }
  if (rule.tiePriority.length < 3) {
    throw const QuizFailure('invalidDefinition', '판정에는 세 축이 필요합니다.');
  }
}

List<OptionContent> _scale(QuizContent quiz, String scaleId) {
  return [
    for (final option in quiz.options)
      if (option.scaleId == scaleId && option.isActive) option,
  ];
}

OptionContent? _option(QuizContent quiz, QuestionContent question, String optionId) {
  for (final option in _scale(quiz, question.scaleId)) {
    if (option.optionId == optionId) {
      return option;
    }
  }
  return null;
}

OptionContent? _optionForScore(QuizContent quiz, QuestionContent question, int score) {
  final matches = [
    for (final option in _scale(quiz, question.scaleId))
      if (option.scoreValue == score) option,
  ];
  if (matches.length != 1) {
    return null;
  }
  return matches.single;
}

List<String> _neighbors(QuizContent quiz, QuestionContent question, String optionId) {
  final scale = _scale(quiz, question.scaleId)
    ..sort((a, b) {
      final value = a.scoreValue.compareTo(b.scoreValue);
      return value == 0 ? a.optionId.compareTo(b.optionId) : value;
    });
  final index = scale.indexWhere((option) => option.optionId == optionId);
  final neighbors = <String>[];
  if (index > 0) {
    neighbors.add(scale[index - 1].optionId);
  }
  if (index + 1 < scale.length) {
    neighbors.add(scale[index + 1].optionId);
  }
  return neighbors;
}

List<String> _rank(Map<String, QuizRatio> scores, List<String> priority) {
  final order = {for (var index = 0; index < priority.length; index++) priority[index]: index};
  final ranked = [...priority];
  ranked.sort((a, b) {
    final value = scores[b]!.compareTo(scores[a]!);
    return value == 0 ? order[a]!.compareTo(order[b]!) : value;
  });
  return ranked;
}

QuizRatio _exact(num value) {
  if (value is int) {
    return QuizRatio.integer(value);
  }
  throw const QuizFailure('invalidDefinition', '정수로 저장된 수치만 계산합니다.');
}
