# Cursor 작업 요청 · 글로벌 폰트 시스템

D:\AppYou에서 아래 작업을 구현하고 검증해 주세요. 목표는 Look At You의 언어를 바꾸면 앱과 공통 UI 미리보기의 글꼴이 함께 바뀌고, 진단 입력 상태와 읽기 편한 레이아웃이 유지되는 것입니다.

## 1. 기존 구현 확인
AGENTS.md, docs/02_ARCHITECTURE.md, 05_LOCALIZATION.md, 09_UI_DESIGN_SYSTEM.md를 먼저 읽으세요. app/lib/core/theme/에 AppTheme.light, AppTypography 등이 있고 app/lib/shared/widgets/에 버튼·카드·선택지·진행률이 있습니다. main.dart와 ui_preview.dart는 별도 진입점입니다. shared_widgets_test.dart 및 기본 앱 테스트를 보존하세요. 현재 코드의 material_ui 패키지 관례와 실제 SDK 버전을 확인하세요. 기존 설정 저장소·locale 컨트롤러가 생겼다면 재사용하세요.

## 2. 에셋과 라이선스 준비
기본 매핑은 ko → Pretendard, en·pt-BR·es·id → Pretendard Std, ja → Pretendard JP, vi → Noto Sans, th → Noto Sans Thai, hi → Noto Sans Devanagari입니다. ko/en/ja/pt-BR은 현재 번역 스키마 대상이고 es/id/vi/th/hi는 미리보기 검수 대상입니다. 실제 제품 메뉴에는 번역 출시 정책을 적용하세요.

app/assets/fonts/{pretendard,pretendard_std,pretendard_jp,noto_sans,noto_sans_thai,noto_sans_devanagari}/에 필요한 파일만 관리하세요. Pretendard는 공식 릴리스, Noto는 Google Fonts의 ofl/notosans, ofl/notosansthai, ofl/notosansdevanagari 또는 해당 Noto 공식 릴리스에서 받으세요. 패밀리마다 태그 또는 커밋, 파일명, 출처 URL, SHA-256, 원본 크기, 실제 wght 범위와 라이선스를 기록하세요. 가짜 바이너리나 시스템에 우연히 설치된 폰트로 검수를 통과시키지 마세요.

후보 라이선스는 SIL OFL 1.1입니다. 상업 앱·웹에 포함하거나 결과 이미지를 만드는 용도로 사용할 수 있습니다. 재배포하는 파일에는 해당 배포본의 저작권 고지와 OFL 원문을 포함하고 앱 배포물의 오픈소스 고지에서 열람 가능하게 하세요. 글꼴 단독 판매 제한 및 수정본의 Reserved Font Name 조건을 확인하세요. 서브셋·형식 변환을 하면 수정 이력과 배포 조건을 다시 확인하세요. 공유 PNG 자체에 OFL을 적용할 필요는 없습니다. [OFL 원문](https://openfontlicense.org/open-font-license-official-text/) · [Pretendard](https://github.com/orioncactus/pretendard) · [Google Fonts 배포본](https://github.com/google/fonts/tree/main/ofl)

## 3. 파일 구성과 Web 로딩
공통 배포 형식은 TTF/OTF를 우선하고 upright 가변 파일 1개로 400/500/600/700이 구현되는지 먼저 확인하세요. 같은 파일을 네 굵기로 중복 복사하지 마세요. 실제 SDK에서 가변 굵기가 구별되지 않거나 정적 구성이 더 작고 안정적이라면 필요한 네 굵기의 정적 파일만 사용하고 pubspec.yaml의 family·asset·weight를 정확히 연결하세요. 이탤릭·모노·사용하지 않는 굵기는 제외하세요.

| 방식 | 사용 판단 | 확인할 비용 |
| --- | --- | --- |
| flutter/fonts 선언형 등록 | 가장 단순한 비교 기준. 필요한 언어만 초기 전송됨이 확인되면 유지 | 파일 등록과 실제 다운로드 시점은 별개. release 네트워크 기록으로 확인 |
| 언어별 런타임 로딩 | 권장 Web 경로. 선언형이 다른 패밀리를 함께 내려받으면 해당 파일을 flutter/assets에 등록해 rootBundle + FontLoader로 선택 언어만 로드 | 패밀리별 1회 로딩, 최초 지연, 중복 호출·실패·전환 경쟁 처리. 같은 파일을 두 방식으로 이중 등록하지 않기 |
| 서브셋 | CJK 전송량이 여전히 크면 공식 배포 서브셋을 먼저 비교. 자체 생성은 근거와 재생성 절차가 있을 때 별도 채택 | 런타임 치환, 새 번역·구버전 공유 문구, NFC/NFD, GSUB/GPOS 및 결합 부호 보존. CSS unicode-range가 Flutter에도 적용된다고 가정하지 않기 |

Web은 기본 문구와 폴백으로 먼저 그릴 수 있어야 합니다. 전 언어를 기다리는 시작 화면은 피하세요. 추가 언어의 QA용 바이너리는 제품 배포 번들 포함 여부를 명시하고, 미출시 언어의 첫 방문 요청은 발생하지 않아야 합니다. Android/iOS에서는 같은 원본·테마를 재사용하고 앱 패키지에 포함된 용량과 실제 첫 실행 I/O를 구분하세요. [Flutter 커스텀 폰트](https://docs.flutter.dev/cookbook/design/fonts) · [FontLoader](https://api.flutter.dev/flutter/services/FontLoader-class.html)

## 4. 테마와 타이포그래피 구현
기존 core/theme/에 app_fonts.dart를 추가하고 app_typography.dart와 app_theme.dart를 확장하세요. 별도의 lib/app/theme/를 만들지 마세요. AppFonts는 정규화된 locale별 primary·ordered fallback·asset 식별자를 반환합니다. AppTypography는 역할과 수치를, AppTheme은 locale별 ThemeData·TextTheme 구성을 담당합니다. 앱과 미리보기에 같은 테마를 적용하세요. 기존 AppTheme.light 호출은 호환 진입점을 유지하거나 모든 호출부를 함께 전환하세요.

| 역할 | 크기 / 굵기 / 줄 높이 | 권장 소비 위치 |
| --- | --- | --- |
| 대제목 | 28 / 700 / 1.3 | headlineLarge |
| 진단 질문 | 20 / 600 / 1.5 | titleLarge |
| 결과 타입명 | 24 / 700 / 1.4 | headlineMedium |
| 본문 | 16 / 400 / 1.6 | bodyLarge, 선택지, 카드 본문 |
| 버튼 | 16 / 600 / 1.3 | labelLarge |
| 사이다 대사 | 16 기본 또는 14 / 500 / 1.5 | 대사 전용 역할 |
| 보조 설명 | 14 / 400 / 1.5 | 보조 역할, 진행 문구 |

현재 question.height=1.4, body.height=1.5, secondary=16/1.45, button.height=1.25이므로 새 규격에 맞추세요. AppButton·AppChoiceOption·AppProgress·미리보기에서 static const 스타일을 직접 쓰는 부분은 locale이 반영된 역할 스타일을 받도록 점검하세요. 선택·비활성 버튼 전경색, 아이콘 전용 글꼴, 카드의 자식 스타일 상속, 기존 색 토큰 및 반응형 규격을 보존하세요.

## 5. 언어 상태와 실패 처리
저장된 유효 코드 → 기기 선호 목록 → ko 순으로 초기 언어를 해석합니다. 앱 루트 locale과 위젯 텍스트의 locale을 일치시키고, 필요 시 SDK 지역화 delegate를 연결하세요. 동일 패밀리를 공유하는 en ↔ pt-BR에서도 문구와 locale은 바뀌어야 합니다. 언어 코드만 지속 저장하세요. 앱에 저장 계층이 없다면 Web·모바일 공용 경량 저장 방식(예: shared_preferences)을 한 곳에서 사용하세요. 저장소가 비었거나 접근에 실패해도 기본 화면을 표시하세요.

언어 변경 이벤트에서 즉시 새 locale을 적용하고 필요한 패밀리를 비동기로 준비하세요. 폰트 로드 완료 시 최신 선택일 때만 갱신합니다. 폴백 렌더링·재시도 중에도 응답과 입력을 유지하세요. 빠른 ko → ja → en 전환에서 오래된 ja 로드 결과가 en을 덮지 않아야 합니다. 라틴 언어 간에는 같은 로딩 Future와 캐시를 공유하세요. 퀴즈 세션·라우터를 locale 키로 재생성하지 마세요. 진단 엔진이 아직 없으면 미리보기의 선택지와 진행 위치로 보존을 검증하세요. 샘플 번역은 미리보기 fixture로만 두고 Excel 검수 상태를 변경하지 마세요.

일본어는 Pretendard JP와 ja locale을 우선하고, 실제 누락 한자는 일본 자형 보조 폰트 → 플랫폼 폴백으로 처리하세요. 한국어 패밀리를 전 언어의 공통 CJK 폴백으로 두지 마세요. 다른 문자권도 05_LOCALIZATION의 순서를 적용하세요. 엔진/OS 폴백과 앱 등록 폰트를 구분하고, 숫자·혼합 문자열·이모지의 원래 클러스터 단위 표시를 보존하세요.

## 6. 공유 이미지 계약
이번 구현은 폰트·타이포그래피의 공용 진입점까지입니다. 후속 공유 구현이 결과 타입명, 포메이션 설명, 캐치프레이즈, 안내 문구에 같은 매핑을 요청할 수 있어야 합니다. Flutter 캡처는 해당 언어 폰트 준비 및 레이아웃 완료 후 수행합니다. 서버 생성은 파일 해시·locale·굵기·줄 높이를 일치시키고 일본어 자형·복합문자 shaping·이모지 폴백을 별도 검증합니다. 서버 도입이나 카카오톡 연동은 이번 인수 조건에 포함하지 않습니다.

## 7. 직접 실행할 검증과 인수 조건
D:\AppYou\app에서 아래 명령을 실행하세요.

~~~powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
flutter run -d chrome -t lib/ui_preview.dart
flutter build web --release
~~~

각 run 세션을 확인한 뒤 종료하고 다음 명령을 실행하세요. 다음 항목을 자동 테스트와 실제 렌더링으로 나누어 보고하세요.

1. 단위·위젯 테스트로 9개 매핑, pt_BR 정규화, 잘못된 저장값, 테마 상속, 굵기 네 단계, 저장 복원·연속 전환·실패 후 재시도를 검증합니다. 테스트 엔진의 대체 글꼴만으로 실물 자형 통과를 선언하지 마세요.
2. Chrome에서 ko/en/ja/pt-BR을 바꾸고 새로고침 후 복원, 선택한 답과 현재 문항 보존을 확인합니다. es/id/vi/th/hi는 미리보기에서 실제 폰트를 로드합니다. 브라우저에서 파일 요청 또는 로더 성공을 확인하고 특정 폰트가 필요한 문자열은 배포 바이너리 cmap 및 렌더링 이미지를 함께 점검합니다.
3. 05_LOCALIZATION의 언어별 예문으로 검증합니다. vi는 같은 문장의 NFC/NFD에서 겹성조·모음 위치를 대조합니다. ja는 骨·直·令의 획과 점을 공식 JP 견본과 나란히 봅니다. th의 ผู้เล่น·หนึ่ง은 위아래 기호의 겹침과 두 줄 경계, hi의 कि·क्ष·दृष्टि는 선행 모음 위치와 자음 결합을 봅니다. 단순 코드포인트 존재만으로 통과시키지 마세요.
4. 320·360 너비 모바일과 PC 최대 콘텐츠 폭 520, 100%·200% 글자 확대를 확인합니다. 구별 기호 상하 잘림, 버튼 레이블과 아이콘 겹침, 오버플로, 로드 후 위치 이동을 봅니다. Web 줌과 Flutter TextScaler 검증을 구분하고, 가독성은 줄바꿈·여백으로 확보합니다.
5. 선택 언어 폰트의 요청을 차단하거나 실패를 주입합니다. 실패 중 읽기·선택, 재시도 후 복구, 다른 언어 전환을 확인합니다. 설치된 시스템 글꼴이 실패를 숨긴 결과를 기록하지 마세요.
6. release 빌드를 정적 서버로 제공해 Chrome Network 기록을 남깁니다. 비교 조건(브라우저·네트워크·캐시)을 고정하고 패밀리별 원본 바이트, build/web에 포함된 파일과 총 바이트, 첫 방문 각 언어의 실제 전송량·요청 수, 폰트 준비 시점, 전환 시 추가 전송, 재방문 캐시를 표로 보고하세요. 기본 4언어 첫 진입 시 선택되지 않은 대형 CJK 폰트 요청은 0건을 목표로 합니다. 엔진의 자체 폴백 요청도 따로 집계하세요. 전체 배포 크기와 첫 방문 전송 크기를 구분하세요.
7. Android/iOS는 가능한 기기에서 같은 예문의 굵기·기호·폰트 실패를 검증하고, 환경이 없으면 플랫폼별 미검증으로 기록하세요. 소스·라이선스·해시, 변경 파일, 명령 결과, 실제 확인 화면, 실패·미확인 범위를 보고하면 완료입니다.
