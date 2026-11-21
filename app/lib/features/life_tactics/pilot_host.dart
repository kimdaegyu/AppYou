import 'package:flutter/foundation.dart';

import '../catalog/content_models.dart';
import '../quiz/quiz_engine.dart';
import '../quiz/quiz_scenario.dart';
import '../quiz/quiz_session.dart';
import 'pilot_checkpoint.dart';
import 'pilot_session_store_memory.dart';

/// 한 회차의 문항·장면·결과. 언어 위젯과 경로가 다시 만들어져도 이 객체가 답을 가진다.
class PilotHost extends ChangeNotifier {
  PilotSessionStore store = MemoryPilotSessionStore();
  ContentBundle? bundle;
  QuizSession? questions;
  ScenarioSession? scenes;
  QuizOutcome? outcome;
  ScenarioTally? tally;
  String? failure;
  String stage = PilotStage.home;

  /// 복원 경로를 올리기 전에는 빈 홈이 저장을 덮지 않는다.
  var hold = true;

  void bind(ContentBundle value) {
    bundle = value;
  }

  void releaseHold() {
    hold = false;
  }

  QuizContent? get quiz => bundle?.quiz('life_tactics');

  ScenarioPilot? get pilot => bundle?.pilot('life_tactics');

  bool get canPlay {
    final item = quiz;
    return item != null && item.rule != null && pilot != null;
  }

  List<QuestionContent> get questionItems => activeQuestions(quiz!);

  List<ScenarioContent> get sceneItems {
    final items = [...pilot!.scenarios];
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  List<String> get axisOrder {
    final items = [...quiz!.dimensions];
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return [
      for (final item in items)
        if (item.isActive) item.dimensionId,
    ];
  }

  int get questionIndex {
    final session = questions;
    if (session == null) {
      return 0;
    }
    final index = questionItems.indexWhere(
      (item) => item.questionId == session.positionId,
    );
    return index < 0 ? 0 : index;
  }

  int get sceneIndex {
    final session = scenes;
    if (session == null) {
      return 0;
    }
    final index = sceneItems.indexWhere(
      (item) => item.scenarioId == session.positionId,
    );
    return index < 0 ? 0 : index;
  }

  bool ensureQuestions() {
    if (!canPlay) {
      failure = 'unavailable';
      notifyListeners();
      return false;
    }
    questions ??= QuizSession.start(quiz!, allowPending: true);
    failure = null;
    return true;
  }

  void ensureScenes() {
    if (scenes != null) {
      return;
    }
    scenes = ScenarioSession.start(pilot!);
    final first = sceneItems.first.scenarioId;
    if (scenes!.positionId != first) {
      scenes!.moveTo(first);
    }
  }

  void focusQuestion(int index, {bool notify = true}) {
    final session = questions;
    if (session == null) {
      return;
    }
    final id = questionItems[index].questionId;
    if (session.positionId == id) {
      return;
    }
    session.moveTo(id);
    if (notify) {
      notifyListeners();
    }
  }

  void focusScene(int index, {bool notify = true}) {
    final session = scenes;
    if (session == null) {
      return;
    }
    final id = sceneItems[index].scenarioId;
    if (session.positionId == id) {
      return;
    }
    session.moveTo(id);
    if (notify) {
      notifyListeners();
    }
  }

  bool questionAnswered(int index) {
    final session = questions;
    if (session == null) {
      return false;
    }
    return session.answers.containsKey(questionItems[index].questionId);
  }

  bool sceneAnswered(int index) {
    final session = scenes;
    if (session == null) {
      return false;
    }
    return session.answers.containsKey(sceneItems[index].scenarioId);
  }

  String? questionSelection(int index) {
    return questions?.answers[questionItems[index].questionId];
  }

  String? sceneSelection(int index) {
    return scenes?.answers[sceneItems[index].scenarioId];
  }

  void selectQuestion(int index, String optionId) {
    questions!.select(questionItems[index].questionId, optionId);
    outcome = null;
    tally = null;
    failure = null;
    _save();
    notifyListeners();
  }

  void selectScene(int index, String optionId) {
    scenes!.select(sceneItems[index].scenarioId, optionId);
    outcome = null;
    tally = null;
    failure = null;
    _save();
    notifyListeners();
  }

  /// 현재 화면이 맨 앞일 때만 호출한다. 경로를 쌓는 동안에는 [hold]로 막는다.
  void notePlace(String stage, {int? questionIndex, int? sceneIndex}) {
    if (hold) {
      return;
    }
    this.stage = stage;
    if (questionIndex != null) {
      focusQuestion(questionIndex, notify: false);
    }
    if (sceneIndex != null) {
      focusScene(sceneIndex, notify: false);
    }
    _save();
  }

  /// 홈으로 나간 기록은 답을 남기지 않아, 새로고침 뒤에도 홈에 머문다.
  void goHome() {
    stage = PilotStage.home;
    _save();
    notifyListeners();
  }

  void reportFailure(String message) {
    failure = message;
    notifyListeners();
  }

  /// 18문항과 6장면이 모두 있을 때만 결과를 만든다. 타입을 찾지 못하면 비운다.
  void finish() {
    final scored = questions!.complete();
    final counted = scenes!.complete(dimensionOrder: axisOrder);
    final known = quiz!.resultTypes.any(
      (item) => item.resultTypeId == scored.resultTypeId,
    );
    if (!known) {
      outcome = null;
      tally = null;
      failure = 'unavailable';
      notifyListeners();
      throw const QuizFailure('invalidDefinition', '결과 타입을 찾지 못했습니다.');
    }
    outcome = scored;
    tally = counted;
    failure = null;
    notifyListeners();
  }

  /// 저장된 응답이 이 번들과 맞을 때만 적용한다. 점수는 응답으로 다시 계산한다.
  bool restore(String? raw) {
    hold = true;
    if (raw == null || raw.isEmpty) {
      return false;
    }
    final checkpoint = PilotCheckpoint.tryParse(raw);
    if (checkpoint == null || !_matches(checkpoint)) {
      return false;
    }
    try {
      _apply(checkpoint);
    } on QuizFailure {
      questions = null;
      scenes = null;
      outcome = null;
      tally = null;
      failure = null;
      stage = PilotStage.home;
      return false;
    }
    return true;
  }

  /// 다시 하기. 답과 장면, 캐시된 결과를 함께 지우고 다음 시작은 새 회차다.
  void reset() {
    questions = null;
    scenes = null;
    outcome = null;
    tally = null;
    failure = null;
    stage = PilotStage.home;
    _save();
    notifyListeners();
  }

  bool _matches(PilotCheckpoint checkpoint) {
    final item = quiz;
    final pilotItem = pilot;
    final rule = item?.rule;
    if (item == null || pilotItem == null || rule == null) {
      return false;
    }
    return checkpoint.quizId == item.quizId &&
        checkpoint.dataVersion == item.dataVersion &&
        checkpoint.ruleVersion == rule.ruleVersion &&
        checkpoint.pilotVersion == pilotItem.pilotVersion;
  }

  void _apply(PilotCheckpoint checkpoint) {
    questions = null;
    scenes = null;
    outcome = null;
    tally = null;
    failure = null;
    stage = checkpoint.stage;
    if (checkpoint.stage == PilotStage.home) {
      return;
    }
    final needsQuestions =
        checkpoint.questions.isNotEmpty ||
        checkpoint.stage == PilotStage.question ||
        checkpoint.stage == PilotStage.scene ||
        checkpoint.stage == PilotStage.result ||
        checkpoint.stage == PilotStage.share;
    if (needsQuestions) {
      _loadQuestions(checkpoint.questions);
      if (checkpoint.stage == PilotStage.intro &&
          checkpoint.positionId != null) {
        questions!.moveTo(checkpoint.positionId!);
      }
    }
    if (checkpoint.scenes.isNotEmpty ||
        checkpoint.stage == PilotStage.scene ||
        checkpoint.stage == PilotStage.result ||
        checkpoint.stage == PilotStage.share) {
      _loadScenes(checkpoint.scenes);
    }
    switch (checkpoint.stage) {
      case PilotStage.intro:
        return;
      case PilotStage.question:
        final position = checkpoint.positionId;
        if (questions == null || position == null) {
          throw const QuizFailure('invalidAnswer', '문항 위치가 없습니다.');
        }
        questions!.moveTo(position);
        return;
      case PilotStage.scene:
        final position = checkpoint.positionId;
        if (questions == null ||
            questions!.missingIds.isNotEmpty ||
            scenes == null ||
            position == null) {
          throw const QuizFailure('incomplete', '장면으로 돌아갈 응답이 없습니다.');
        }
        scenes!.moveTo(position);
        return;
      case PilotStage.result:
      case PilotStage.share:
        if (questions == null ||
            questions!.missingIds.isNotEmpty ||
            scenes == null) {
          throw const QuizFailure('incomplete', '결과를 다시 계산할 응답이 없습니다.');
        }
        finish();
        return;
      default:
        throw const QuizFailure('invalidAnswer', '알 수 없는 단계입니다.');
    }
  }

  void _loadQuestions(Map<String, String> answers) {
    questions = QuizSession.start(quiz!, allowPending: true);
    for (final entry in answers.entries) {
      questions!.select(entry.key, entry.value);
    }
  }

  void _loadScenes(Map<String, String> answers) {
    scenes = ScenarioSession.start(pilot!);
    final first = sceneItems.first.scenarioId;
    if (scenes!.positionId != first) {
      scenes!.moveTo(first);
    }
    for (final entry in answers.entries) {
      scenes!.select(entry.key, entry.value);
    }
  }

  void _save() {
    if (hold) {
      return;
    }
    final item = quiz;
    final pilotItem = pilot;
    final rule = item?.rule;
    if (item == null || pilotItem == null || rule == null) {
      return;
    }
    final atHome = stage == PilotStage.home;
    try {
      store.write(
        PilotCheckpoint(
          quizId: item.quizId,
          dataVersion: item.dataVersion,
          ruleVersion: rule.ruleVersion,
          pilotVersion: pilotItem.pilotVersion,
          stage: stage,
          positionId: _positionId(),
          questions: atHome
              ? const {}
              : Map<String, String>.from(questions?.answers ?? const {}),
          scenes: atHome
              ? const {}
              : Map<String, String>.from(scenes?.answers ?? const {}),
        ).encode(),
      );
    } catch (_) {}
  }

  String? _positionId() {
    if (stage == PilotStage.question || stage == PilotStage.intro) {
      return questions?.positionId;
    }
    if (stage == PilotStage.scene) {
      return scenes?.positionId;
    }
    return null;
  }
}
