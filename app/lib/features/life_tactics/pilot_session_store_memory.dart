/// 웹 sessionStorage와 테스트용 메모리가 같은 방식으로 읽고 쓴다.
abstract class PilotSessionStore {
  String? read();

  void write(String value);

  void clear();
}

/// VM·테스트 저장소. [failWrites]가 켜지면 쓰기가 막힌 브라우저를 대신한다.
class MemoryPilotSessionStore implements PilotSessionStore {
  MemoryPilotSessionStore({this.value});

  String? value;
  var failWrites = false;

  @override
  String? read() => value;

  @override
  void write(String value) {
    if (failWrites) {
      throw StateError('storage blocked');
    }
    this.value = value;
  }

  @override
  void clear() {
    value = null;
  }
}
