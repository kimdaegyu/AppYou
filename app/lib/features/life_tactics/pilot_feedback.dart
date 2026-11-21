import '../quiz/quiz_engine.dart';
import 'pilot_external_link.dart';

/// 결과 피드백 설문. 주소는 한곳이고, 쿼리는 화면에 나온 결과의 세 값만 담는다.
abstract final class PilotFeedback {
  static const endpoint = 'https://tally.so/r/kbN9YR';

  static Uri uriFor(QuizOutcome outcome) {
    return Uri.parse(endpoint).replace(
      queryParameters: {
        'quiz_id': outcome.quizId,
        'data_version': outcome.dataVersion,
        'result_type_id': outcome.resultTypeId,
      },
    );
  }
}

/// 테스트가 실제 탭 대신 호출을 기록할 수 있게 둔다. 화면을 그리는 동안에는 호출하지 않는다.
bool Function(Uri uri) pilotOpenExternalLink = openPilotExternalLink;
