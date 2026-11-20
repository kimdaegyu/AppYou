import 'package:flutter/services.dart';

import '../theme/app_fonts.dart';

/// 폰트 파일을 읽거나 등록하지 못했을 때.
class AppFontLoadException implements Exception {
  const AppFontLoadException(this.asset);

  final String asset;

  @override
  String toString() => 'AppFontLoadException: $asset';
}

/// 선택한 언어의 파일만 `rootBundle`과 [FontLoader]로 등록한다.
///
/// 같은 에셋은 진행 중인 Future 하나를 공유한다. 실패는 캐시에 남기지 않아
/// 다시 시도할 수 있다. `flutter/fonts`에는 등록하지 않는다.
class AppFontLoader {
  AppFontLoader({
    Future<ByteData> Function(String asset)? loadBytes,
    Future<void> Function(String family, ByteData data)? register,
  }) : _loadBytes = loadBytes ?? rootBundle.load,
       _register = register ?? _registerWithEngine;

  final Future<ByteData> Function(String asset) _loadBytes;
  final Future<void> Function(String family, ByteData data) _register;
  final Map<String, Future<void>> _pending = {};
  var _failNext = false;

  /// 다음 [ensure] 한 번을 실패시킨다. 이미 받은 캐시도 그 파일은 버린다.
  void failNext() {
    _failNext = true;
  }

  Future<void> ensure(AppFontPlan plan) async {
    if (_failNext) {
      _failNext = false;
      final asset = plan.files.first.asset;
      _pending.remove(asset);
      throw AppFontLoadException(asset);
    }
    for (final file in plan.files) {
      await _one(file);
    }
  }

  Future<void> _one(AppFontFile file) {
    return _pending.putIfAbsent(file.asset, () {
      return _load(file).catchError((Object error, StackTrace stack) {
        _pending.remove(file.asset);
        Error.throwWithStackTrace(error, stack);
      });
    });
  }

  Future<void> _load(AppFontFile file) async {
    final data = await _loadBytes(file.asset);
    await _register(file.family, data);
  }

  static Future<void> _registerWithEngine(String family, ByteData data) {
    final loader = FontLoader(family);
    loader.addFont(Future<ByteData>.value(data));
    return loader.load();
  }
}
