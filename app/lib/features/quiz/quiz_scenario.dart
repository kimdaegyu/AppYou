import '../catalog/content_models.dart';
import 'quiz_engine.dart';

/// 상황 선택 집계. 전술 점수와 TiePriority에는 더하지 않는다.
class ScenarioTally {
  const ScenarioTally({
    required this.counts,
    required this.total,
    required this.kind,
    required this.leaders,
  });

  final Map<String, int> counts;
  final int total;

  /// balanced, tie, lead 중 하나. 공동 1위는 순서로 깨지 않는다.
  final String kind;
  final List<String> leaders;
}

class ScenarioSession {
  ScenarioSession.start(this.pilot)
    : answers = {},
      positionId = pilot.scenarios.first.scenarioId;

  final ScenarioPilot pilot;
  final Map<String, String> answers;
  String positionId;

  int get length => pilot.scenarios.length;

  void select(String scenarioId, String optionId) {
    final scenario = _scenario(scenarioId);
    final matches = scenario.options.where((option) => option.optionId == optionId);
    if (matches.isEmpty) {
      throw const QuizFailure('invalidAnswer', '이 장면의 선택지가 아닙니다.');
    }
    answers[scenarioId] = optionId;
  }

  void moveTo(String scenarioId) {
    _scenario(scenarioId);
    positionId = scenarioId;
  }

  ScenarioTally complete({List<String> dimensionOrder = const []}) {
    return tallyScenarioAnswers(pilot, Map<String, String>.of(answers), dimensionOrder: dimensionOrder);
  }

  ScenarioContent _scenario(String scenarioId) {
    for (final item in pilot.scenarios) {
      if (item.scenarioId == scenarioId) {
        return item;
      }
    }
    throw const QuizFailure('invalidAnswer', '활성 장면이 아닙니다.');
  }
}

Map<String, String> loadScenarioRows(List<Map<String, String>> rows) {
  final seen = <String>{};
  final loaded = <String, String>{};
  for (final row in rows) {
    final scenarioId = row['scenarioId'];
    final optionId = row['optionId'];
    if (scenarioId == null || optionId == null || scenarioId.isEmpty || optionId.isEmpty || !seen.add(scenarioId)) {
      throw const QuizFailure('invalidAnswer', '상황 응답이 중복되었거나 비어 있습니다.');
    }
    loaded[scenarioId] = optionId;
  }
  return loaded;
}

ScenarioTally tallyScenarioAnswers(
  ScenarioPilot pilot,
  Map<String, String> answers, {
  List<String> dimensionOrder = const [],
}) {
  if (pilot.scoringMode != 'axis_count' && pilot.scoringMode != 'option_points') {
    throw const QuizFailure('invalidDefinition', '지원하지 않는 상황 배점입니다.');
  }
  final order = dimensionOrder.isEmpty ? _dimensionOrder(pilot) : [...dimensionOrder];
  final counts = {for (final id in order) id: 0};
  if (answers.length != pilot.scenarios.length) {
    throw const QuizFailure('incomplete', '상황 선택이 끝나지 않았습니다.');
  }
  for (final scenario in pilot.scenarios) {
    final optionId = answers[scenario.scenarioId];
    if (optionId == null) {
      throw const QuizFailure('incomplete', '상황 선택이 끝나지 않았습니다.');
    }
    final matches = scenario.options.where((option) => option.optionId == optionId).toList();
    if (matches.length != 1) {
      throw const QuizFailure('invalidAnswer', '이 장면의 선택지가 아닙니다.');
    }
    final option = matches.single;
    if (pilot.scoringMode == 'axis_count') {
      counts.putIfAbsent(option.dimensionId, () => 0);
      if (!order.contains(option.dimensionId)) {
        order.add(option.dimensionId);
      }
      counts[option.dimensionId] = counts[option.dimensionId]! + 1;
      continue;
    }
    if (option.pointsByDimension.isEmpty) {
      throw const QuizFailure('invalidDefinition', '상황 배점이 손상되었습니다.');
    }
    for (final entry in option.pointsByDimension.entries) {
      if (entry.value < 0) {
        throw const QuizFailure('invalidDefinition', '상황 배점이 손상되었습니다.');
      }
      counts.putIfAbsent(entry.key, () => 0);
      if (!order.contains(entry.key)) {
        order.add(entry.key);
      }
      counts[entry.key] = counts[entry.key]! + entry.value;
    }
    for (final dimensionId in order) {
      if (!option.pointsByDimension.containsKey(dimensionId)) {
        throw const QuizFailure('invalidDefinition', '상황 배점이 손상되었습니다.');
      }
    }
  }
  final leaders = _leaders(counts, order);
  return ScenarioTally(
    counts: counts,
    total: counts.values.fold(0, (sum, value) => sum + value),
    kind: _kind(leaders, order),
    leaders: leaders,
  );
}

List<String> _dimensionOrder(ScenarioPilot pilot) {
  final found = <String>[];
  for (final scenario in pilot.scenarios) {
    final options = [...scenario.options]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final option in options) {
      if (!found.contains(option.dimensionId)) {
        found.add(option.dimensionId);
      }
    }
  }
  return found;
}

List<String> _leaders(Map<String, int> counts, List<String> order) {
  if (order.isEmpty) {
    return const [];
  }
  final top = order.map((id) => counts[id] ?? 0).reduce((a, b) => a > b ? a : b);
  return [for (final id in order) if ((counts[id] ?? 0) == top) id];
}

String _kind(List<String> leaders, List<String> order) {
  if (order.length > 1 && leaders.length == order.length) {
    return 'balanced';
  }
  if (leaders.length > 1) {
    return 'tie';
  }
  return 'lead';
}
