import 'dart:convert';

/// 같은 탭에 남기는 회차 단계. 점수 캐시는 넣지 않고 응답으로 다시 계산한다.
abstract final class PilotStage {
  static const home = 'home';
  static const intro = 'intro';
  static const question = 'question';
  static const scene = 'scene';
  static const result = 'result';
  static const share = 'share';

  static const values = {home, intro, question, scene, result, share};
}

/// 진단·규칙·장면 버전과 응답 ID를 한 레코드로 둔다.
class PilotCheckpoint {
  const PilotCheckpoint({
    required this.quizId,
    required this.dataVersion,
    required this.ruleVersion,
    required this.pilotVersion,
    required this.stage,
    required this.positionId,
    required this.questions,
    required this.scenes,
  });

  final String quizId;
  final String dataVersion;
  final String ruleVersion;
  final String pilotVersion;
  final String stage;
  final String? positionId;
  final Map<String, String> questions;
  final Map<String, String> scenes;

  String encode() {
    return jsonEncode({
      'quizId': quizId,
      'dataVersion': dataVersion,
      'ruleVersion': ruleVersion,
      'pilotVersion': pilotVersion,
      'stage': stage,
      'positionId': positionId,
      'questions': questions,
      'scenes': scenes,
    });
  }

  static PilotCheckpoint? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final quizId = decoded['quizId'];
      final dataVersion = decoded['dataVersion'];
      final ruleVersion = decoded['ruleVersion'];
      final pilotVersion = decoded['pilotVersion'];
      final stage = decoded['stage'];
      final position = decoded['positionId'];
      final questions = _pairs(decoded['questions']);
      final scenes = _pairs(decoded['scenes']);
      if (quizId is! String ||
          dataVersion is! String ||
          ruleVersion is! String ||
          pilotVersion is! String ||
          stage is! String ||
          !PilotStage.values.contains(stage) ||
          (position != null && position is! String) ||
          questions == null ||
          scenes == null) {
        return null;
      }
      return PilotCheckpoint(
        quizId: quizId,
        dataVersion: dataVersion,
        ruleVersion: ruleVersion,
        pilotVersion: pilotVersion,
        stage: stage,
        positionId: position as String?,
        questions: questions,
        scenes: scenes,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, String>? _pairs(Object? value) {
    if (value is! Map) {
      return null;
    }
    final pairs = <String, String>{};
    for (final entry in value.entries) {
      if (entry.key is! String ||
          entry.value is! String ||
          (entry.key as String).isEmpty ||
          (entry.value as String).isEmpty) {
        return null;
      }
      pairs[entry.key as String] = entry.value as String;
    }
    return pairs;
  }
}
