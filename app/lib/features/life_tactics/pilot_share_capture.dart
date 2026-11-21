import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// 카드 가로. 화면 폭과 상관없이 이 크기로 그린다.
const pilotShareExportWidth = 1080.0;

/// 테스트가 실제 그리기 대신 카드 내용으로 바이트를 만든다.
Future<Uint8List> Function(
  BuildContext context, {
  required Widget card,
  required List<String> assets,
})
pilotCaptureCard = capturePilotShareCard;

/// [LifeTacticsShareCard]를 화면 밖에서 가로 1080으로 그려 PNG로 만든다.
Future<Uint8List> capturePilotShareCard(
  BuildContext context, {
  required Widget card,
  required List<String> assets,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  for (final asset in assets) {
    if (asset.isEmpty) {
      continue;
    }
    await precacheImage(AssetImage(asset), context);
  }
  final boundaryKey = GlobalKey();
  final entry = OverlayEntry(
    builder: (overlayContext) {
      final media = MediaQuery.of(overlayContext);
      return Positioned(
        left: 0,
        top: 0,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Opacity(
              opacity: 0.02,
              child: Transform.scale(
                scale: 4 / pilotShareExportWidth,
                alignment: Alignment.topLeft,
                child: MediaQuery(
                  data: media.copyWith(textScaler: TextScaler.noScaling),
                  child: SizedBox(
                    width: pilotShareExportWidth,
                    child: RepaintBoundary(key: boundaryKey, child: card),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
  try {
    await _afterFrames(3);
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize || boundary.size.width <= 0) {
      throw StateError('share card was not painted');
    }
    var waits = 0;
    while (boundary.debugNeedsPaint && waits < 4) {
      await _afterFrames(1);
      waits += 1;
    }
    late ui.Image image;
    try {
      image = boundary.toImageSync(pixelRatio: 1);
    } catch (_) {
      image = await boundary.toImage(pixelRatio: 1);
    }
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('png was empty');
      }
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    entry.remove();
  }
}

Future<void> _afterFrames(int count) async {
  for (var i = 0; i < count; i++) {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
    await completer.future;
  }
}
