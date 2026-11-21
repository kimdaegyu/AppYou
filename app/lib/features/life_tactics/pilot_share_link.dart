/// 친구가 같은 진단을 시작하는 공개 주소. 로컬 실행에서도 이 주소를 공유한다.
const pilotPublicSite = 'https://lookatyou.dcstudio.workers.dev';

/// 공유창에 넘기는 진단 링크와 문구. 파일은 포함하지 않는다.
class PilotShareLink {
  const PilotShareLink({required this.url, required this.text});

  final Uri url;
  final String text;
}

/// 카카오톡 기본 텍스트 템플릿. 본문은 결과명이고 버튼은 진단 링크다.
class PilotKakaoShare {
  const PilotKakaoShare({
    required this.text,
    required this.buttonTitle,
    required this.webUrl,
    required this.mobileWebUrl,
  });

  final String text;
  final String buttonTitle;
  final Uri webUrl;
  final Uri mobileWebUrl;
}

/// 시스템 공유가 없을 때만 카카오톡 인앱 버튼을 쓴다.
bool pilotUsesKakaoShare({required bool systemShare, required bool kakaoTalk}) {
  return kakaoTalk && !systemShare;
}

/// `quizId`만 붙인다. 응답, 점수, 결과 타입은 주소에 넣지 않는다.
Uri pilotDiagnosisLink(String quizId) {
  final origin = Uri.parse(pilotPublicSite);
  return origin.replace(
    path: origin.path.isEmpty ? '/' : origin.path,
    queryParameters: {'quizId': quizId},
  );
}
