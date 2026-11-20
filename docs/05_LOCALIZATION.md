# 다국어 편집과 출시
한국어(ko)가 원문이다. 언어 식별자는 ko, en, ja, pt-BR을 사용하고 JSON 파일명과 공유 링크에도 같은 표기를 유지한다. 일반 UI와 사이다 대사까지 Localization.xlsx/Strings에서 관리한다.

|키 범위|사용 예|
|---|---|
|common.ui.*|common.ui.quiz.progress의 {current}, {total}은 정수 치환값|
|common.saida.*|common.saida.middle은 절반 진행 안내|
|진단 ID + 용도 + 고정 ID|life_tactics.question.tq01, life_tactics.result.tr01.description|

같은 의미의 문구 수정은 키를 유지한다. 문항 의미나 채점이 바뀌면 데이터 버전을 올리고 이전 결과를 보존한다. 공통 문자열의 QuizId에는 예약값 common을 쓴다. 번역자는 ko를 기준으로 같은 행에 번역하고 해당 언어 상태를 갱신한다. missing은 빈칸, draft는 초안, reviewed는 검수 완료다. 한국어 원문 의미가 바뀌면 기존 번역을 재검토 대상으로 draft 처리한다.

편집 미리보기에서는 누락된 번역을 한국어로 대체하되 누락 상태를 표시한다. 출시 언어는 사용되는 필수 키가 모두 reviewed여야 한다. `en`, `ja`, `pt-BR`의 빈 칸에 넣은 기계 초안은 status를 `draft`, origin을 `machine`으로 두고 reviewed로 올리지 않는다. 다시 실행해도 이미 있는 문구는 덮어쓰지 않는다. 명령은 `python tools/data/apply_drafts.py`다. 출시 번들은 이 초안을 포함하지 않으며, `validate.py --strict-release`는 미검수 때문에 실패한다. es, id, vi, th, hi는 폰트 검수 언어라 번역 파일이 없고 미리보기는 한국어로 되돌린다. 미지원 언어 요청은 지원 언어 선택으로 연결한다. `pt_BR`은 `pt-BR`이 되고 `pt-PT`는 브라질 포르투갈어가 되지 않는다. 문항 번역은 행동의 방향과 강도를 유지하고 5단계 응답 순서를 보존한다. 결과 별명은 각 언어에서 자연스럽게 바꿀 수 있으나 타입 ID와 포메이션은 유지한다.

공유 이미지는 표시 언어의 별명·한 줄 문구를 같은 버전에서 읽어 생성한다. 긴 포르투갈어 문구와 한국어·일본어 줄바꿈을 카드 미리보기에서 확인한다. 공유 링크 언어와 번들 버전을 명시하고, 지원되지 않는 조합은 지원 언어로 안내한다.

## 언어와 폰트 선택

번역 출시 여부와 폰트 지원 여부를 따로 관리한다. Excel은 기존 문구와 번역 검수 정보를 유지하고 패밀리명·파일명은 Flutter의 AppFonts에서 관리한다. 아래 표는 구현 추천 기본값이며 실제 채택 파일은 글리프·굵기·렌더링 검수를 거쳐 고정한다.

| BCP 47 | 기본 패밀리 | 범위 | 글자 검수용 예시 |
| --- | --- | --- | --- |
| ko | Pretendard | 현재 번역 스키마 | 값·읽기·괜찮아요, 18문항 |
| en | Pretendard Std | 현재 번역 스키마 | What’s your formation? 4–4–2 |
| ja | Pretendard JP | 현재 번역 스키마 | 骨・直・令・返、きょうの作戦。カタカナ |
| pt-BR | Pretendard Std | 현재 번역 스키마 | São Paulo, ação, você, bênção |
| es | Pretendard Std | 추가 예정 | ¿Cuál es tu táctica? ¡Mañana! |
| id | Pretendard Std | 추가 예정 | Bagaimana caramu mengambil keputusan? |
| vi | Noto Sans | 추가 예정 | Tiếng Việt, Nguyễn, tưởng tượng, Ắ ẵ ộ ự Đ đ |
| th | Noto Sans Thai | 추가 예정 | ผู้เล่น น้ำ หนึ่ง กำลังใจ |
| hi | Noto Sans Devanagari | 추가 예정 | हिंदी खिलाड़ी दृष्टि क्ष त्र ज्ञ कि की |

Pretendard의 JP는 일본 환경용, Std는 라틴 환경용이다. Noto Sans는 Google Fonts 자료에 Vietnamese 범위가 명시되어 있어 베트남어 기본 후보로 삼는다. Std가 베트남어를 지원하지 않는다는 가정은 두지 않는다. 고정한 Std 파일이 NFC·NFD와 실제 문장 검수를 모두 통과하면 vi까지 공유하는 최적화를 비교할 수 있다. Thai·Devanagari 전용 패밀리는 복합 문자를 해당 문자권에서 검수하기 위한 선택이다. [Pretendard 공식 배포](https://github.com/orioncactus/pretendard) · [Noto Sans 메타데이터](https://github.com/google/fonts/blob/main/ofl/notosans/METADATA.pb) · [Thai](https://github.com/google/fonts/tree/main/ofl/notosansthai) · [Devanagari](https://github.com/google/fonts/tree/main/ofl/notosansdevanagari)

앱 시작 시 저장한 유효 언어 → 기기의 선호 언어 목록 중 지원되는 언어 → 프로젝트 기본 ko 순으로 해석하는 방식을 권장한다. 실제 사용자 메뉴는 출시 가능한 번역 언어만 표시하고, 개발 미리보기에서는 9개 코드를 선택할 수 있다. pt_BR 입력은 pt-BR로 정규화하고 영어·한국어·일본어 지역 변형은 해당 기본 언어에 연결한다. pt-PT를 pt-BR로 간주하는 정책은 별도 합의 전까지 자동 적용하지 않는다. 설정을 변경하면 번역과 폰트가 같은 locale 상태를 구독한다.

폴백 순서는 해당 문자권 기본 → 필요한 경우 같은 문자권 보조 → 라틴 기호·숫자 → 엔진/플랫폼 이모지·기타 폴백이다. 이미 로드된 적합한 패밀리를 재사용한다. ja의 한자에는 한국어 패밀리를 앞세우지 않는다. 기본 JP에서 빠진 실제 필수 글자가 발견되면 일본 자형을 가진 보조 패밀리(예: Noto Sans JP)를 검증해 추가한다. 글리프가 있으면 엔진은 다음 패밀리로 넘어가지 않으므로 ja 콘텐츠에는 locale도 ja로 전달한다. 미리보기에서 한국어 대체 번역을 보여줄 때는 그 문자열에 ko 언어·서체를 적용한다. 숫자 0–9, 4-2-4, 50%, ₩, R$, →, ⚽, 🐶, 피부색·ZWJ 조합도 점검한다. 이모지 외형은 플랫폼별로 다를 수 있다.
