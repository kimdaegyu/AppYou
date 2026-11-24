import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// 이 시간 안에 끝나면 로딩 문구를 보여 주지 않는다.
const pilotNoticeDelay = Duration(milliseconds: 400);

/// 테스트가 이미지 준비를 대신 끝낸다. 화면은 이 결과가 난 뒤에만 그림을 연다.
Future<void> Function(BuildContext context, String asset) pilotLoadAsset =
    _loadAssetFrame;

/// 같은 그림 묶음의 준비, 지연 안내, 실패를 한 번에 다룬다.
class PilotImageGroup extends StatefulWidget {
  const PilotImageGroup({
    super.key,
    required this.assets,
    required this.builder,
  });

  final List<String> assets;
  final Widget Function(BuildContext context, PilotImagePhase phase) builder;

  @override
  State<PilotImageGroup> createState() => _PilotImageGroupState();
}

class PilotImagePhase {
  const PilotImagePhase({
    required this.ready,
    required this.failed,
    required this.showNotice,
    required this.retry,
  });

  final bool ready;
  final bool failed;

  /// 400ms가 지나도 아직 준비되지 않았을 때만 참이다.
  final bool showNotice;
  final VoidCallback retry;
}

class _PilotImageGroupState extends State<PilotImageGroup> {
  var _generation = 0;
  var _ready = false;
  var _failed = false;
  var _showNotice = false;
  String? _signature;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensure();
  }

  @override
  void didUpdateWidget(PilotImageGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensure();
  }

  @override
  void dispose() {
    _generation += 1;
    _timer?.cancel();
    super.dispose();
  }

  void _ensure() {
    final signature = widget.assets.join('\u0001');
    if (signature == _signature) {
      return;
    }
    _signature = signature;
    _begin();
  }

  void _begin() {
    _timer?.cancel();
    final generation = ++_generation;
    _ready = false;
    _failed = false;
    _showNotice = false;
    final assets = List<String>.of(widget.assets);
    if (assets.any((asset) => asset.isEmpty)) {
      _failed = true;
      return;
    }
    if (assets.isEmpty) {
      _ready = true;
      return;
    }
    final pending = assets.toSet();
    _timer = Timer(pilotNoticeDelay, () {
      if (!mounted || generation != _generation || _ready || _failed) {
        return;
      }
      setState(() => _showNotice = true);
    });
    for (final asset in assets) {
      pilotLoadAsset(context, asset).then(
        (_) => _arrive(generation, pending, asset, failed: false),
        onError: (Object _, StackTrace _) =>
            _arrive(generation, pending, asset, failed: true),
      );
    }
  }

  void _arrive(
    int generation,
    Set<String> pending,
    String asset, {
    required bool failed,
  }) {
    if (!mounted || generation != _generation || _ready || _failed) {
      return;
    }
    if (failed) {
      _timer?.cancel();
      _failed = true;
      _showNotice = false;
      _publish();
      return;
    }
    pending.remove(asset);
    if (pending.isNotEmpty) {
      return;
    }
    _timer?.cancel();
    _ready = true;
    _showNotice = false;
    _publish();
  }

  void _publish() {
    final building =
        WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks;
    if (building) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
      return;
    }
    setState(() {});
  }

  void _retry() {
    _signature = null;
    setState(_ensure);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      PilotImagePhase(
        ready: _ready,
        failed: _failed,
        showNotice: _showNotice && !_ready && !_failed,
        retry: _retry,
      ),
    );
  }
}

Future<void> _loadAssetFrame(BuildContext context, String asset) {
  final completer = Completer<void>();
  final stream = AssetImage(asset)
      .resolve(createLocalImageConfiguration(context));
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo image, bool synchronousCall) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    },
    onError: (Object error, StackTrace? stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    },
  );
  stream.addListener(listener);
  completer.future.whenComplete(() {
    scheduleMicrotask(() => stream.removeListener(listener));
  });
  return completer.future;
}
