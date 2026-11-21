import 'pilot_share_action.dart';
import 'pilot_share_file.dart';
import 'pilot_share_link.dart';

/// 테스트가 브라우저 공유를 대신한다. 클릭 안에서 곧바로 호출해야 한다.
bool Function(PilotShareLink link) pilotCanShareLink = canSharePilotLink;

bool Function() pilotKakaoTalkBrowser = kakaoTalkBrowser;

Future<PilotShareFileResult> Function(PilotShareLink link) pilotShareLink =
    sharePilotLink;

Future<PilotShareFileResult> Function(PilotKakaoShare message) pilotSendKakao =
    sendPilotKakaoShare;

Future<bool> Function(String text) pilotCopyText = copyPilotText;

Future<PilotSaveFileResult> Function(PilotShareFile file) pilotSaveFile =
    savePilotFile;
