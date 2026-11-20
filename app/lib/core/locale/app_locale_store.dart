import 'package:shared_preferences/shared_preferences.dart';

/// 언어 코드만 저장한다. 읽기나 쓰기가 실패해도 호출하는 쪽이 화면을 유지한다.
abstract interface class AppLocaleStore {
  static const storageKey = 'look_at_you.locale';

  Future<String?> read();

  Future<void> write(String languageCode);
}

class SharedPreferencesLocaleStore implements AppLocaleStore {
  const SharedPreferencesLocaleStore();

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(AppLocaleStore.storageKey);
  }

  @override
  Future<void> write(String languageCode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(AppLocaleStore.storageKey, languageCode);
  }
}

/// 테스트와 저장소 실패를 재현하는 메모리 저장소.
class MemoryLocaleStore implements AppLocaleStore {
  String? value;
  var fail = false;

  @override
  Future<String?> read() async {
    if (fail) {
      throw StateError('locale store unavailable');
    }
    return value;
  }

  @override
  Future<void> write(String languageCode) async {
    if (fail) {
      throw StateError('locale store unavailable');
    }
    value = languageCode;
  }
}
