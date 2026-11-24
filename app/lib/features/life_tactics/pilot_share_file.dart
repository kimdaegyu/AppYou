import 'dart:typed_data';

/// 공유와 저장이 함께 쓰는 PNG 한 장.
class PilotShareFile {
  const PilotShareFile({
    required this.bytes,
    required this.filename,
    required this.saveHint,
    required this.closeLabel,
  });

  final Uint8List bytes;
  final String filename;
  final String saveHint;
  final String closeLabel;

  /// 예: look-at-you_life-tactics_tr01_ko.png
  static String filenameFor({
    required String resultTypeId,
    required String languageCode,
  }) {
    return 'look-at-you_life-tactics_${resultTypeId}_$languageCode.png';
  }
}

/// 운영체제 공유창을 연 결과. 창이 열렸다는 뜻이지 전송 완료가 아니다.
///
/// [needsGesture]는 이미지 업로드는 끝났지만, 비동기 작업 뒤에 공유창이
/// 막혀 다음 탭에서 바로 열어야 하는 상태다.
enum PilotShareFileResult { opened, cancelled, unavailable, failed, needsGesture }

/// 저장이 파일을 내려받았는지, 브라우저가 이미지를 열었는지.
enum PilotSaveFileResult { downloaded, opened, failed }

/// 카카오톡 인앱 브라우저. 시스템 공유가 없으면 카카오 공유를 쓴다.
bool pilotKakaoTalkAgent(String userAgent) {
  return userAgent.toLowerCase().contains('kakaotalk');
}

/// iOS와 터치 기반 iPad는 이미지를 새 화면에서 여는 경우가 있다.
bool pilotImageOpensForSaving(String userAgent, {int maxTouchPoints = 0}) {
  final agent = userAgent.toLowerCase();
  if ((agent.contains('android') &&
          (agent.contains('kakaotalk') || agent.contains('; wv'))) ||
      agent.contains('iphone') ||
      agent.contains('ipad') ||
      agent.contains('ipod')) {
    return true;
  }
  return agent.contains('macintosh') && maxTouchPoints > 1;
}
