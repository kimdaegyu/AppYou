import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'pilot_share_file.dart';
import 'pilot_share_link.dart';

/// 클릭 안에서 `navigator.share`를 바로 호출한다. 그 전에 await하면 권한이 사라진다.
bool canSharePilotLink(PilotShareLink link) => _shareFunction != null;

bool kakaoTalkBrowser() => pilotKakaoTalkAgent(_userAgent.toDart);

/// `Kakao.Share.sendDefault`를 클릭 안에서 바로 호출한다.
Future<PilotShareFileResult> sendPilotKakaoShare(PilotKakaoShare message) {
  _initKakao();
  final kakao = _kakaoGlobal;
  final share = kakao?.getProperty<JSObject?>('Share'.toJS);
  final send = share?.getProperty<JSFunction?>('sendDefault'.toJS);
  if (kakao == null || share == null || send == null) {
    return Future.value(PilotShareFileResult.unavailable);
  }
  final link = JSObject();
  link.setProperty('webUrl'.toJS, message.webUrl.toString().toJS);
  link.setProperty('mobileWebUrl'.toJS, message.mobileWebUrl.toString().toJS);
  final settings = JSObject();
  settings.setProperty('objectType'.toJS, 'text'.toJS);
  settings.setProperty('text'.toJS, message.text.toJS);
  settings.setProperty('link'.toJS, link);
  settings.setProperty('buttonTitle'.toJS, message.buttonTitle.toJS);
  try {
    send.callAsFunction(share, settings);
    return Future.value(PilotShareFileResult.opened);
  } catch (_) {
    return Future.value(PilotShareFileResult.failed);
  }
}

void _initKakao() {
  final kakao = _kakaoGlobal;
  final key = _kakaoJavaScriptKey?.toDart ?? '';
  if (kakao == null || key.isEmpty) {
    return;
  }
  final initialized = kakao.getProperty<JSFunction?>('isInitialized'.toJS);
  final ready = initialized?.callAsFunction(kakao);
  if (ready.isA<JSBoolean>() && (ready as JSBoolean).toDart) {
    return;
  }
  kakao.getProperty<JSFunction?>('init'.toJS)?.callAsFunction(kakao, key.toJS);
}

Future<PilotShareFileResult> sharePilotLink(PilotShareLink link) {
  if (!canSharePilotLink(link)) {
    return Future.value(PilotShareFileResult.unavailable);
  }
  final JSPromise promise;
  try {
    final data = _linkData(link);
    promise = _navigator.share(data);
  } catch (_) {
    return Future.value(PilotShareFileResult.failed);
  }
  return _waitForShare(promise);
}

Future<bool> copyPilotText(String text) {
  final clipboard = _clipboardObject;
  final write = clipboard?.getProperty<JSFunction?>('writeText'.toJS);
  if (clipboard == null || write == null) {
    return Future.value(false);
  }
  try {
    final JSAny? result = write.callAsFunction(clipboard, text.toJS);
    if (result != null && result.isA<JSPromise>()) {
      return (result as JSPromise).toDart.then(
        (_) => true,
        onError: (_) => false,
      );
    }
    return Future.value(false);
  } catch (_) {
    return Future.value(false);
  }
}

Future<PilotSaveFileResult> savePilotFile(PilotShareFile file) {
  try {
    final blob = _Blob([file.bytes.toJS].toJS, _options({'type': 'image/png'}));
    final opens = pilotImageOpensForSaving(
      _userAgent.toDart,
      maxTouchPoints: _maxTouchPoints.toDartInt,
    );
    if (opens) {
      _showSaveImage(
        blob,
        file.filename.toJS,
        file.saveHint.toJS,
        file.closeLabel.toJS,
      );
      return Future.value(PilotSaveFileResult.opened);
    }
    final url = _Url.createObjectURL(blob);
    Timer(const Duration(minutes: 1), () => _Url.revokeObjectURL(url));
    final anchor = _Anchor(_document.createElement('a'.toJS));
    anchor.href = url;
    anchor.download = file.filename.toJS;
    _document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return Future.value(PilotSaveFileResult.downloaded);
  } catch (_) {
    return Future.value(PilotSaveFileResult.failed);
  }
}

Future<PilotShareFileResult> _waitForShare(JSPromise promise) async {
  try {
    await promise.toDart;
    return PilotShareFileResult.opened;
  } catch (error) {
    final name = error.isA<JSObject>()
        ? (error as JSObject).getProperty<JSString?>('name'.toJS)?.toDart
        : null;
    if (name == 'AbortError') {
      return PilotShareFileResult.cancelled;
    }
    return PilotShareFileResult.failed;
  }
}

JSObject _linkData(PilotShareLink link) {
  final payload = JSObject();
  payload.setProperty('text'.toJS, link.text.toJS);
  payload.setProperty('url'.toJS, link.url.toString().toJS);
  if (_canShareFunction != null) {
    try {
      if (_navigator.canShare(payload).toDart) return payload;
    } catch (_) {
      // Some embedded browsers only implement the share call itself.
    }
    return JSObject()..setProperty('url'.toJS, link.url.toString().toJS);
  }
  return payload;
}

JSObject _options(Map<String, String> values) {
  final object = JSObject();
  for (final entry in values.entries) {
    object.setProperty(entry.key.toJS, entry.value.toJS);
  }
  return object;
}

@JS('Kakao')
external JSObject? get _kakaoGlobal;

@JS('lookAtYouKakaoJavaScriptKey')
external JSString? get _kakaoJavaScriptKey;

@JS('navigator.canShare')
external JSFunction? get _canShareFunction;

@JS('navigator.share')
external JSFunction? get _shareFunction;

@JS('navigator.clipboard')
external JSObject? get _clipboardObject;

@JS('navigator.userAgent')
external JSString get _userAgent;

@JS('navigator.maxTouchPoints')
external JSNumber get _maxTouchPoints;

@JS('navigator')
external _Navigator get _navigator;

@JS('document')
external _Document get _document;

extension type _Navigator._(JSObject _) implements JSObject {
  external JSBoolean canShare(JSObject data);

  external JSPromise share(JSObject data);
}

extension type _Document._(JSObject _) implements JSObject {
  external _Body? get body;

  external JSObject createElement(JSString tag);
}

extension type _Body._(JSObject _) implements JSObject {
  external void append(JSAny node);
}

extension type _Anchor(JSObject _) implements JSObject {
  external set href(JSString value);

  external set download(JSString value);

  external void click();

  external void remove();
}

@JS('lookAtYouSaveImage')
external void _showSaveImage(
  _Blob blob,
  JSString filename,
  JSString hint,
  JSString close,
);

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external _Blob(JSArray<JSAny> parts, JSObject options);
}

@JS('URL')
extension type _Url._(JSObject _) implements JSObject {
  external static void revokeObjectURL(JSString url);
  external static JSString createObjectURL(JSObject object);
}
