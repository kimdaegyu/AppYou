# Cursor 구현 요청 · 나의 인생 전술 상황 선택 파일럿

D:\AppYou에서 다음 비교 실험을 개발 미리보기에 구현해 주세요. 같은 사람이 기존 18문항에서는 세 성향 모두에 높은 점수를 주더라도, 하나만 고르는 장면에서 우선순위가 드러나는지 확인합니다. 첫 테스트에서 의미 79.2, 행복·심리적 풍요로움 각 75.0으로 4-4-2가 나왔습니다. 이 한 사례로 실제 이용자의 유형 분포를 추정할 수 없습니다.

## 사용자 흐름

1. 기존 life_tactics 0.3.0의 18문항을 그대로 진행합니다. 마지막 답을 제출하면 기준 점수와 판정을 내부에서 계산합니다. 참가자에게 기준 결과를 먼저 보여주면 이어지는 선택에 영향을 줄 수 있으므로 두 단계가 끝난 뒤 공개합니다. 비교용 상황 데이터가 없는 구버전에서는 기존 완료 흐름을 사용합니다.
2. 진행률을 새로 시작해 “상황 속 나의 선택” 1/6부터 6/6까지 보여줍니다. 6개 장면마다 세 가지 매력적인 행동 중 하나만 고릅니다. 선택 전에 축·점수·포메이션을 노출하지 않습니다. 실제 표시 순서는 ScenarioOptions.SortOrder를 따릅니다. 편집본에서 각 축은 각 위치에 정확히 두 번씩 등장하므로 세션 도중 추가로 섞을 필요가 없습니다.
3. 답변은 ScenarioId → OptionId로 한 개씩 저장합니다. 미선택 시 다음/완료 차단, 이전 이동·답 교체·언어 전환 시 선택 유지, 1번 장면에서 이전으로 가면 기존 18번째 문항으로 복귀, 전체 재시작 시 두 단계 모두 초기화합니다. 기본 답을 수정하면 최종 제출 시 기준 결과를 다시 계산합니다.
4. 결과 카드 하나에 기존 전술명·포메이션·3축 점수와 기존 판정 이유를 먼저 보여주고, 그 아래 세 축별 선택 횟수(합계 6)와 요약 한 줄을 표시합니다. 판정은 기존 12/20 규칙 그대로입니다. 횟수는 독립 점수에 가산하거나 동점 해소에 쓰지 않습니다. 개발 컴포넌트 샘플의 결과명과 시작 대사가 파일럿 결과와 함께 보이지 않도록 파일럿 진행 화면을 분리하거나 해당 상태에서 샘플을 숨깁니다.

## 이미 작성된 Excel과 출력 계약

- QuestionData.xlsx의 Scenarios 6행과 ScenarioOptions 18행, Localization.xlsx의 PilotStrings 34행이 원본입니다. scope는 QuizId=life_tactics, BaseDataVersion=0.3.0, PilotVersion=scenario_v1입니다. 기존 Questions/Options/Strings와 자료형·의미가 다른 별도 시트입니다. 18문항의 QuestionCount, 기존 번들 및 규칙 버전을 유지합니다.
- Scenarios의 키는 scope + ScenarioId입니다. SortOrder, PromptTextKey, IsActive를 읽습니다. ScenarioOptions는 같은 scope와 ScenarioId에 연결하고 OptionId, SortOrder, DimensionId, LabelTextKey를 읽습니다. PilotStrings는 scope + Key를 기준으로 ko, en, ja, pt-BR와 각 언어 Status를 읽습니다. UI 고정 키는 life_tactics.scenario.ui.* 입니다. 기존 공통 이전·다음·재시작·축 이름 키를 재사용합니다.
- 기존 tools/data/lookatyou의 원본 읽기·검증·직렬화와 build/validate 진입점을 확장합니다. preview 전용으로 app/assets/data/0.3.0/preview/pilots/life_tactics/scenario_v1.json을 생성하고 pubspec에 등록합니다. JSON에는 quizId, baseDataVersion, pilotVersion, 정렬된 scenarios(각 options 포함), locales(언어별 strings/statuses)를 담습니다. 기존 quiz JSON을 수정해야만 열리는 구조를 피하고, release 경로에는 파일럿을 출력하거나 앱에서 로드하지 않습니다. 수기 JSON 수정 금지.
- 현재 3개 시트를 모두 제공하는 경우에만 이 파일럿을 생성합니다. 일부만 있거나 scope 불일치, ID/순서 중복, 없는 축·질문·텍스트 참조, 선택지 누락, 비어 있는 한국어, 치환 변수 불일치는 행과 열을 포함한 검증 오류입니다. 기존 파일럿 없는 입력은 정상 처리합니다. 해당 scope마다 활성 장면 6개, 장면당 3개 선택지가 세 활성 축에 정확히 하나씩 연결되는지 검사합니다. Flutter는 배열 길이를 읽어 진행률을 계산합니다.
- 미번역 언어는 missing으로 유지하고 미리보기에서는 기존 정책에 맞게 한국어로 폴백합니다. UI 요약에 쓰는 {axis}, {axes}, {count}, {current}, {total}은 표시 시점에 치환합니다. 전술 판정의 TiePriority로 상황 선택의 공동 1위를 깨지 않습니다. 2·2·2는 balanced, 3·3·0은 tie, 나머지 단독 최다는 lead 문구를 씁니다. 빈도 1위가 겨우 한 번 앞선 경우에도 성격이나 새로운 타입으로 단정하지 않습니다.
- 기존 app/lib/features/catalog, features/quiz/quiz_session.dart, quiz_engine.dart, ui_preview.dart를 먼저 확인합니다. 기존 엔진은 기본 18개 답만 받습니다. 상황 집계는 위젯에 의존하지 않는 작은 함수로 분리하고 세션과 위젯은 위치·응답·렌더링만 담당합니다. 일반 진단에 축 3개·상황 6개 조건을 강제하지 않습니다.

## 관찰 기록

파일럿 결과 화면에 개발자용 ‘기록 복사’를 제공한다면 별도 개발 도구 영역으로 구분합니다. 최소 인수 조건은 완료 직후 로컬 디버그 출력으로 한 회차 JSON을 얻을 수 있는 것입니다. quizId, baseDataVersion, ruleVersion, pilotVersion, 기본 QuestionId→OptionId, dimensionScores, baseResultTypeId, ScenarioId→OptionId, 축별 선택 횟수를 포함합니다. 사용자 식별 정보나 서버 전송은 필요하지 않습니다. 이 기록으로 기본 문항별 4·5번 비율과 4-4-2 응답자 중 상황 선택이 한 축에 집중된 사례를 같은 회차 단위로 볼 수 있어야 합니다.

## Cursor가 실행할 검증과 완료 조건

- 기존 Python·Flutter 테스트를 유지합니다. 모든 기본 답 4 → 세 축 75점, tr10. 같은 기본 답에 상황 선택 6회 전부 richness → 풍요 6회, 4-4-2 유지. 상황 응답 3·3·0 → 공동 1위 둘, 2·2·2 → 세 축 동률, 3·2·1 → 단독 최다. 하나를 이전 화면에서 바꾸면 정확히 한 표가 이동하고 총합은 6입니다. 중복 제출·잘못된 OptionId·다른 장면의 OptionId는 추가 집계하지 않습니다.
- 중간 화면을 왕복한 뒤 언어 변경, 전체 재시작, 번역 누락, 구버전 진단, 비활성 장면, 일부 시트 누락, release 파일럿 부재를 검증합니다. 미리보기 화면에 실제 18+6문항을 연결한 위젯 테스트로 시작부터 결과까지 최소 한 번 완주합니다.
- 프로젝트 루트에서 python tools/data/validate.py, python tools/data/build.py, python -m unittest discover -s tools/data/tests를 실행합니다. app에서 flutter analyze, flutter test, flutter run -d chrome -t lib/ui_preview.dart를 실행해 모바일 폭과 PC 폭에서 마지막 답 제출·카드 중복·문구 잘림을 확인합니다.
- 실행한 명령·결과·미실행 사유와 완료 기록 한 예를 보고합니다. 실제 파일럿에서 응답 피로, 선택 이유, 두 결과에 대한 공감을 받아 본 뒤 정식 12+6 구성이나 판정 반영을 결정합니다. 이번 작업은 18+6 비교용 미리보기까지입니다.
