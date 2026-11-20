import 'package:material_ui/material_ui.dart';

import '../fonts/app_font_loader.dart';
import '../theme/app_fonts.dart';
import 'app_locale_store.dart';

enum AppFontReadiness { idle, loading, ready, failed }

/// 앱 루트의 언어. 새 코드는 바로 반영하고, 폰트는 비동기로 준비한다.
///
/// 로드가 끝나도 그 사이 언어가 바뀌었으면 결과를 버린다.
class AppLocaleController extends ChangeNotifier {
  AppLocaleController({
    required this.store,
    required this.loader,
    this.languageCode = 'ko',
  }) : locale = AppFonts.localeOf(languageCode);

  final AppLocaleStore store;
  final AppFontLoader loader;

  String languageCode;
  Locale locale;
  AppFontReadiness readiness = AppFontReadiness.idle;

  int _generation = 0;
  var _disposed = false;
  var _userChosen = false;

  /// 저장값과 기기 선호를 해석한 뒤 true가 된다.
  var settled = false;

  bool get isFontReady => readiness == AppFontReadiness.ready;

  /// 저장값 → 기기 선호 → 한국어. 사용자가 이미 골랐으면 덮지 않는다.
  Future<void> restore(List<String> deviceTags) async {
    if (_userChosen || _disposed) {
      _settle();
      return;
    }
    String? saved;
    try {
      saved = await store.read();
    } catch (_) {
      saved = null;
    }
    if (_userChosen || _disposed) {
      _settle();
      return;
    }
    await _apply(
      AppFonts.resolve(saved: saved, deviceTags: deviceTags),
      persist: false,
    );
    _settle();
  }

  Future<void> select(String code) {
    final normalized = AppFonts.normalize(code);
    if (normalized == null) {
      return Future<void>.value();
    }
    _userChosen = true;
    settled = true;
    return _apply(normalized, persist: true);
  }

  Future<void> retry() {
    return _apply(languageCode, persist: false);
  }

  void failNextLoad() {
    loader.failNext();
  }

  Future<void> _apply(String code, {required bool persist}) {
    final generation = ++_generation;
    languageCode = code;
    locale = AppFonts.localeOf(code);
    readiness = AppFontReadiness.loading;
    _notify();
    return _finish(generation, code, persist: persist);
  }

  Future<void> _finish(
    int generation,
    String code, {
    required bool persist,
  }) async {
    if (persist) {
      try {
        await store.write(code);
      } catch (_) {
        // 저장이 실패해도 이번 화면의 언어는 유지한다.
      }
    }
    if (generation != _generation || _disposed) {
      return;
    }
    try {
      await loader.ensure(AppFonts.plan(code));
      if (generation != _generation || _disposed) {
        return;
      }
      readiness = AppFontReadiness.ready;
      _notify();
    } catch (_) {
      if (generation != _generation || _disposed) {
        return;
      }
      readiness = AppFontReadiness.failed;
      _notify();
    }
  }

  void _settle() {
    if (settled || _disposed) {
      return;
    }
    settled = true;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
