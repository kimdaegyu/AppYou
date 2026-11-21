import '../catalog/content_models.dart';

/// 주소의 `quizId`. 비어 있으면 일반 홈 순서다.
String? Function() pilotHomeQuizId = _quizIdFromUri;

String? _quizIdFromUri() {
  final value = Uri.base.queryParameters['quizId'];
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

/// SortOrder 오름차순. 카탈로그에 있는 ID만 맨 앞으로 옮기고 원본 순서는 유지한다.
List<QuizContent> orderedHomeQuizzes(
  List<QuizContent> quizzes,
  String? requestedId,
) {
  final items = [...quizzes]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  if (requestedId == null || requestedId.isEmpty) {
    return items;
  }
  final index = items.indexWhere((item) => item.quizId == requestedId);
  if (index <= 0) {
    return items;
  }
  items.insert(0, items.removeAt(index));
  return items;
}
