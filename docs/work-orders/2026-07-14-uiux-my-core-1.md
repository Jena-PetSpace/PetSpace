# 작업지시서 초안: MY Core 1 — 실제 프로필·상태 신뢰도·반려동물 상세

- 작성일: 2026-07-14
- 상태: 12파일 구현·자동 검증·Codex 및 Claude Opus 4.8 독립 리뷰 완료, blocker/high 0, 사람 실기기 검증 대기
- 상위 감사: `docs/reviews/2026-07-14-my-tab-full-audit.md`
- 승인 목업: MY 메인, 반려동물 상세, 설정 허브, 저장 라이브러리, 프로필 편집
- 이번 구현 화면: MY 메인, 프로필 편집, 본인 반려동물 상세
- 구현 초안 담당: Codex
- 독립 검토: Claude Opus 4.8
- commit·merge·push·deploy·운영 DB 작업: 금지

## 1. 목표

MY 탭 첫 구현 단위에서 사용자가 바로 체감하는 신뢰 저하 요소를 제거한다.

1. MY 헤더의 가상 handle·레벨·포인트·고정 소개를 없애고 실제 프로필과 실제 통계만 보여준다.
2. 내 게시글·저장 게시글의 조회 실패를 성공한 빈 목록과 구분하고 안전한 재시도를 제공한다.
3. 프로필 편집을 승인 목업의 정보 위계와 기존 저장 계약에 맞게 정돈하고, 저장 후 MY 헤더가 갱신되게 한다.
4. 반려동물 상세의 과도한 hero·강한 원색·부정확한 `함께한 날` 표현을 정리한다.
5. 기존 분석·게시물 작성·정보 수정·삭제 동선과 PetBloc 갱신은 잃지 않는다.

## 2. 이번 단위의 제품 결정

### 2.1 MY 메인

- 이메일 로컬 파트로 만든 handle, `레벨 1 견주`, `0 P`를 표시하지 않는다.
- 실제 `ProfileService.getProfile()`의 bio가 있으면 표시한다.
- bio가 비어 있으면 사실을 꾸미지 않고 `소개를 작성해보세요` 편집 유도만 표시한다.
- posts·followers·following은 기존 쿼리와 실제 통계 계약을 유지한다. 조회 중·실패에는 가짜 0을 확정값처럼 표시하지 않고 재시도를 제공한다.
- 현재 `ProfileService.getProfileStats()`가 실패를 `0/0/0` 성공값으로 바꾸는 동작은 이 서비스의 유일한 호출자인 MY 헤더가 오류를 구분할 수 있도록 rethrow로 바꾼다. 쿼리·반환형·성공값은 변경하지 않는다.
- 데이터 계약이 확정되지 않은 `UserBadgesSection`은 이번 MY 메인에서 마운트하지 않는다. 현재 위젯은 획득 내역이 없어도 잠긴 뱃지 전체를 렌더하므로 verify-only로는 목표를 충족하지 못한다. 위젯 파일과 데이터 코드는 삭제하지 않는다.
- MBTI·반려동물 요약의 기존 비노출 플래그는 그대로 유지한다.
- 저장 탭은 현행 단일 그리드와 라우트를 유지한다. 컬렉션 정본 통합은 다음 manifest로 분리한다.
- 이미지 없는 게시글의 문자 emoji `✍` 대체는 중립 아이콘/표현으로 바꾼다.

### 2.2 오류와 빈 상태

- MY의 두 Repository failure를 빈 `[]`로 바꾸지 않고 예외/실패로 UI 경계까지 전달하는 것은 **필수**다.
- 성공 응답이 빈 목록일 때만 `아직 게시글이 없어요` / `저장한 게시글이 없어요`를 표시한다.
- 최초 조회 실패에는 내부 예외 원문 없이 네트워크/일반 오류 안내와 `다시 시도`를 표시한다.
- 추가 페이지 조회 실패는 이미 보이는 항목을 지우지 않는다. 내부 예외 원문을 SnackBar에 노출하지 않는다.
- 공용 `LazyGridView`에는 오류 상태 추적·오류 렌더·재시도를 **필수 구현**한다. `MyPage`는 반드시 안전한 `errorWidget`을 전달한다.
- `errorWidget` 매개변수의 nullable/optional 성격은 기존 다른 호출부의 소스 호환성을 위한 API 형태일 뿐, 이번 MY 두 그리드에서 생략할 수 있다는 뜻이 아니다.

### 2.3 프로필 편집

- 기존 display name·bio·photo prefill과 `ProfileService.updateProfile` / `uploadProfileImage` / `AuthProfileRefresh` 계약을 보존한다.
- 사진과 텍스트 저장의 현재 부분 실패 의미를 바꾸지 않는다. 사진 업로드가 실패하면 텍스트 성공을 되돌리지 않고 화면에 남아 재시도할 수 있게 한다.
- 초기 로딩·초기 조회 실패·재시도·저장 중 중복 제출 방지를 명시적으로 표시한다.
- 승인된 공용 scaffold·색·간격 토큰을 사용해 compact avatar, 기본 정보, 하단 고정 CTA 순으로 정돈한다.
- 성공 시 `Navigator.pop(context, true)` 계약을 유지하고, MY 헤더는 반환값을 await한 뒤 실제 profile과 stats를 다시 조회한다.

### 2.4 본인 반려동물 상세

- 300px hero 대신 표준 top bar와 compact identity block을 사용한다.
- 사진 없음, 품종·생년월일 등 선택값 없음, 긴 이름/품종에서도 사실을 숨기거나 추정하지 않는다.
- `createdAt`은 관계 시작일이 아니므로 `함께한 날`로 표시하지 않는다. 이번에는 의미가 정확한 `등록한 날`과 절대 날짜 `yyyy.MM.dd`로 표시한다.
- 승인 목업의 높은 우선순위인 `정보 수정`을 직접 CTA로 제공한다.
- 기존 `감정 분석하기`와 `게시물 작성`은 보조 액션으로 유지한다. 새 AI 분석 히스토리 라우트는 만들지 않는다.
- 기존 overflow 수정·삭제, PetEditor route data, PetBloc success/list refresh, 상세의 최신 pet 반영을 보존한다.
- 삭제 확인은 검증되지 않은 cascade 범위를 약속하지 않고 `삭제하면 복구할 수 없습니다. 계속할까요?` 수준으로 한정한다. 삭제 event 자체는 변경하지 않는다.

## 3. 정확한 구현 manifest

아래 12개 파일만 허용한다. 기존 사용자 변경을 기준선으로 삼으며, 해시는 Claude 비준 직전 다시 확인한다.

### 수정 6개

1. `pjh/lib/features/my/presentation/pages/my_page.dart`
   - 기준 SHA-256: `c55572f75fcf64ee69d2e7a0f072b53abc88cfff715dbf140b28fdacaacd8d25`
2. `pjh/lib/features/my/presentation/widgets/my_profile_header.dart`
   - 기준 SHA-256: `2c80afa0580649e2f297ab40c1a8fe73a9d666fae8458c614a231dd63610d39e`
3. `pjh/lib/features/profile/presentation/pages/profile_edit_page.dart`
   - 기준 SHA-256: `84f7096ca0fa6773e72267fa479a3196060f193569f682301e237c07543b2ecb`
4. `pjh/lib/features/pets/presentation/pages/pet_detail_page.dart`
   - 기준 SHA-256: `ab7da76c0ae2291d3d493008cc12d30f42c547d45e82c1cc6f42d2162240ad85`
5. `pjh/lib/shared/widgets/lazy_load_list.dart`
   - 기준 SHA-256: `d57b023b153224c57ea29489ace905671c45ffb1a683fd3777ee924d51563d0f`
6. `pjh/lib/core/services/profile_service.dart`
   - 기준 SHA-256: `19c6b1b95be2c20ad4258264aade6007fe83b3e9495e20645b218ebf1dffec64`
   - 변경 제한: `getProfileStats()` 실패를 0 성공값으로 치환하지 않고 rethrow하는 것만 허용

### 생성 6개

7. `pjh/test/features/my/presentation/pages/my_page_test.dart`
8. `pjh/test/features/my/presentation/widgets/my_profile_header_test.dart`
9. `pjh/test/features/profile/presentation/pages/profile_edit_page_test.dart`
10. `pjh/test/features/pets/presentation/pages/pet_detail_page_test.dart`
11. `pjh/test/shared/widgets/lazy_load_list_test.dart`
12. `pjh/test/core/services/profile_service_test.dart`

## 4. 명시적 범위 제외

- 하단 5탭의 구조·높이·중앙 버튼·아이콘·라벨·색·배지와 `main_navigation.dart`
- 설정 허브 및 알림·개인정보·가이드라인·도움말 하위 화면
- 저장 게시글 컬렉션 통합·라우트 정본화
- 공개 반려동물 프로필과 공개 RLS/딥링크
- 푸시 발송 경로의 알림 선호도 적용
- 약관·가이드라인·운영 문구 정본 변경
- dark theme 제품 완성도 개선
- Router, domain/entity, Repository, DI, Supabase, Edge Function, DB/API/RLS 변경
- `UserBadgesSection` 파일 삭제나 리워드 데이터 모델 신규 설계

## 5. 보호·불변 계약

- 직접 수정 금지:
  - `pjh/lib/features/social/presentation/pages/home_page.dart`
  - `pjh/lib/features/home/**`
  - `pjh/lib/features/emotion/presentation/**`
- 하단 5탭 UI와 라우팅 의미를 유지한다.
- `/settings/my`, `/my/edit-profile`, followers/following, `/post/:id`, `/create-post`, `/feed` 동선을 보존한다.
- pet detail의 emotion/create-post/edit/delete 동선과 PetBloc event/state 의미를 보존한다.
- AI 결과 confidence·진단 표현, 법무 문구, 데이터 계약을 새로 만들지 않는다.
- 신규 임의 빨강과 raw exception 사용자 노출을 추가하지 않는다.
- PetBloc 삭제 성공의 문자열 판별은 이번 UI manifest에서 타입 계약으로 확대하지 않고 기존 의미를 회귀 테스트로 고정한다. 타입화는 별도 기능 wave 후보로 기록한다.

## 6. 자동 테스트 요구

### MY 메인·헤더

- 실제 bio가 표시되고 고정 소개, `레벨 1`, `0 P`, 이메일 기반 handle이 보이지 않는다.
- bio 없음 CTA, profile edit 반환 `true` 이후 profile/stats 재조회가 동작한다.
- posts/followers/following과 기존 세 라우트가 유지된다.
- 통계 조회 성공 0과 조회 실패가 구분되고, `ProfileService.getProfileStats()` 성공 쿼리·반환값과 실패 rethrow가 단위 테스트로 고정된다.
- 뱃지 section, MBTI, pet summary는 의도한 비노출 상태다.
- 내 글/저장 글: loading, 성공 empty, 성공 populated, failure, retry recovery가 서로 구분된다.
- raw Repository failure/exception 문자열이 화면이나 SnackBar에 보이지 않는다.
- 360×800, 390×844, text scale 100%·150%에서 overflow가 없다.

### 프로필 편집

- name·bio·photo prefill, validation, 저장 중 중복 제출 방지.
- 초기 load failure와 retry, 텍스트 저장 실패, 사진 업로드 부분 실패, 전체 성공 경로.
- 성공 시 `true` 반환과 `AuthProfileRefresh`; 실패 시 입력과 화면 유지.
- 키보드 viewInsets·SafeArea·150% text scale에서 하단 CTA 접근 가능.

### 반려동물 상세

- 사진 성공/실패/없음, 긴 이름·긴 품종, 선택값 없음에 overflow 없음.
- `등록한 날`과 절대 날짜가 보이고 `함께한 날`이 보이지 않는다.
- 정보 수정, 감정 분석, 게시물 작성, overflow 수정, 삭제 확인의 기존 callback/route 의미가 유지된다.
- PetEditor 성공과 PetBloc state 이후 표시 pet이 갱신된다.
- 삭제 확인에 `관련된 모든 데이터` 등 검증되지 않은 cascade 문구가 없다.
- 삭제 성공 pop과 실패 화면 유지가 현재 PetBloc message 계약에서 회귀하지 않는다. 문자열 기반 operation 판별은 별도 부채로 기록한다.

### 공용 LazyGridView

- 최초 load throw 시 empty가 아니라 errorWidget을 표시한다.
- retry 성공 시 error를 지우고 populated 또는 성공 empty를 표시한다.
- 추가 load 실패는 기존 items를 유지하며 raw exception을 노출하지 않는다.
- `errorWidget`을 지정하지 않은 기존 호출부의 loading/empty/grid/header/refresh 계약이 회귀하지 않는다.

## 7. 검증 명령과 증거

1. 승인 manifest 12파일 format
2. `flutter analyze --no-pub`
3. 신규 5개 대상 widget test와 영향받는 기존 MY/pet/shared widget test
4. 전체 `flutter test` 기준선 비교: 기존 실패와 신규 실패 분리
5. `git diff --check`
6. 허용 12파일 밖 app/test 변경 0 확인
7. 하단 5탭·home·emotion 보호 경로 hash 불변 확인
8. Codex diff 리뷰와 Claude Opus 4.8 독립 diff 리뷰 각각 blocker/high 0

## 8. 사람 실기기 검증

- MY 메인: 실제 bio 있음/없음, 통계 로딩/성공/실패, 내 글·저장 글 empty/error/populated
- 프로필 편집: 키보드, 사진 권한 거부, 사진 선택 취소, 느린 업로드, 부분 실패 후 재시도
- 반려동물 상세: 사진 있음/없음, 긴 텍스트, 누락 정보, edit 왕복, 분석·게시물 작성 왕복, 삭제 취소
- 테스트 계정에서 삭제를 검증할 경우 관련 감정·건강·게시글 데이터의 실제 보존/삭제 결과를 별도 기록한다. 이 결과가 확인되기 전 UI는 cascade 범위를 약속하지 않는다.
- 360급 작은 Android와 기준 기기, 100%·130~150% 글자 크기
- TalkBack 읽기 순서, 모든 주요 액션 44px 이상
- 하단 5탭이 이번 변경으로 달라지지 않았는지 전후 캡처 비교

## 9. 협업·승인 게이트

1. Codex가 이 작업지시서와 정확 manifest를 작성한다.
2. Claude Opus 4.8이 동일 감사·목업·소스·manifest를 read-only로 검토한다.
3. 양쪽 accept, blocker/high 0, 동일 12파일 manifest일 때 사용자에게 최종 구현 범위를 보고한다.
4. 사용자가 정확 manifest 구현을 승인하기 전에는 Flutter 코드를 수정하지 않는다.
5. 승인 후 Codex가 구현하고 Codex·Claude가 독립 테스트/리뷰한다.
6. blocker/high, 범위 밖 수정 필요, 기능 의미 불일치가 생기면 자동 확대·수정하지 않고 쟁점만 보고한다.

### 비준 판정 기준

- 사용자 구현 승인 전이므로 현재 Flutter 소스는 의도적으로 baseline 결함을 그대로 가진 상태다.
- 비준은 **현재 코드가 이미 수정됐는지**가 아니라 **이 작업지시서가 해당 결함을 필수 변경과 테스트로 빠짐없이 닫는지**를 평가한다.
- baseline 결함이 이 문서의 필수 계약에 포함돼 있으면 이를 `미해결 high`로 반복하지 않는다.
- high는 필수 변경이 문서에 누락됐거나, manifest 안에서 구현 불가능하거나, 계획 자체가 기능·데이터·보호 계약을 깨는 경우에만 부여한다.

## 10. Claude 검토 질문

1. MY Core 1의 목표를 달성하는 데 12파일 manifest가 필요충분한가?
2. 공용 `LazyGridView`의 optional 오류 계약이 기존 호출부를 안전하게 보존하는가?
3. 승인 목업을 구현하면서 pet detail의 기존 분석·게시물 작성 기능을 함께 보존하는 액션 위계가 적절한가?
4. 가상 데이터 제거, `createdAt → 등록한 날`, 삭제 문구 축소가 사실성과 신뢰도 측면에서 적절한가?
5. blocker/high 수준의 누락, 회귀, 테스트 공백 또는 범위 초과가 있는가?

## 11. Claude Opus 4.8 1차 비준과 반영

- 1차 판정: `changes_required`, blocker 0, high 1, source manifest 자체는 `sufficient`
- high: MY Repository failure 상향 전달과 `LazyGridView` 오류 상태가 함께 필수라는 점을 optional로 오독할 수 있음
- 반영: MY의 두 failure 상향 전달, 공용 grid 오류 상태, MY `errorWidget` 전달을 하나의 필수 end-to-end 계약으로 명문화
- 추가 코드 대조: `UserBadgesSection`은 획득 0개여도 잠긴 전체 목록을 렌더하므로 `MyPage`에서 마운트하지 않도록 확정
- 추가 코드 대조: `ProfileService.getProfileStats()`가 실패를 실제 0처럼 반환하고 호출자는 MY 헤더 하나뿐이므로 서비스 실패 rethrow와 전용 테스트 2파일을 manifest에 추가
- 사실관계 정정: 현재 `MyProfileHeader`에는 Claude가 언급한 고정 `반려 1 마리` 문구가 존재하지 않는다. 새 펫 수 표시도 이번 범위에 추가하지 않는다.
- pet deletion: 검증되지 않은 cascade 약속은 제거하고, 실제 데이터 영향은 사람 테스트 증거로 분리한다. DB/API 변경은 하지 않는다.
- 2차 검토는 구현 전 baseline을 완료본처럼 평가하여, 이 문서가 필수로 닫도록 한 MY failure 전파·실제 bio·가상 값 제거를 다시 high로 판정했다. 이는 구현 리뷰가 아니라 기획 비준이라는 단계 기준과 맞지 않아 최종 비준에서는 위 판정 기준을 적용한다.

### 최종 기획 비준

- 최종 판정: `accept`
- blocker/high: 0
- manifest: 수정 6개 + 생성 6개, 총 12개 `sufficient` 및 경로 완전 일치
- end-to-end error plan: pass
- profile truth plan: pass
- pet detail plan: pass
- profile stats plan: pass
- scope and tests: pass
- medium 실행 가드레일:
  1. `getProfileStats()` rethrow와 `MyProfileHeader`의 `snapshot.hasError`·재시도 UI를 반드시 같은 변경으로 적용한다.
  2. 공용 `LazyGridView.errorWidget`은 기존 호출부 소스 호환을 위해 nullable을 유지하되, MY의 두 그리드는 반드시 제공한다.
- low 기록: 가상 레벨·포인트는 실제 값으로 새로 만들지 않고 숨긴다. pet 삭제 문자열 기반 성공 판별은 이번 UI wave에서 회귀 테스트로 고정하고 별도 구조 부채로 남긴다.

## 12. 구현·자동 검증·독립 리뷰 결과

- 사용자 정확 12파일 구현 승인: 2026-07-14
- 구현자: Codex
- 구현 결과: 수정 6개 + 테스트 생성 6개, manifest 밖 app/test 변경 0
- 최종 manifest SHA-256: `c212838b7eac3329f8aaf945879d653aa2c891a5bd6aab49e919ce00de124941`
- `dart format`: 12파일 완료
- 신규 테스트 6파일: 18/18 통과
- MY·profile·pets·shared 영향 회귀 묶음: 67/67 통과
- `flutter analyze --no-pub`: `No issues found`
- 전체 `flutter test --no-pub`: 414 pass / 기존 실패 14 / 신규 실패 0
- `git diff --check`: 통과
- trailing whitespace: 0
- 하단 5탭·`main_navigation.dart`·home·emotion 보호 경로 변경: 0
- commit·merge·push·deploy·운영 DB 작업: 0

### 구현된 사용자 변화

1. MY 헤더가 실제 bio와 통계를 표시하고 이메일 handle·`레벨 1`·`0 P`·잠긴 전체 뱃지를 노출하지 않는다.
2. 내 글과 저장 글의 조회 실패가 성공 empty와 분리되고, raw exception 없이 재시도할 수 있다.
3. 프로필 편집이 초기 loading/error/retry, compact identity, 하단 저장 CTA를 사용하며 기존 텍스트 우선 저장·이미지 부분 실패·`AuthProfileRefresh`·`pop(true)` 계약을 보존한다.
4. 반려동물 상세가 300px hero 대신 compact identity와 수직 정보 위계를 사용한다.
5. `createdAt`은 `함께한 날`이 아니라 `등록한 날 yyyy.MM.dd`로 표시한다.
6. 정보 수정·AI 분석·게시물 작성·overflow 수정·삭제·PetBloc 갱신 동선은 유지한다.
7. 삭제 확인은 검증되지 않은 cascade를 약속하지 않고 복구 불가 사실만 안내한다.

### Codex 독립 리뷰

- 판정: `approve`
- blocker/high: 0
- correctness, 오류/빈 상태, 프로필 사실성, 라우팅·상태·저장 계약, 보호 범위: 통과

### Claude Opus 4.8 독립 구현 리뷰

- 판정: `approve`
- blocker/high: 0
- manifest/protected paths: 통과
- correctness, error vs empty, profile truth, profile edit contract, pet detail contract, UI/UX·접근성, tests: 모두 pass
- medium 후속 1건: `PetOperationSuccess.message.contains('삭제')` 문자열 기반 pop은 현재 계약에서 정상이나, 향후 PetBloc에 operation type을 추가하는 별도 기능 wave에서 타입화 권고
- low 후속 2건: profile 갱신 직후 follower 링크 name의 짧은 이전값 가능성, 테스트 loader seam의 production constructor 노출 의도 명시

### 남은 게이트

- 자동 검증과 양쪽 리뷰는 완료했다.
- 실기기에서 MY 메인, 프로필 편집, 반려동물 상세의 실제 데이터·키보드·사진 권한·느린 네트워크·150% 글자·TalkBack을 확인하기 전에는 MY Core 1을 사람 검증 완료로 동결하지 않는다.
