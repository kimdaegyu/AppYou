import 'pilot_session_store_memory.dart';

export 'pilot_session_store_memory.dart';

/// 웹이 아닌 빌드. 탭을 다시 열어도 이 메모리는 비어 있다.
PilotSessionStore createPilotSessionStore() => MemoryPilotSessionStore();
