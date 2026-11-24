import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'pilot_kakao_image.dart';
import 'pilot_share_file.dart';
import 'pilot_share_link.dart';

/// 클릭 안에서 `navigator.share`를 바로 호출한다. 그 전에 await하면 권한이 사라진다.
bool canSharePilotLink(PilotShareLink link) => _shareFunction != null;

bool? _fileShareSupported;

/// `navigator.canShare({ files })`로 결과 PNG 공유를 확인한다.
bool canSharePilotFile() {
  final cached = _fileShareSupported;
  if (cached != null) {
    return cached;
  }
  final canShare = _canShareFunction;
  if (canShare == null || _shareFunction == null) {
    return _fileShareSupported = false;
  }
  try {
    final data = JSObject();
    data.setProperty('files'.toJS, [_probeFile].toJS);
    return _fileShareSupported = _navigator.canShare(data).toDart;
  } catch (_) {
    return _fileShareSupported = false;
  }
}

bool samsungInternetBrowser() =>
    _userAgent.toDart.toLowerCase().contains('samsungbrowser/');

bool kakaoTalkBrowser() => pilotKakaoTalkAgent(_userAgent.toDart);

/// 준비된 주소는 클릭 안에서 피드 창을 연다. 바이트만 있으면 먼저 업로드한다.
Future<PilotKakaoDelivery> sendPilotKakaoShare(PilotKakaoShare message) {
  _initKakao();
  final ready = message.imageUrl;
  if (ready != null && ready.isNotEmpty) {
    return Future.value(_deliverFeed(message, ready));
  }
  return _uploadThenDeliver(message);
}

Future<PilotKakaoDelivery> _uploadThenDeliver(PilotKakaoShare message) async {
  final bytes = message.imageBytes;
  final upload = _uploadKakaoImage;
  if (bytes == null ||
      bytes.isEmpty ||
      upload == null ||
      _kakaoGlobal == null ||
      bytes.length > pilotKakaoImageByteLimit) {
    return const PilotKakaoDelivery(result: PilotShareFileResult.failed);
  }
  final JSObject uploaded;
  try {
    final raw = upload.callAsFunction(null, bytes.toJS, message.filename.toJS);
    if (raw == null || !raw.isA<JSPromise>()) {
      return const PilotKakaoDelivery(result: PilotShareFileResult.failed);
    }
    final result = await (raw as JSPromise).toDart;
    if (result == null || !result.isA<JSObject>()) {
      return const PilotKakaoDelivery(result: PilotShareFileResult.failed);
    }
    uploaded = result as JSObject;
  } catch (_) {
    return const PilotKakaoDelivery(result: PilotShareFileResult.failed);
  }
  final url = uploaded.getProperty<JSString?>('url'.toJS)?.toDart ?? '';
  final width = uploaded.getProperty<JSNumber?>('width'.toJS)?.toDartInt ?? 0;
  final height = uploaded.getProperty<JSNumber?>('height'.toJS)?.toDartInt ?? 0;
  if (url.isEmpty || width <= 0 || height <= 0) {
    return const PilotKakaoDelivery(result: PilotShareFileResult.failed);
  }
  final image = PilotKakaoImage(url: url, width: width, height: height);
  final ready = PilotKakaoShare(
    title: message.title,
    buttonTitle: message.buttonTitle,
    webUrl: message.webUrl,
    mobileWebUrl: message.mobileWebUrl,
    imageUrl: url,
    imageWidth: width,
    imageHeight: height,
    filename: message.filename,
  );
  if (!_gestureActive()) {
    return PilotKakaoDelivery(
      result: PilotShareFileResult.needsGesture,
      image: image,
    );
  }
  return _deliverFeed(ready, url, image: image);
}

PilotKakaoDelivery _deliverFeed(
  PilotKakaoShare message,
  String imageUrl, {
  PilotKakaoImage? image,
}) {
  final send = _sendKakaoFeed;
  if (send == null) {
    return PilotKakaoDelivery(
      result: PilotShareFileResult.unavailable,
      image: image,
    );
  }
  final kept =
      image ??
      PilotKakaoImage(
        url: imageUrl,
        width: message.imageWidth,
        height: message.imageHeight,
      );
  try {
    final settings = _toJs(
      pilotKakaoFeedSettings(
        PilotKakaoShare(
          title: message.title,
          buttonTitle: message.buttonTitle,
          webUrl: message.webUrl,
          mobileWebUrl: message.mobileWebUrl,
          imageUrl: imageUrl,
          imageWidth: kept.width,
          imageHeight: kept.height,
        ),
      ),
    );
    final status = send.callAsFunction(null, settings);
    final name = status.isA<JSString>() ? (status as JSString).toDart : '';
    if (name == 'blocked') {
      return PilotKakaoDelivery(
        result: PilotShareFileResult.needsGesture,
        image: kept,
      );
    }
    if (name != 'opened') {
      return PilotKakaoDelivery(
        result: PilotShareFileResult.failed,
        image: kept,
      );
    }
    return PilotKakaoDelivery(result: PilotShareFileResult.opened, image: kept);
  } catch (_) {
    return PilotKakaoDelivery(result: PilotShareFileResult.failed, image: kept);
  }
}

bool _gestureActive() {
  final ask = _kakaoGestureActive;
  if (ask == null) {
    return true;
  }
  try {
    final value = ask.callAsFunction(null);
    return value.isA<JSBoolean>() && (value as JSBoolean).toDart;
  } catch (_) {
    return true;
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

Future<PilotShareFileResult> sharePilotResult(
  PilotShareLink link,
  PilotShareFile file,
) {
  if (_shareFunction == null) {
    return Future.value(PilotShareFileResult.unavailable);
  }
  final JSPromise promise;
  try {
    final data = _resultData(link, file);
    if (_canShareFunction != null && !_navigator.canShare(data).toDart) {
      return Future.value(PilotShareFileResult.failed);
    }
    promise = _navigator.share(data);
  } catch (_) {
    return Future.value(PilotShareFileResult.failed);
  }
  return _waitForShare(promise);
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
    final JSString url;
    if (samsungInternetBrowser()) {
      url = Uri.base.resolve('result-cards/${file.filename}').toString().toJS;
    } else {
      url = _Url.createObjectURL(blob);
      Timer(const Duration(minutes: 1), () => _Url.revokeObjectURL(url));
    }
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

JSObject _resultData(PilotShareLink link, PilotShareFile file) {
  final full = JSObject();
  full.setProperty('files'.toJS, [_pngFile(file.bytes, file.filename)].toJS);
  full.setProperty('text'.toJS, link.text.toJS);
  full.setProperty('url'.toJS, link.url.toString().toJS);
  if (_canShareFunction == null) {
    return full;
  }
  try {
    if (_navigator.canShare(full).toDart) {
      return full;
    }
  } catch (_) {
    // The combined payload is checked again below.
  }
  final titled = JSObject();
  titled.setProperty('files'.toJS, [_pngFile(file.bytes, file.filename)].toJS);
  titled.setProperty('text'.toJS, '${link.text}\n${link.url}'.toJS);
  return titled;
}

_File _pngFile(Uint8List bytes, String filename) {
  return _File(
    [bytes.toJS].toJS,
    filename.toJS,
    _options({'type': 'image/png'}),
  );
}

JSAny? _toJs(Object? value) {
  switch (value) {
    case null:
      return null;
    case String text:
      return text.toJS;
    case int number:
      return number.toJS;
    case double number:
      return number.toJS;
    case bool flag:
      return flag.toJS;
    case Map map:
      final object = JSObject();
      for (final entry in map.entries) {
        object.setProperty(entry.key.toString().toJS, _toJs(entry.value));
      }
      return object;
    case List list:
      final array = JSArray<JSAny?>.withLength(list.length);
      for (var index = 0; index < list.length; index++) {
        array[index] = _toJs(list[index]);
      }
      return array;
    default:
      return value.toString().toJS;
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
    return JSObject()
      ..setProperty('text'.toJS, '${link.text}\n${link.url}'.toJS);
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

@JS('lookAtYouUploadKakaoImage')
external JSFunction? get _uploadKakaoImage;

@JS('lookAtYouSendKakaoFeed')
external JSFunction? get _sendKakaoFeed;

@JS('lookAtYouKakaoGestureActive')
external JSFunction? get _kakaoGestureActive;

final _File _probeFile = _pngFile(
  Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]),
  'probe.png',
);

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

@JS('File')
extension type _File._(JSObject _) implements JSObject {
  external _File(JSArray<JSAny> parts, JSString name, JSObject options);
}

@JS('URL')
extension type _Url._(JSObject _) implements JSObject {
  external static void revokeObjectURL(JSString url);
  external static JSString createObjectURL(JSObject object);
}
