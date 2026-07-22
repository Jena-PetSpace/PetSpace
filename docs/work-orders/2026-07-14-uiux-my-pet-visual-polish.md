# 작업지시서 초안: MY 탭 Visual Polish 1 — 반려동물 관리·등록·수정

- 상태: 구현·자동 검증·Claude Opus 4.8 독립 리뷰 완료, blocker/high 0, 사람 실기기 검증 대기
- 선행 완료: UI/UX Wave 1C `20260714-UIUX-wave1C-pet-flow-B-f2b6`
- 근거: 2026-07-14 사용자 실기기 캡처 3장
- 구현자 초안: Codex
- 독립 리뷰: Claude Opus 4.8
- commit·merge·push·deploy·운영 DB 작업: 금지

## 목표

Wave 1C에서 확정한 전체 화면 2단계 등록, 수정, 여권 draft, 동일 PetBloc, 라우팅과 저장 계약은 그대로 유지한다. 실기기에서 확인된 과한 세로 여백, 반복되는 정보 위계, 강한 파란 테두리, 약한 보조 정보 대비만 다듬어 MY 탭 안에서 설정 화면과 같은 밀도와 신뢰감을 만든다.

## 이번 범위에서 하지 않는 것

- 하단 5탭의 구조, 높이, 중앙 버튼, 아이콘, 라벨, 선택 상태, 색, 배지 수정
- `pjh/lib/main_navigation.dart` 및 하단 내비게이션 관련 파일 수정
- 설정 화면 재디자인
- 홈·AI 분석 보호 화면 수정
- 기능 의미, 라우트, PetBloc event/state, domain/data/Repository/DI, DB/API, 이미지 업로드 계약 변경
- 등록 단계를 늘리거나 여권·필수 입력 정책을 변경

## 구현 후보 manifest

목업과 사용자 승인 뒤 아래 범위만 구현 후보로 삼는다. Claude 리뷰에서 정확한 테스트 범위를 함께 확정한다.

### 수정 후보

1. `pjh/lib/features/pets/presentation/pages/pet_management_page.dart`
   - 기준 SHA-256: `4f18e17fd1561611845608c178f725bb2b57a45991d413c3737f9586ed47347c`
2. `pjh/lib/features/pets/presentation/widgets/pet_card.dart`
   - 기준 SHA-256: `a0a16f07755ace4ba5c41ef45bf8dc2d0ee0a26e61b8706a88a631bbd3f721b9`
3. `pjh/lib/features/pets/presentation/pages/pet_editor_page.dart`
   - 기준 SHA-256: `7d107166549b12da77ca7c25a59a2777923dc93e578fda003b7377648300fe9d`
4. `pjh/test/features/pets/presentation/pages/pet_editor_page_test.dart`
   - 기준 SHA-256: `8f7c6f9377f68c28ed61d7487db5afb883423dcbe64f2f9d7c627c7117e493b0`

### 생성 후보

5. `pjh/test/features/pets/presentation/widgets/pet_card_test.dart`
6. `pjh/test/features/pets/presentation/pages/pet_management_page_test.dart`

## 핵심 화면 4개

1. 반려동물 관리 목록
2. 신규 등록 1단계 기본 정보
3. 신규 등록 2단계 추가 정보
4. 반려동물 정보 수정

여권 관리 화면은 구조와 입력 계약을 유지하고, 수정 화면과 공통 토큰 변경으로 직접 영향을 받을 때만 회귀 검증한다.

## 제안 시각 계약

### 관리 목록

- 추가 CTA는 44px 이상 터치 영역을 유지하되 강한 파란 외곽선 대신 옅은 action container와 절제된 아이콘·텍스트를 사용한다.
- 기본 카드는 중립 1px 경계다. 대표 카드는 얇은 action 경계와 `대표` chip만 사용하고 옅은 action surface를 겹치지 않는다.
- `대표`, 이름, 종류 badge, 품종, 나이·성별의 우선순위를 명확히 하고 badge와 원형 배경의 수를 줄인다.
- 더보기는 44px 터치 영역을 유지하되 큰 원형 배경은 제거하거나 투명 처리한다.
- 품종·나이·성별은 라이트·다크 모두 WCAG 대비를 해치지 않는 onSurfaceVariant 역할색을 사용한다.
- 리스트 하단은 기존 5탭 UI를 건드리지 않고 콘텐츠 padding만 확보해 마지막 카드가 가려지지 않게 한다.

### 등록 1단계

- 상단 단계명은 `기본 등록`이 아니라 `기본 정보`로 통일한다.
- 단계명 `기본 정보`는 화면당 한 번만 노출한다. 폼 section 제목은 제거하고 헤드라인은 `먼저 꼭 필요한 것만 알려주세요`로 바꿔 반복을 없애며 18sp 역할로 낮춘다.
- 사진은 88~92px preview와 `사진 추가 · 선택`을 한 덩어리로 묶어 세로 점유를 줄인다. 선택·변경·권한 의미는 유지한다.
- 이름 50자 제한과 validator는 유지한다. 카운터는 입력 필드와 시각적으로 붙여 정렬한다.
- 이름 필드 56px 전후, 종류 선택·하단 CTA 52px 전후를 기준으로 하되 모든 터치 영역은 44px 이상이다.
- 페이지 좌우 20, 주요 section 24, 필드 간 12~16 역할을 일관되게 적용한다.

### 등록 2단계·수정

- 1단계와 동일한 progress, section, 필드, CTA 밀도를 사용한다.
- 선택 항목, `건너뛰기`, nullable 비우기, passport notice/draft, 기존 데이터 prefill 의미는 바꾸지 않는다.
- 사진을 상단 compact identity block으로 묶되 수정 화면에서는 이름을 identity heading과 편집 필드에 중복 노출하지 않는다. 나머지 필드는 읽기 순서대로 배치한다.
- 하단 고정 CTA와 키보드·SafeArea 계약을 유지한다.
- 여권 row의 상태 문구와 국가코드는 현재 계약인 `선택 정보 · KOR` / `등록됨 · KOR` 또는 기존 값 그대로 유지하고, 목업 때문에 문구를 새로 바꾸지 않는다.
- 등록 2단계 인트로와 여권 안내는 현행 동결 문구 `조금 더 알려주시면 기록이 정확해져요` / `여권 정보는 등록 완료 후 반려동물 상세에서 만들 수 있어요.`를 그대로 유지한다.

## 기능 불변 계약

- 네 진입점, 전체 화면 라우트, 하단 탭 없는 editor, Android back 의미 유지
- `AddPetEvent`/`UpdatePetEvent`, 성공 단일 pop, 오류 입력 유지·재시도, 중복 제출 방지 유지
- 이미지 picker 512/512/70, draft petId와 업로드 URL 재사용 유지
- nullable 품종·성별·생년월일 비우기와 MBTI/passportNo 등 미편집 필드 보존
- 대표 설정, 수정, 삭제, 상세 진입과 목록 refresh 의미 유지
- 사용자 문구에 내부 예외 원문 노출 금지

## 목업·승인 게이트

1. Codex가 4화면 목업 초안을 작성한다.
2. Claude가 실기기 캡처, 작업지시서, 목업, 현재 코드와 동일 manifest를 read-only 리뷰한다.
3. 양쪽이 blocker/high 0과 동일 시각 계약에 동의한 합의 목업만 사용자에게 제시한다.
4. 사용자가 목업과 정확한 파일 범위를 승인하기 전에는 Flutter UI 코드를 수정하지 않는다.

### Claude Opus 4.8 비준 결과

- 최종 판정: `accept`
- blocker/high: 0
- 하단 5탭 불변: 확인
- 6파일 manifest 충분성: 확인
- 구현 가드레일: 단계명 변경과 폼 section 제목 제거를 함께 적용하고, avatar/photo label key와 44px 터치 계약을 보존하며, 등록 2단계·여권 안내 문구를 현행 그대로 유지한다.

## 구현·검증 사이클

1. 승인 후 Codex가 정확한 manifest 안에서 구현 초안을 만든다.
2. Claude가 같은 diff를 독립 리뷰한다. 불일치 또는 blocker/high는 자동 수정하지 않고 보고한다.
3. Codex가 format, `flutter analyze --no-pub`, 대상 widget test, 전체 기준선, `git diff --check`, manifest·보호 hash를 검증한다.
4. Claude가 코드와 검증 증거를 독립 리뷰한다.
5. Codex가 4화면 실기기 캡처 비교 체크리스트를 작성하고 Claude가 판정을 리뷰한다.
6. 사용자가 실기기 캡처를 최종 승인한 뒤 이 범위를 동결한다.

## 자동 테스트 요구

- 기존 `pet_editor_page_test.dart`의 18개 기능·접근성 계약 유지
- 등록 1단계의 `기본 정보`는 정확히 한 번 노출되고 기존 텍스트 어서션 의미를 유지
- 등록 1·2단계, 수정 화면 360×800 및 390×844에서 overflow 없음
- text scale 100%와 150%, 라이트·다크, 키보드 viewInsets에서 CTA 접근 가능
- PetCard 기본/대표, 긴 이름, 사진 성공·실패, 품종 없음, 성별 없음 상태
- PetCard 더보기 44px 이상과 대표·수정·삭제 callback
- 관리 화면 추가 CTA, 빈 상태, 1개·여러 개 목록, 마지막 카드 bottom padding
- populated 목록의 추가 CTA만 이번 manifest 안에서 조정하고 공유 `PetSpaceStateView`의 empty CTA는 수정하지 않음
- 하단 5탭 파일과 보호 hash 불변

## 사람 실기기 검증

- 제공 캡처와 동일 기기에서 관리 목록·등록 1·2단계·수정 전후 비교
- 작은 화면·기준 화면, 100%·130~150%, 라이트·다크, 키보드
- 사진 선택·변경·취소·권한 거부·느린 업로드
- 카드 1개·3개 이상에서 마지막 카드와 하단 5탭 겹침 여부
- TalkBack 읽기 순서와 44px 터치 영역

## 2026-07-14 구현·독립 리뷰 결과

- 구현: 승인된 6파일 manifest 안에서 완료
- `flutter analyze --no-pub`: `No issues found`
- 대상 테스트: editor 20/20, PetCard 3/3, management 4/4, 총 27/27 통과
- 전체 테스트: 396 pass / 기존 실패 14 / 신규 실패 0
- `git diff --check`: 통과
- 하단 5탭·home·emotion 보호 경로 변경: 0
- Claude Opus 4.8: `approve`, blocker/high 0, 시각·기능·테스트 계약 모두 승인, 실기기 검증 진행 가능
- 비차단 low: 극단적으로 긴 품종명의 1줄 축약 여부, 실제 popup open 경로 테스트 보강, 범위 밖 여권 국가 국기 이모지의 별도 정리 검토

## 중단 조건

- 하단 5탭 UI 또는 `main_navigation.dart` 수정 필요
- 기능·라우트·상태·데이터·법무 계약 변경 필요
- manifest 밖 앱 코드 수정 필요
- 보호 hash 불일치, 신규 analyzer/test 실패, overflow·대비·접근성 악화
- Claude와 Codex의 목업·manifest·완료 조건 불일치
