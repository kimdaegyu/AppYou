# 파일럿 결과 피드백 · Cursor 구현 요청

## 사용자 흐름

나의 인생 전술 파일럿을 마친 사용자가 결과를 읽고 원할 때 한국어 Tally 설문에 참여한다. 폼은 운영자가 발행·확인했다. 설문 작성과 응답 보관은 Tally가 담당한다.

1. `app/lib/features/life_tactics/pilot_pages.dart`의 `PilotResultPage`에 ‘결과에 의견 보내기’ 보조 버튼을 추가한다. 결과 설명과 장면 요약 뒤, 하단의 공유 카드 미리보기 다음에 배치한다.
2. 버튼 근처에 ‘한국어 설문이 새 탭에서 열려요.’를 표시한다. 앱의 기존 지원 언어에서 버튼과 안내는 해당 언어의 번역 정책을 따른다. 사용자 문구는 Localization.xlsx와 기존 생성 경로로 관리한다.
3. 완료한 파일럿 결과에만 표시한다. 버튼을 누른 순간 새 탭으로 설문을 열고 원래 탭의 결과·스크롤·응답을 유지한다. 링크 열기를 응답 제출로 기록하지 않는다.

## 연결 규격

기본 주소는 `https://tally.so/r/kbN9YR` 한 곳에서 관리한다. 현재 화면에 표시된 QuizOutcome에서 아래 세 값만 읽어 Dart Uri의 queryParameters로 구성한다.

| Tally Hidden field | Flutter 값 |
|---|---|
| quiz_id | outcome.quizId |
| data_version | outcome.dataVersion |
| result_type_id | outcome.resultTypeId |

예시 주소는 `https://tally.so/r/kbN9YR?quiz_id=life_tactics&data_version=0.9.0&result_type_id=tr10`이다. 버전과 타입은 회차마다 동적으로 가져온다. 점수·문항별 답·장면 응답·세션 ID·사용자 식별자는 전달 대상에서 제외한다.

기존 외부 링크 처리 방식과 웹 조건부 구현을 먼저 확인한다. 탭 열기는 사용자의 클릭에서 직접 실행하고 opener 및 referrer 전달을 차단한다. 열기 실패가 확인되면 같은 링크를 다시 열 수 있게 한다. 새 탭의 핸들이 없다는 사실만으로 실패를 표시하지 않는다. Tally API 키, 자체 DB, 제출 확인 콜백은 필요하지 않다.

## 완료 기준

- 단위·위젯 테스트에서 서로 다른 결과 타입과 데이터 버전으로 생성된 주소의 호스트·경로·세 파라미터를 확인한다. 결과 화면을 표시하기만 하면 외부 호출이 없어야 한다.
- Chrome에서 대표 결과 한 건으로 버튼을 눌러 설문이 새 탭에 열리는지, 주소가 실제 결과와 일치하는지, 원래 탭으로 돌아왔을 때 같은 결과가 유지되는지 확인한다. 테스트 중 운영 설문에 응답을 제출할 필요는 없다.
- 모바일 폭에서 버튼과 안내의 줄바꿈을 확인한다. D:\AppYou\app에서 flutter analyze와 flutter test를 실행하고, 변경 파일·자동 테스트·실제 브라우저 확인 결과를 구분해 보고한다.
