# Look At You

모바일 세로 화면과 PC 브라우저를 지원할 글로벌 자기탐색 앱입니다. 1단계에서는 기존 Flutter 카운터 예제로 개발 환경을 검증합니다. Flutter 패키지명은 `look_at_you`이며 Web과 Android 플랫폼이 구성되어 있습니다.

## 로컬 실행

Windows PowerShell에서 아래 명령을 실행합니다. Flutter가 이미 PATH에 있으면 첫 줄은 생략할 수 있습니다.

```powershell
$env:Path = "C:\src\flutter\bin;$env:Path"
Set-Location D:\AppYou\app
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Chrome에서 기본 화면이 열리면 + 버튼을 눌러 카운터가 올라가는지 확인합니다. 터미널에서 `r`로 변경 사항을 반영하고 `q`로 종료합니다.

### 환경 점검

- `flutter doctor -v`에서 JDK를 찾지 못하면 PowerShell에서 `$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"`를 설정합니다. Android SDK의 설치 위치는 `$env:ANDROID_HOME = "$env:USERPROFILE\AppData\Local\Android\Sdk"`로 지정할 수 있습니다.
- 위젯 테스트가 `127.0.0.1` 소켓 오류로 로딩 중 종료되거나 Chrome이 DevTools 연결 전에 종료되면, PC의 일반 PowerShell에서 위 실행 명령을 다시 확인합니다. 브라우저 연결과 별도로 웹 컴파일은 `flutter build web`으로 검사할 수 있습니다.
- Android 연결 상태는 `& "$env:ANDROID_HOME\platform-tools\adb.exe" devices`로 확인합니다.

## 프로젝트 구조

| 경로 | 역할 |
| --- | --- |
| `app/lib/main.dart` | 현재 기본 앱 진입점 |
| `app/lib/features/` | home, quiz, result, sharing, settings 기능별 코드 |
| `app/lib/l10n/` | 공통 UI 번역 리소스 예정 위치 |
| `app/web/`, `app/android/` | 플랫폼별 실행 설정 |
| `app/test/` | Flutter 위젯 및 Dart 단위 테스트 |
| `data/source/`, `data/schemas/` | Excel 원본과 데이터 스키마 |
| `tools/data/` | Python 직렬화 도구 예정 위치 |
| `app/assets/data/` | 앱이 읽을 생성 JSON 예정 위치 |
| `tests/` | 데이터 파이프라인 및 통합 검증 |
| `docs/`, `design/` | 기획·설계 문서와 사이다 캐릭터 등 디자인 원본 |

## 다음 단계

첫 Excel 시트의 ID, 번역 키, 필수 열과 자료형을 정하고 대응하는 JSON 예시를 정의합니다. 이후 Python 변환 도구를 추가하고 출력 JSON을 Flutter 자산으로 등록합니다. iOS 확장 시 macOS와 Xcode가 준비된 환경에서 앱 식별자를 확인한 뒤 `app/`에 iOS 플랫폼을 추가합니다.

개발 규칙은 [AGENTS.md](AGENTS.md)를 참고하세요.
