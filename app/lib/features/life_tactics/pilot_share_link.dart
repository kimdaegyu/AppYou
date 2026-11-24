import 'dart:typed_data';

import 'pilot_share_file.dart';

/// 친구가 같은 진단을 시작하는 공개 주소. 로컬 실행에서도 이 주소를 공유한다.
const pilotPublicSite = 'https://lookatyou.dcstudio.workers.dev';

/// 공유창에 넘기는 진단 링크와 문구.
class PilotShareLink {
  const PilotShareLink({required this.url, required this.text});

  final Uri url;
  final String text;
}

/// 진단명과 결과명을 피드 제목과 파일 공유 문구로 쓴다.
String pilotResultTitle({
  required String quizTitle,
  required String resultName,
}) {
  return '$quizTitle - $resultName';
}

/// 카카오에 올라간 카드 이미지. 같은 카드의 재시도는 이 주소를 다시 쓴다.
class PilotKakaoImage {
  const PilotKakaoImage({
    required this.url,
    required this.width,
    required this.height,
  });

  final String url;
  final int width;
  final int height;
}

/// 카카오톡 피드. 이미지가 있으면 업로드하고, 주소가 있으면 그 이미지를 다시 쓴다.
class PilotKakaoShare {
  const PilotKakaoShare({
    required this.title,
    required this.buttonTitle,
    required this.webUrl,
    required this.mobileWebUrl,
    required this.imageWidth,
    required this.imageHeight,
    this.imageBytes,
    this.imageUrl,
    this.filename = 'look-at-you.png',
  });

  final String title;
  final String buttonTitle;
  final Uri webUrl;
  final Uri mobileWebUrl;
  final Uint8List? imageBytes;
  final int imageWidth;
  final int imageHeight;
  final String? imageUrl;
  final String filename;
}

/// 업로드와 피드 전송의 결과. 이미지는 전송이 막혀도 유지한다.
class PilotKakaoDelivery {
  const PilotKakaoDelivery({required this.result, this.image});

  final PilotShareFileResult result;
  final PilotKakaoImage? image;
}

/// `sendDefault` 피드에 넣는 값. 설명과 응답, 점수는 넣지 않는다.
Map<String, Object?> pilotKakaoFeedSettings(PilotKakaoShare message) {
  final imageUrl = message.imageUrl;
  if (imageUrl == null || imageUrl.isEmpty) {
    throw ArgumentError.value(
      imageUrl,
      'imageUrl',
      'uploaded image is required',
    );
  }
  final link = {
    'webUrl': message.webUrl.toString(),
    'mobileWebUrl': message.mobileWebUrl.toString(),
  };
  return {
    'objectType': 'feed',
    'content': {
      'title': message.title,
      'imageUrl': imageUrl,
      if (message.imageWidth > 0) 'imageWidth': message.imageWidth,
      if (message.imageHeight > 0) 'imageHeight': message.imageHeight,
      'link': link,
    },
    'buttons': [
      {
        'title': message.buttonTitle,
        'link': {
          'webUrl': message.webUrl.toString(),
          'mobileWebUrl': message.mobileWebUrl.toString(),
        },
      },
    ],
  };
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
