import 'dart:js_interop';

/// 클릭에서 바로 새 탭을 연다. opener와 referrer는 넘기지 않는다.
///
/// noopener 창은 핸들이 비어 있어도 열린 것이므로, 그 사실만으로 실패로 보지 않는다.
bool openPilotExternalLink(Uri uri) {
  try {
    _window.open(
      uri.toString().toJS,
      '_blank'.toJS,
      'noopener,noreferrer'.toJS,
    );
    return true;
  } catch (_) {
    return false;
  }
}

@JS('window')
external _BrowserWindow get _window;

extension type _BrowserWindow._(JSObject _) implements JSObject {
  external JSAny? open(JSString url, JSString target, JSString features);
}
