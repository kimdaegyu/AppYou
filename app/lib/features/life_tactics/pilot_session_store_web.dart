import 'dart:js_interop';

import 'pilot_session_store_memory.dart';

export 'pilot_session_store_memory.dart';

/// 같은 탭의 sessionStorage. 막혀 있으면 빈 저장소처럼 두고 진단은 계속한다.
PilotSessionStore createPilotSessionStore() => WebPilotSessionStore();

class WebPilotSessionStore implements PilotSessionStore {
  static const storageKey = 'lookatyou.pilot.life_tactics';

  @override
  String? read() {
    try {
      return _sessionStorage.getItem(storageKey.toJS)?.toDart;
    } catch (_) {
      return null;
    }
  }

  @override
  void write(String value) {
    try {
      _sessionStorage.setItem(storageKey.toJS, value.toJS);
    } catch (_) {}
  }

  @override
  void clear() {
    try {
      _sessionStorage.removeItem(storageKey.toJS);
    } catch (_) {}
  }
}

@JS('sessionStorage')
external _BrowserSessionStorage get _sessionStorage;

extension type _BrowserSessionStorage._(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);

  external void setItem(JSString key, JSString value);

  external void removeItem(JSString key);
}
