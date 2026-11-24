import 'pilot_share_file.dart';
import 'pilot_share_link.dart';

/// 웹이 아닌 실행. 링크 공유 창은 없고 저장은 내려받은 것으로 본다.
bool canSharePilotLink(PilotShareLink link) => false;

bool canSharePilotFile() => false;

bool samsungInternetBrowser() => false;

bool kakaoTalkBrowser() => false;

Future<PilotKakaoDelivery> sendPilotKakaoShare(PilotKakaoShare message) {
  return Future.value(
    const PilotKakaoDelivery(result: PilotShareFileResult.unavailable),
  );
}

Future<PilotShareFileResult> sharePilotLink(PilotShareLink link) {
  return Future.value(PilotShareFileResult.unavailable);
}

Future<PilotShareFileResult> sharePilotResult(
  PilotShareLink link,
  PilotShareFile file,
) {
  return Future.value(PilotShareFileResult.unavailable);
}

Future<bool> copyPilotText(String text) => Future.value(false);

Future<PilotSaveFileResult> savePilotFile(PilotShareFile file) {
  return Future.value(PilotSaveFileResult.downloaded);
}
