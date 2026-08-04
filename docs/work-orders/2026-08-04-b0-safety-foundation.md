# B0 안전·디자인 기반 구현 작업지시서 v3

기준일: 2026-08-04
기준 브랜치: `mac-ios-release`
기준 HEAD: `e6b6aac6e7546f10d54492442dad856fba4ee697`
정본: `docs/reviews/2026-08-04-full-app-uiux-master-plan.md`
상태: 구현·재검증 완료, Claude Opus 5 최종 `APPROVED` (`BLOCKER 0`, `HIGH 0`)

## 1. 목적과 경계

B0는 이후 B1~B6가 공통으로 따라야 할 안전·디자인 계약을 코드와 자동 테스트로
고정한다. Home과 AI 분석 결과 구현은 잠금 상태를 유지한다. 운영 DB, Edge,
APNs, signing 자산, TestFlight, 스토어 제출은 실행하지 않는다.

이번 B0에서 실제로 구현하는 항목은 다음과 같다.

1. FCM/realtime 민감 payload·record release 로그 제거
2. 공개 오류 메시지 공통 정제기와 잠금 외 직접 노출 지점 적용
3. Android release debug-signing fallback 차단
4. 실제 스키마의 nullable `is_private` fail-closed SQL 계약 작성(원격 적용 금지)
5. 라이트·다크 토큰과 CTA 상태, 하단 탭 접근성 정본화
6. 80개 presentation 화면 배치 매핑 80/80 자동 검증
7. 세션 만료 draft 복원과 반려동물 soft-delete의 후속 배치 계약 고정

OAuth·Apple revoke·APNs·FCM·딥링크와 QA 계정 2개 상호작용은 자격증명·실기기
의존 검증이다. B0에서는 자동 계약과 체크리스트만 고정하며 통과로 허위 보고하지
않는다. 세션 복원 UI는 B1, 반려동물 soft delete UI/데이터 계층은 B2,
공개 범위 재설정 UI는 B3에서 구현한다.

## 2. 보호 조건

- 수정 금지: Home presentation, AI 분석·결과 presentation
- 보존: Apple OAuth, URL scheme, entitlement, iPad `shareOrigin`
- 보존: K1/H2, `auth.uid()` 기반 RPC, 차단·신고·건강 소유권 계약
- 금지: 광범위 `public.users SELECT`, caller-id 기반 RPC, 원격 migration 실행
- 금지: 비밀 파일, Firebase plist, 환경변수, 인증서·키·profile 내용·해시 출력
- 사용자 소유 `.agents/`, `.codex/`, `AGENTS.md`는 수정·stage하지 않는다.

## 3. 정확한 구현 manifest

### 공통 안전

- `pjh/lib/core/services/fcm_service.dart`
- `pjh/lib/core/services/realtime_service.dart`
- `pjh/lib/core/error/error_messages.dart`
- `pjh/lib/features/mbti/presentation/bloc/mbti_test_bloc.dart`
- `pjh/lib/features/mbti/presentation/widgets/my_mbti_badge_section.dart`
- `pjh/lib/features/news/presentation/pages/news_list_page.dart`
- `pjh/lib/features/pets/presentation/pages/pet_detail_page.dart`
- `pjh/lib/features/pets/presentation/pages/pet_editor_page.dart`
- `pjh/lib/features/pets/presentation/pages/pet_management_page.dart`
- `pjh/lib/features/social/presentation/pages/comments_page.dart`
- `pjh/lib/features/social/presentation/pages/post_detail_page.dart`
- `pjh/lib/features/social/presentation/widgets/comments_bottom_sheet.dart`
- `pjh/lib/features/social/presentation/bloc/bookmark_bloc.dart`
- `pjh/lib/shared/widgets/error_dialog.dart`
- `pjh/lib/shared/widgets/lazy_load_list.dart`

### 디자인·접근성

- `pjh/lib/shared/themes/app_theme.dart`
- `pjh/lib/main_navigation.dart`

### Android release 보호

- `pjh/android/app/build.gradle.kts`

### 서버 계약(로컬 SQL만 작성, 실행 금지)

- `supabase/migrations/20260804_b0_post_visibility_fail_closed.sql`
- `supabase/petspace_setup.sql`

### 작업지시서와 테스트

- `docs/work-orders/2026-08-04-b0-safety-foundation.md`
- `pjh/test/contracts/b0_release_safety_contract_test.dart`
- `pjh/test/contracts/b0_visibility_fail_closed_contract_test.dart`
- `pjh/test/contracts/b0_uiux_inventory_contract_test.dart`
- `pjh/test/contracts/b0_protected_paths_contract_test.dart`
- `pjh/test/contracts/p2b_block_privacy_contract_test.dart`
- `pjh/test/contracts/public_error_message_contract_test.dart`
- `pjh/test/contracts/uiux_scope_boundary_contract_test.dart`
- `pjh/test/shared/themes/app_theme_test.dart`
- `pjh/test/main_navigation_test.dart`
- `pjh/tool/uiux_frozen_scope.sha256`
- `pjh/tool/uiux_protected_scope.sha256`

### read-only inspection manifest

아래 파일은 계약 우회가 없는지 검사하지만 내용 변경 대상은 아니다.

- `pjh/lib/main.dart`
- `pjh/lib/core/services/local_notification_service.dart`
- `pjh/lib/core/services/notification_service.dart`
- `pjh/lib/features/chat/data/datasources/chat_remote_data_source.dart`
- `pjh/android/.gitignore`
- `pjh/android/key.properties.example`
- `supabase/migrations/K1_block_privacy_contract.sql`
- `docs/reviews/2026-08-04-full-app-uiux-master-plan.md`
- `docs/reviews/2026-08-04-full-app-uiux-inventory.md`

기준 SHA-256:

- master plan: `cb7e5d28f193a4327619723f8ffed86fa355e786e49c4de5b03f6f73d5945d6a`
- 80-screen inventory: `4ca3e3de408e4ccaafb936912c58ce10614ce832ca83fc69eccce40aac85bc05`

manifest 밖 수동 수정이 필요하면 중단하고 작업지시서를 먼저 개정한다.

## 4. 구현 계약

### 로그

- 저장소 전역 스캔을 기준으로 알림 title/body/data, realtime new/old record,
  user id, post id, channel id, token/deviceToken, endpoint URL을 release 로그에
  넣지 않는다.
- 이벤트 종류와 성공/실패 같은 비식별 상태만 기록한다.
- 예외 객체와 stack trace는 FCM/realtime 사용자 payload 경로에서 출력하지 않는다.
- `main.dart`에는 background handler 등록만 있고 handler 본체는
  `fcm_service.dart`에 있음을 확인했다. local notification과 notification service는
  payload를 기능적으로 전달하지만 출력하지 않는다. feature realtime 중 chat은
  record를 model로 전달할 뿐 출력하지 않는다.
- 로그 제거 전 금지 패턴은 FCM 5건(foreground title 1 + data route 1 +
  background title/body/data 3),
  Realtime record 6건이다. 기능 전달용 `payload.newRecord/oldRecord`는 금지 로그가
  아니므로 제거하지 않는다.
- FCM/realtime 경로의 기존 Crashlytics `recordError`, `recordFlutterError`,
  breadcrumb sink는 감사 결과 0건이다. B0 변경 후에도 0이어야 한다.

### 공개 오류

- 내부 예외, URL, SQL/PostgREST/Supabase/OAuth/token/uid, 로컬 경로는 고정된
  한국어 안전 문구로 치환한다.
- 이미 제품이 정의한 한국어 validation/network 안내는 유지한다.
- AI/Home 잠금 파일의 기존 노출 지점은 이번 diff에서 수정하지 않고 B7/B8 보호
  해제 시 처리한다.
- 잠금 raw UI allowlist는 `ai_history_page.dart`, `emotion_analysis_page.dart`,
  `emotion_result_loader_page.dart`, `emotion_result_page.dart`,
  `emotion_timeline_page.dart`, `health_result_page.dart`,
  `my_emotion_history_page.dart`, `home_mbti_card.dart` 8개다. 만료 조건은 B7/B8
  보호 해제 승인이다. B1 후속 ID는 `B1-ERR-01`, B7은 `B7-ERR-01`, B8은
  `B8-ERR-01`로 고정한다. 신규 raw 직접 노출 파일이 이 집합 밖에 생기면 실패한다.
- 원문은 UI에 표시하지 않는다. debug 진단은 `kDebugMode` 한정 로컬 로그에서만
  허용하며, sanitizer가 원문을 Crashlytics에 새로 전달하는 코드는 추가하지 않는다.

### Android release

- `key.properties`가 없거나 필수 키가 비었거나 keystore 파일이 없으면 release
  task graph가 준비되는 시점에 명시적으로 실패해야 한다. Gradle configuration/sync
  자체에서 무조건 throw하지 않는다. 이 방식은 `assembleRelease --dry-run`에서도
  release task graph를 식별해 실패하는 (a) 계약으로 고정한다.
- debug signingConfig로의 fallback은 없어야 한다.
- debug/profile, `flutter test`, `assembleDebug`는 영향을 받지 않는다.
- 실제 signing 파일은 읽거나 생성하지 않는다.

### visibility

- 실제 스키마에는 문자열 `visibility` 열이 없고 nullable boolean `is_private`만
  존재한다. 존재하지 않는 enum이나 followers-only 값을 새로 만들지 않는다.
- `is_private = true` 또는 `NULL`은 작성자 본인 외 SELECT 불가다.
- 직접 SELECT는 기존 K1 PERMISSIVE 정책과 AND 결합되는 `AS RESTRICTIVE`
  owner/public guard로 강제한다. 기존 K1 차단·활성 사용자 조건은 유지한다.
- SECURITY DEFINER 게시글 읽기 RPC `get_recommended_posts`, `get_feed_posts`,
  `get_posts_by_hashtag`, `get_posts_by_location`, `get_popular_hashtags`,
  `get_trending_hashtags`는 owner가 아닌 행 또는 집계에
  `is_private IS FALSE`를 강제한다. 특히 기존 `get_feed_posts`의 누락을 수정한다.
- K1의 posts/comments/likes/comment_likes SELECT는 모두 `authenticated` 전용이다.
  익명 사용자는 posts PERMISSIVE 정책 자체가 없어 읽을 수 없다. comments·likes·
  comment_likes의 부모 확인 subquery는 `public.posts` RLS를 함께 적용하므로 비공개
  부모를 우회하지 못한다. 별도 `post_media`/`post_images` 테이블은 없고 이미지와
  hashtag는 posts 행의 열이다. `saved_posts`는 본인 행만 읽는 기존 계약을 유지한다.
- migration은 transaction, 멱등 `DROP POLICY IF EXISTS`, nullable 기존 행의
  owner-only 의미 보존, 명시적 rollback 절차를 포함한다. B0는 컬럼 NOT NULL이나
  backfill을 실행하지 않고 RESTRICTIVE guard만 추가한다. B1 원격 적용 게이트
  `B1-DB-PRIVACY-01`에서 staging NULL 사전 count, NULL→false backfill 여부의 사용자
  결정 기록, 결정 전 운영 적용 금지를 요구한다. rollback SQL은 자동
  실행될 migrations 디렉터리에 별도 파일로 두지 않고 이 작업지시서에만 기록한다.
- `petspace_setup.sql`과 신규 migration의 direct/RPC 조건을 자동 대조한다.
- `get_feed_posts` owner 판정은 전달된 `user_uuid`가 아닌 `auth.uid()`를 정본으로
  한다. 인자 signature, 반환 type, `SECURITY DEFINER`, `SET search_path`, volatility,
  owner와 GRANT는 수정 전후 불변이다. migration은 동일 signature의
  `CREATE OR REPLACE`만 사용하고 새 overload를 만들지 않는다.
- B3의 소유자 재설정 UI가 준비되기 전 신규 팔로워 전용 선택을 노출하지 않는다.

### 디자인·접근성

- light: canvas `#F7F8FA`, surface `#FFFFFF`, border `#E5E8EC`, body `#283746`,
  secondary `#687789`, CTA `#2F6399`, on-CTA `#FFFFFF`, pressed `#244E79`,
  disabled `#D6DEE8`, disabled text `#6B7788`, focus `#2F6399`,
  error `#B42318`, success `#2E7D32`, scrim `#99000000`
- dark: background `#0F1724`, surface `#182232`, border `#344054`, body
  `#F4F7FB`, secondary `#B8C2CF`, brand `#A9C7E8`, action `#86B7E7`,
  on-action `#10243A`, pressed `#A5CAED`, disabled `#344054`, disabled text
  `#8E9AAA`, focus `#A9C7E8`, error `#FFB4AB`, success `#A6D8A8`,
  scrim `#B3000000`
- 대비는 일반 본문 4.5:1 이상, large/UI component 3:1 이상, light CTA/white
  6.24:1 이상을 자동 계산해 단언한다.
- disabled 텍스트/배경 쌍은 WCAG 비활성 컴포넌트 예외로 4.5:1 단언 대상에서
  제외하되, 다른 본문 역할이 disabled 토큰을 재사용하지 않도록 토큰 동등성과
  버튼 상태 resolver를 별도로 단언한다.
- 하단 탭은 5개 전체 semantic label, selected state, 위치 `n/5`, padding 포함
  48 logical pixel 이상 hit target, long-press tooltip을 제공한다.
- 하단 탭 라벨 text scale만 최대 1.3으로 제한한다. 본문·폼·결과 텍스트의
  200% 확대를 전역 제한하지 않는다. clamp는 nav label `Text` subtree에만 둔다.
- long-press tooltip은 탭 전환을 발생시키지 않는다.

### 후속 배치 계약

- 세션 만료: silent refresh 1회 → 실패 시 진행 task draft 저장 → 로그인 후
  복원 여부 1회 질문. B1에서 실제 auth/router/task 연결을 구현하며 B0에는 런타임
  호출부를 추가하지 않는다. draft는 플랫폼 보안 저장소에 계정별 암호화 저장,
  TTL 24시간, 복원 거절/로그아웃/계정 변경 시 즉시 파기, 복원 질문 키는
  `session_draft_restore_prompted:<uid>:<draftId>`로 한 번만 소비한다.
- pet soft delete: 30일 유예, 유예 중 pet/전용 건강/AI 숨김, 게시글 유지·pet 연결
  숨김, 대표 pet 삭제 전 사용자 재선택, 마지막 pet은 대표 없음. B2에서 구현하며
  B0에는 pet runtime/SQL을 추가하지 않는다. 보존 게시글은 privacy guard를 그대로
  적용하고 삭제 pet 연결만 숨긴다.

### rollback 절차(문서 전용, 실행 금지)

운영 적용 전 staging에서 문제가 확인된 경우에만 신규 restrictive policy와
`get_feed_posts`/canonical SQL을 직전 승인 commit으로 함께 되돌린다. RESTRICTIVE
guard 제거는 개인정보 보호 해제이므로 단독 실행하지 않는다. migration과 canonical
한쪽만 되돌리면 drift 테스트가 실패하도록 유지한다. 자동 적용될 down migration은
만들지 않는다. 운영 적용 후에는 사용자 승인과 DB 백업 없이 실행하지 않는다.

## 5. 검증 명령

`pjh/`에서 다음 순서로 실행한다.

```bash
dart format <이번 B0에서 변경된 정확한 Dart 파일>
git diff --check
flutter analyze --no-pub --fatal-infos
flutter test --no-pub test/contracts/b0_release_safety_contract_test.dart
flutter test --no-pub test/contracts/b0_visibility_fail_closed_contract_test.dart
flutter test --no-pub test/contracts/b0_uiux_inventory_contract_test.dart
flutter test --no-pub test/contracts/b0_protected_paths_contract_test.dart
flutter test --no-pub test/contracts/p2b_block_privacy_contract_test.dart
flutter test --no-pub test/contracts/public_error_message_contract_test.dart
flutter test --no-pub test/contracts/uiux_scope_boundary_contract_test.dart
flutter test --no-pub test/shared/themes/app_theme_test.dart
flutter test --no-pub test/main_navigation_test.dart
flutter test --no-pub
flutter build ios --release --no-codesign
./gradlew :app:assembleDebug
./gradlew :app:assembleDebug --dry-run
./gradlew :app:assembleRelease --dry-run  # signing 미설정 환경에서는 의도한 오류로 실패
```

Simulator에서는 비로그인 인증 화면을 라이트/최대 글자 크기에서 확인한다. 인증된
QA 계정이 없으면 보호 화면을 우회하지 않으며, 로그인 후 root navigation의 5개 탭,
다크, 본문 200% + 라벨 1.3 clamp, VoiceOver, long-press tooltip, 키보드, SafeArea는
실제 production destination 위젯 테스트로 검증한 뒤 B1 실기기 게이트로 남긴다.
Home·AI 결과는 수정하지 않는다.

추가 자동 게이트:

- 화면 인벤토리 bullet 80개, mapping table 80개, 실제 파일 존재 80개, 중복/누락 0
- 변경 파일 집합이 수정 manifest 이내이며 Home/AI/Apple/iOS 보호 경로 diff 0
- 알림 탭 deep-link 분기와 realtime stream 전달 코드가 로그 제거 후에도 존재
- 공개 오류 잠금 allowlist 외 raw direct display 0
- `key.properties`와 keystore가 gitignore 상태이며 내용/해시를 읽지 않음

## 6. 중단 조건

- blocker/high 발견
- 보호 계약 또는 잠금 화면 수정 필요
- manifest 밖 수동 변경 필요
- 비밀 또는 사용자 데이터 노출
- K1/H2/auth.uid 계약 약화
- 신규 analyze/test/build 실패
- Android release가 debug 키로 구성 가능
- 80개 화면 매핑이 80/80이 아님

## 7. 최종 실행 결과

- `dart format`, `git diff --check`: 통과
- `flutter analyze --no-pub --fatal-infos`: issue 0
- B0 지정 계약·테마·내비게이션 테스트: 통과
- `flutter test --no-pub`: `+1020 All tests passed`
- UI freeze: rendering input 377개 통과, protected input 52개 통과
- `flutter build ios --release --no-codesign`: 성공, `Runner.app` 91.8MB
- iPhone 17 Simulator: 최신 코드 로그인 화면, 기본/최대 글자 크기, 키보드 스크롤,
  입력·CTA 접근성 확인. 인증 후 화면은 자격증명 없이 우회하지 않음
- `:app:assembleDebug --dry-run`: `BUILD SUCCESSFUL`
- `:app:assembleRelease --dry-run`: signing 미설정 지정 오류로 의도한 실패
- 실제 `assembleDebug`: B0와 무관한 기존 Firebase Android package 등록 mismatch로
  차단. Firebase 설정 파일 내용은 열거나 출력하지 않음
- Home/AI presentation, Apple/OAuth iOS 파일, `auth_repository_impl.dart`,
  `share_origin.dart`, `firebase_options.dart`: diff 0
- 운영 DB, Edge, APNs, signing 자산, TestFlight, 스토어, 원격 push: 미실행

## 8. Claude 단계별 합의

- 사전 v1: `changes_required`
- 사전 v2: `approved`, blocker 0; 코드 전 문서 보완 5건 반영
- 구현 후 1차: 구현 승인, 검증 High 2건
- 보완 후 최종: `APPROVED`, `BLOCKER 0`, `HIGH 0`
- 최종 Medium 2건은 B0 코드 결함이 아니라 원격/인증 상태에 의존하는 B1 게이트다.

## 9. 개선점과 다음 배치 게이트

### B1-DB-PRIVACY-01

사용자 승인 뒤 staging에서만 migration을 적용하고 다음을 한 체크포인트로 검증한다.

1. 적용 전 `is_private IS NULL` 행 count
2. NULL→false backfill 여부의 사용자 결정 기록
3. 적용 후 `pg_policies`의 posts 정책 전체 열거
4. 구 public/anon PERMISSIVE SELECT 정책 0건
5. `posts_privacy_fail_closed` RESTRICTIVE SELECT 존재
6. `get_feed_posts`, `get_popular_hashtags`, `get_trending_hashtags` smoke test

결정과 검증 전 운영 DB에는 적용하지 않는다.

### B1-ANDROID-FIREBASE-01

Firebase Console에서 Android applicationId와 일치하는 앱 등록·설정 파일을 사용자가
준비한 뒤 실제 `assembleDebug`를 실행한다. 올바른 설정 파일이 제공되기 전에는
기존 파일을 추측으로 수정하거나 내용을 출력하지 않는다.

### B1-QA-DEVICE-01

QA 계정 2개와 실기기/Simulator 인증 상태를 확보한 뒤 다크, 본문 200% + nav 1.3,
탭 5개, long-press tooltip, VoiceOver, 키보드 포커스, SafeArea, 알림·딥링크를
실제 상호작용으로 검증한다.

### B1 hashtag 호출부 확인

`get_popular_hashtags`/`get_trending_hashtags` 호출은 `SearchBloc`과 Home 내부로
한정된다. 검색·탐색 라우트와 Home은 `ShellRoute`의 `AuthGuard` 아래에 있고,
독립 `TrendingHashtagsSection`은 현재 호출부가 없다. 비인증 진입 호출부는 0건이다.

### 구현 우선순위

1. 위 세 B1 게이트 준비
2. B1 세션 silent refresh 1회와 secure draft 24시간 복원 wiring
3. B2 pet soft-delete 30일과 대표 재선택
4. B3 공개범위 소유자 reset UI
5. B7/B8 보호 해제 승인 시 raw UI allowlist 8개 재평가
