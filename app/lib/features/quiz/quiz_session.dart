import '../catalog/content_models.dart';
import 'quiz_engine.dart';

/// 한 진단 버전에 고정된 응답. 언어나 화면 크기와 함께 초기화하지 않는다.
class QuizSession {
  QuizSession.start(this.quiz, {this.allowPending = false})
    : answers = {},
      positionId = activeQuestions(quiz).first.questionId;

  final QuizContent quiz;
  final bool allowPending;
  final Map<String, String> answers;
  String positionId;

  String get quizId => quiz.quizId;

  String get dataVersion => quiz.dataVersion;

  int get answeredCount => activeQuestions(quiz).where((item) => answers.containsKey(item.questionId)).length;

  List<String> get missingIds => [
    for (final item in activeQuestions(quiz))
      if (!answers.containsKey(item.questionId)) item.questionId,
  ];

  void select(String questionId, String optionId) {
    final question = _question(questionId);
    final matches = quiz.options.where(
      (option) => option.optionId == optionId && option.scaleId == question.scaleId && option.isActive,
    );
    if (matches.isEmpty) {
      throw const QuizFailure('invalidAnswer', '선택지가 문항의 활성 척도에 없습니다.');
    }
    answers[questionId] = optionId;
  }

  void moveTo(String questionId) {
    _question(questionId);
    positionId = questionId;
  }

  void importRows(String dataVersion, List<Map<String, String>> rows) {
    if (dataVersion != this.dataVersion) {
      throw const QuizFailure('versionMismatch', '다른 데이터 버전의 응답은 합치지 않습니다.');
    }
    final loaded = loadAnswerRows(rows);
    for (final entry in loaded.entries) {
      final question = _question(entry.key);
      final matches = quiz.options.where(
        (option) => option.optionId == entry.value && option.scaleId == question.scaleId && option.isActive,
      );
      if (matches.isEmpty) {
        throw const QuizFailure('invalidAnswer', '선택지가 문항의 활성 척도에 없습니다.');
      }
    }
    answers
      ..clear()
      ..addAll(loaded);
  }

  QuizOutcome complete() {
    return scoreAnswers(
      quiz,
      Map<String, String>.of(answers),
      allowPending: allowPending,
      detectBoundary: true,
    );
  }

  QuestionContent _question(String questionId) {
    for (final item in activeQuestions(quiz)) {
      if (item.questionId == questionId) {
        return item;
      }
    }
    throw const QuizFailure('invalidAnswer', '활성 문항이 아닙니다.');
  }
}
