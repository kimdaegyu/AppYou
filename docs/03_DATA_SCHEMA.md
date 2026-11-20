# Excel 및 JSON 계약 · 초안 0.2.0
한 행은 한 버전의 한 레코드다. 아래 물리 열 이름을 기준으로 읽는다. 요청 명칭 Version/Enabled/Order/Axis/TypeId는 각각 기존 DataVersion/IsActive/SortOrder/DimensionId/ResultTypeId에 대응한다. DescriptionKey는 진단 소개의 경우 IntroTextKey, 문항 TextKey는 PromptTextKey다.

## 공통 필드
|필드|형식과 의미|
|---|---|
|QuizId|문자열. 진단의 불변 ID. Strings에서만 common 예약값 허용|
|DataVersion|문자열 major.minor.patch. 4개 파일이 같은 배포 묶음을 참조|
|SortOrder|양의 정수. 진단 목록, 진단별 문항·축·결과·문구, 척도별 선택지의 표시 순서|
|IsActive|Excel 불리언. 부모 공개 여부와 자식 사용 여부를 각각 표현|

## 파일별 필드
아래 열에 위 공통 4개가 더해진다. Key로 끝나는 필드는 문자열이며 같은 범위·버전의 Strings.Key를 가리킨다.

|파일 / 시트|추가 열과 의미|
|---|---|
|QuizData / Quizzes|TitleTextKey 이름, IntroTextKey 소개, ScoreMode 채점 전략(independent_sum/pending), CompletionPolicy 완료 조건(all_required/pending), ResultRuleStatus 판정 승인 상태(pending/approved), ResultTemplateId 화면 식별자, QuestionCount 활성 문항 수(0 이상 정수)|
|QuizData / Dimensions|DimensionId 축 ID, NameTextKey 이름, RoleTextKey 포지션 이름(없으면 빈 셀). 네 가지 부의 축은 설계 메타데이터다.|
|QuestionData / Questions|QuestionId 고정 ID, PromptTextKey 문항 본문 키, ScaleId 척도 그룹, DimensionId 기여 축, Weight 양의 유한수, Reverse 역채점 불리언, ReviewStatus draft/reviewed. 검수 여부는 문항 편집 승인 상태를 뜻한다.|
|QuestionData / Options|OptionId 선택지 ID, ScaleId 그룹 ID, LabelTextKey 응답 문구 키, ScoreValue 수치. 척도는 옵션을 ScaleId로 그룹화해 정의한다.|
|ResultTypeData / ResultTypes|ResultTypeId 타입 ID, NameTextKey 이름, Formation 표시 문자열, ShareTextKey 공유 메시지 키, DesignStatus candidate/approved, DescriptionKey 설명 키, CatchphraseKey 카드 한 줄 키, ResultTemplateId 화면 ID. 0.2.0의 화면 ID는 상위 진단과 같아야 한다.|
|Localization / Strings|Key 불변 문구 키, ko/en/ja/pt-BR 문자열(미번역 셀은 비움), koStatus/enStatus/jaStatus/pt-BRStatus 각각 missing/draft/reviewed.|

## 참조 및 버전
Quizzes 기본키는 (QuizId, DataVersion). 자식은 여기에 테이블별 ID를 더한다. Strings는 (DataVersion, Key)를 고유하게 유지하고 키의 접두사와 QuizId 범위를 일치시킨다. 같은 의미의 ID는 버전 간 유지하되 폐기한 ID를 새 의미로 재사용하지 않는다. SortOrder는 ID로 쓰지 않는다. 이 묶음에서는 질문과 척도 선택지, 진단 축을 (QuizId, DataVersion) 안에서 연결한다.

0.1.0에서 원본 이름과 레코드 ID를 유지한 채 0.2.0에 새 열과 문구를 추가했다. 배포한 버전은 수정하지 않고 Git 이력과 버전별 번들을 보존한다. 점수·판정·문항 의미·번역이 바뀌면 새 DataVersion으로 묶어 재발행한다. 번들 구조 자체의 호환성은 별도의 정수 schemaVersion으로 관리한다. 저장 결과의 식별자는 QuizId + DataVersion + ResultTypeId이며 재방문 때 최신 버전으로 재판정하지 않는다.

## 채점
응답은 QuestionId에 대해 같은 ScaleId의 OptionId 하나만 가진다. 정방향 원점수는 ScoreValue, Reverse=true면 같은 척도의 최솟값 + 최댓값 − ScoreValue다. 축 점수는 그 원점수를 L·U로 정규화한 가중 평균이고, 원점수 합 Σ(w×x)는 따로 둔다. 등가중 6문항이면 원점수 합은 6~30이다. 응답 수정 시 해당 문항은 한 번만 반영한다. 18을 엔진에 고정하지 않고 활성 문항 목록에서 읽는다. all_required에서는 미응답 결과를 산출하지 않는다.

## JSON 출력 계약
`python tools/data/build.py`가 `app/assets/data/<DataVersion>/`에 쓴다. 요청서의 `app/assets/generated/`는 쓰지 않고 이 기존 경로를 출력 위치로 둔다. 구조 버전은 정수 `schemaVersion`이다. 규칙이 없는 0.2.0은 1, 규칙이 있는 0.3.0은 2다. Excel의 DataVersion 문자열과 별도다. 파일 내 참조는 ID와 문자열 키로 유지한다. JSON 키는 정렬해 같은 입력이 같은 바이트가 되게 한다.

|경로|내용|
|---|---|
|preview/|비활성·초안·후보를 유지한 편집 번들. 개발 미리보기가 읽는다|
|release/|출시 조건을 통과한 진단과 reviewed 문구만. 현재 0.2.0은 진단 0개|
|report.json|제외 이유, 미검수 개수, 기계 초안 개수. 앱 에셋으로 등록하지 않는다|

수식 셀은 계산하지 않고 오류다. 값은 Excel에 저장된 리터럴만 읽는다. 실패하면 출력 폴더를 교체하지 않는다.

Strings에는 선택 열 `koOrigin`, `enOrigin`, `jaOrigin`, `pt-BROrigin`을 둘 수 있다. 값은 `human` 또는 `machine`이다. 비어 있으면 출처를 기록하지 않은 것이다. 출시 조건은 출처가 아니라 status가 `reviewed`인지로 판단한다.

|출력|예정 필드와 형태|
|---|---|
|catalog.json|schemaVersion 1, dataVersion 문자열, channel preview 또는 release, quizzes 배열. 각 항목은 quizId, titleTextKey, introTextKey, questionCount, resultTemplateId, sortOrder와 상태 필드 isActive, scoreMode, completionPolicy, resultRuleStatus|
|quizzes/<QuizId>.json|schemaVersion, dataVersion, quizId, scoreMode, completionPolicy, resultRuleStatus, resultTemplateId, dimensions[], questions[], options[], resultTypes[]. 각 레코드 필드는 Excel 열을 lowerCamelCase로 매핑한다. 예를 들어 questions의 reverse는 불리언, weight는 수치다. resultTypes의 formation은 문자열이다.|
|locales/<언어코드>.json|schemaVersion, dataVersion, locale, strings, statuses. 값이 있는 출처는 origins. 출시 파일은 reviewed 문구만 담고, 없으면 strings가 빈 객체다. `{current}`, `{total}` 같은 치환 변수는 언어 사이에 집합이 같아야 한다.|

미리보기 출력은 `preview/`에 생성하고 비활성·미검수 여부를 유지한다. RuleStatus가 pending인 진단은 결과를 자동 선택하지 않으며, 이번 단계에는 선택 엔진 자체가 없다. 출시 출력은 활성 부모, 승인된 판정, 지원 템플릿 `football_formation`, reviewed 문항, 승인된 활성 결과 타입, 출시 4언어의 reviewed 문구를 모두 갖춘 진단만 포함한다. 공통 문구도 reviewed가 아니면 출시 locale에 넣지 않는다. 현재 출시 카탈로그의 진단 수는 0이다.

0.2.0은 schemaVersion 1이다. 진단 JSON에 rule이 없고 앱은 목록·문구만 읽는다. 0.3.0은 schemaVersion 2다. life_tactics만 ResultTypeData의 RuleSets·RuleMappings를 rule 객체로 싣는다. wealth_four의 rule은 null이다. 규칙 필드은 ruleVersion, strategy, balanceMaxRange, dominanceMinGap, tiePriority 배열, mappings 배열이다. 매핑은 kind, firstDimensionId, secondDimensionId, resultTypeId다. 균형은 두 축이 null이고 단독은 둘째 축만 null이다.

파일럿 규칙 버전은 `life_rank_v1_preview`, 전략은 `range_gap_rank`, 균형 상한 12, 단독 하한 20, 동점 순서는 happiness, meaning, richness다. ResultRuleStatus는 pending이라 출시 번들에서 빠진다. 문항은 추천본 lt_vp01–lt_vp18만 활성이다. 가중치 1, 역채점 없음, 한국어 draft, 나머지 언어 missing이다. 0.2.0 행은 수정하지 않고 같은 참조를 0.3.0으로 복사했다. 검토 통합 문서는 `docs/`에만 둔다.

채점은 활성 척도의 최솟값 L, 최댓값 U와 응답 v로 정방향 x=v, 역방향 x=L+U−v를 만든 뒤 `100 × Σ[w × (x−L)/(U−L)] / Σw`를 유리수로 비교한다. 원점수 합 Σ(w×x)는 별도 필드다. 표시만 소수 첫째 자리 half-up이다. 최고−최저 ≤ 12이면 balance, 아니면 1위−2위 ≥ 20이면 dominant, 나머지는 mixed다. 매핑이 없으면 결과를 만들지 않는다.

## 직렬화 인수 조건
1. 파일·시트·열 및 자료형을 확인한다. 필수값 누락, 수식 셀, 허용 목록 밖의 상태, 날짜로 바뀐 Formation은 행·열 위치를 붙여 오류 처리한다.
2. 기본키·정렬 순서 범위 내 중복, 다른 버전·진단의 참조, 고아 축/척도/문구 키를 검출한다. QuestionCount는 실제 활성 문항 수와 같아야 한다.
3. 출시 진단은 승인된 판정 규칙, 지원 템플릿, reviewed 문항과 승인된 활성 타입을 요구한다. 비활성 부모의 문항이 단독으로 노출되지 않아야 한다.
4. 표기 언어별 missing과 빈 셀의 일치, reviewed 본문의 존재, 원문과 번역의 치환 변수 집합 일치를 확인한다. 미리보기와 출시의 검수 기준을 구분한다.
5. 5점 척도에서 1·3·5의 역채점은 5·3·1이다. 전체 최저·최고, 응답 변경, 동률을 시험한다. 승인된 판정은 가능한 모든 점수 조합에서 결과가 정확히 하나이고 후보 타입 모두 도달 가능한지 검사한다.
6. SortOrder와 ID로 출력을 결정적으로 정렬하고 UTF-8 JSON으로 쓴다. 모든 검증이 끝난 뒤 묶음을 교체한다. 실패한 실행이 이전 정상 번들을 훼손하면 안 된다.
