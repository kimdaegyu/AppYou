import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../core/theme/app_colors.dart';

/// 카카오 이미지 업로드 한도. 넘으면 업로드하지 않는다.
const pilotKakaoImageByteLimit = 5 * 1024 * 1024;

/// 카카오 피드가 잘라 먹지 않고 보여주는 가로/세로 범위.
///
/// 사용자 정의 템플릿의 이미지 한도는 가장 넓은 2:1, 가장 높은 3:4다.
/// 기본 피드도 그 밖은 가운데를 자른다.
const pilotKakaoFeedWidest = 2.0;
const pilotKakaoFeedTallest = 3 / 4;

/// 업로드할 카드. 비율 안이면 원본이고, 밖이면 같은 카드를 가운데 둔 캔버스다.
class PilotKakaoFeedImage {
  const PilotKakaoFeedImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

/// PNG 헤더의 픽셀 크기. PNG가 아니면 null이다.
({int width, int height})? pngDimensions(Uint8List bytes) {
  if (bytes.length < 24) {
    return null;
  }
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var index = 0; index < signature.length; index++) {
    if (bytes[index] != signature[index]) {
      return null;
    }
  }
  final data = ByteData.sublistView(bytes);
  if (data.getUint32(12) != 0x49484452) {
    return null;
  }
  return (width: data.getUint32(16), height: data.getUint32(20));
}

/// 피드에 잘리지 않도록 카드를 놓을 캔버스 크기.
({int width, int height}) pilotKakaoFeedFrame({
  required int width,
  required int height,
}) {
  if (width <= 0 || height <= 0) {
    return (width: width, height: height);
  }
  final ratio = width / height;
  if (ratio > pilotKakaoFeedWidest) {
    return (width: width, height: (width / pilotKakaoFeedWidest).ceil());
  }
  if (ratio < pilotKakaoFeedTallest) {
    return (width: (height * pilotKakaoFeedTallest).ceil(), height: height);
  }
  return (width: width, height: height);
}

/// 미리보기와 같은 PNG를 피드 비율 안에 둔다. 비율 안이면 바이트를 그대로 둔다.
Future<PilotKakaoFeedImage> fitPilotKakaoFeedPng(Uint8List png) async {
  final size = pngDimensions(png);
  if (size == null) {
    return PilotKakaoFeedImage(bytes: png, width: 0, height: 0);
  }
  final frame = pilotKakaoFeedFrame(width: size.width, height: size.height);
  if (frame.width == size.width && frame.height == size.height) {
    return PilotKakaoFeedImage(
      bytes: png,
      width: size.width,
      height: size.height,
    );
  }
  final codec = await ui.instantiateImageCodec(png);
  final source = (await codec.getNextFrame()).image;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()),
    ui.Paint()..color = AppColors.background,
  );
  canvas.drawImage(
    source,
    ui.Offset(
      (frame.width - source.width) / 2,
      (frame.height - source.height) / 2,
    ),
    ui.Paint(),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(frame.width, frame.height);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      return PilotKakaoFeedImage(
        bytes: png,
        width: size.width,
        height: size.height,
      );
    }
    return PilotKakaoFeedImage(
      bytes: data.buffer.asUint8List(),
      width: frame.width,
      height: frame.height,
    );
  } finally {
    source.dispose();
    image.dispose();
    picture.dispose();
  }
}
