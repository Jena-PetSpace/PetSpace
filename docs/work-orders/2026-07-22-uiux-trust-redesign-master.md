# PetSpace UI/UX 신뢰도 전면 개선 Master Work Order v1

> 기획 기준일: 2026-07-22
> 앱 코드 기준: `c49a8c4`
> 기획 브랜치 기준: `604e9f1`
> 구현 상태: 미착수
> 기획 검토: Codex 단독 3-pass
> 외부 검토: Claude·Anthropic 전송 제외
> 상위 승인: Set A~D 목업 및 아래 사용자 결정 승인

> 2026-07-23 후속 실행: 아래 원래 제외 조건과 별도의 사용자 승인으로
> `20260723042242_m1_selected_pet_contract.sql`만 원격 DB에 적용했다.
> 다른 migration·Edge·APNs·배포는 적용하지 않았다.

이 문서는 승인 전 초안 `docs/work-orders/2026-07-22-post-merge-upgrade-master.md`를 대체하는 구현 정본이다.

## 1. 목적과 범위

기능 수는 유지하면서 화면 간 제품 언어, 계층, 상태 표현과 실패 복구를 하나의 시스템으로 통합한다. 홈 탭과 AI 분석 탭의 콘텐츠는 재설계하지 않지만, 전역 5탭 shell과 safe area 회귀 검증에는 포함한다.

포함:

- 일반형 5탭 root navigation과 root/task/detail 계층 분리
- 인증·온보딩·약관·프로필·첫 반려동물 등록
- 반려동물 관리·MY·저장·프로필·설정·알림·개인정보
- `피드 / 커뮤니티`·작성·상세·댓글·검색·신고·차단·저장·알림
- 건강 5종 기록·편집·삭제·추이·PDF·기기 알림 테스트
- 채팅 목록·1:1·그룹·텍스트·사진·재전송·방 설정
- loading / empty / validation / offline / recoverable error / destructive confirmation / success 상태

제외:

- 홈 콘텐츠, 카드, 뉴스, 퀴즈, 운세 재기획
- AI 분석 촬영·결과·히스토리 콘텐츠 재기획
- 스토리 기능
- 피드 동영상 업로드
- 자동 건강 예정일 알림 운영 연결
- 그룹 멤버 강제 퇴장과 방별 알림 스위치
- 운영 DB migration 적용, 원격 RPC 실행, Edge, APNs, signing, TestFlight, 스토어 배포
- `mac-ios-release`, `win-android-release`, `main` 반영과 모든 원격 push

## 2. 승인 목업 정본

- Set A: `docs/mockups/set-a-navigation-auth-v1.html`의 `A01`~`A07`
- Set B: `docs/mockups/set-b-pet-my-v1.html`의 `B01`~`B12`
- Set C: `docs/mockups/set-c-feed-social-v1.html`의 `C01`~`C12`
- Set D: `docs/mockups/set-d-health-chat-v1.html`의 `D01`~`D12`
- 결정·리뷰 정본: `docs/mockups/2026-07-22-uiux-direction-discussion.md`
- 제품 감사 정본: `docs/reviews/2026-07-22-uiux-product-trust-audit.md`

목업은 정보구조·위계·상태·문구 계약의 기준이다. 픽셀을 기계적으로 복제하지 않고 Flutter text scale, safe area, 플랫폼 접근성에 맞게 구현한다.

## 3. 고정된 사용자 결정

1. root는 홈 / 건강 / AI 분석 / 피드 / MY의 일반형 5탭을 사용한다.
2. 중앙 AI paw FAB와 notch를 제거한다.
3. 브랜드는 차분한 케어 에디토리얼 톤을 사용한다.
4. 건강 root는 `다음 케어`를 먼저 보여준다.
5. MY는 대표 반려동물을 상단 identity로 사용한다.
6. 피드 상단은 정확히 `피드 / 커뮤니티`를 사용하고 `발견 / 라운지`를 새 UI에서 사용하지 않는다.
7. 첫 반려동물 등록은 `나중에`를 허용한다.
8. 한 줄 소개는 온보딩이 아니라 MY 프로필 편집에서 받는다.
9. 이메일 인증 화면은 `로그인 / 회원가입` segmented 구조를 사용한다.
10. 대표 반려동물 선택은 계정 단위로 영구 저장한다.
11. MY 대표 반려동물 카드에 다음 건강 일정을 표시한다.
12. 반려동물 삭제 확인은 삭제되는 데이터와 연결만 해제되는 데이터를 구분한다.
13. `팔로워만` 게시 범위는 안전한 audience 정책이 완성될 때까지 숨긴다.
14. 피드 작성은 사진 최대 10장만 지원한다.
15. 커뮤니티 제목은 기존 caption 첫 문단을 파싱해 본문과 시각적으로 분리한다.
16. 건강 기록 추가·수정은 full task screen으로 전환한다.
17. 신규 예방접종의 백신 종류는 필수지만 기존 빈 값 기록은 조회·편집할 수 있다.
18. 자동 건강 예정일 알림은 `준비 중`으로 두고 5초 기기 테스트만 제공한다.
19. 채팅 사진은 한 번에 최대 10장으로 제한하고 같은 선택의 재전송을 보존한다.
20. 실제 저장 계약이 없는 멤버 강제 퇴장과 방별 알림 UI는 만들지 않는다.

## 4. 보호 계약과 중단 조건

다음은 모든 wave에 적용한다.

- Apple 로그인·OAuth callback·URL scheme·entitlement를 변경하지 않는다.
- `pjh/ios/Podfile`, `pjh/ios/Podfile.lock`, `pjh/ios/Runner/Runner.entitlements`, `pjh/ios/Runner/Info.plist`, `pjh/ios/Runner.xcodeproj/project.pbxproj`를 변경하지 않는다.
- `pjh/ios/Runner/GoogleService-Info.plist`, `pjh/lib/firebase_options.dart`, `pjh/lib/core/utils/share_origin.dart`, `pjh/lib/features/auth/data/repositories/auth_repository_impl.dart`를 변경하거나 내용·SHA를 출력하지 않는다.
- K1 차단·개인정보 정책과 H2 인증 연결을 보존한다.
- 신규 대표 반려동물 RPC는 caller id 인자가 아니라 `auth.uid()`만 사용한다.
- 광범위 `public.users SELECT`와 구형 caller-id RPC를 복구하지 않는다.
- H1 건강 소유권과 `pets.user_id = auth.uid()` 경계를 보존한다.
- public AI confidence 백분율을 표시하지 않는다.
- iPad `shareHandler + shareOrigin`, health root navigator와 `context.mounted` 안전 수정을 보존한다.
- `pjh/lib/config/secrets.dart`, `.env*`, 키·인증서·provisioning profile을 읽기 결과, diff, stage, commit, manifest에 포함하지 않는다.
- 허용 manifest 밖 production 수정, blocker/high, 비밀 노출, 보호 계약 변경 또는 신규 검증 실패가 발생하면 즉시 중단한다.
- 테스트 삭제·skip·기대값 약화로 실패를 숨기지 않는다.

## 5. 공통 구현 규칙

- 각 wave는 별도 로컬 commit으로 끝내고 다음 wave 전 집중 테스트와 전체 테스트를 실행한다.
- `git add -A`를 사용하지 않고 해당 wave의 실제 수정 경로만 명시적으로 stage한다.
- root 다섯 경로 `/home`, `/health`, `/emotion`, `/feed`, `/my`에서만 하단 탭을 표시한다.
- 작성·편집·설정·상세·채팅·검색·알림에는 하단 탭을 표시하지 않는다.
- interactive target은 최소 44×44pt로 구현한다.
- type scale 100%, 150%, 200%와 320×568, 390×844에서 overflow가 없어야 한다.
- 제출 pending 중 중복 요청을 막고 입력·선택·로컬 사진을 보존한다.
- 성공 UI는 repository/server 성공 뒤에만 반영한다.
- raw exception, SQL, UID, 이메일, OAuth URL/token, storage path를 사용자 문구와 운영 로그에 노출하지 않는다.
- 색상·radius·type·spacing은 `AppTheme`을 사용하고 신규 임의 hex를 화면 파일에 추가하지 않는다.

## 6. W0 — Navigation + Visual Foundation

### 화면 매핑

- `A01` root shell
- `A02` task shell
- `C01`, `C02`, `D01`, `D02`의 root shell
- 모든 detail/task screen의 하단 탭 제거

### 수동 수정 허용 production manifest

- `pjh/lib/main_navigation.dart`
- `pjh/lib/core/navigation/app_router.dart`
- `pjh/lib/shared/models/navigation_item.dart`
- `pjh/lib/shared/themes/app_theme.dart`
- `pjh/lib/shared/widgets/category_chip.dart`
- `pjh/lib/shared/widgets/info_box.dart`
- `pjh/lib/shared/widgets/petspace_app_bar.dart`
- `pjh/lib/shared/widgets/petspace_page_scaffold.dart`
- `pjh/lib/shared/widgets/petspace_settings_components.dart`
- `pjh/lib/shared/widgets/petspace_state_view.dart`
- `pjh/lib/shared/widgets/section_header.dart`

`pjh/lib/shared/widgets/main_navigation_wrapper.dart`와 `pjh/lib/shared/widgets/custom_bottom_navigation_bar.dart`는 현행 진입점이 아니므로 이 wave에서 수정·삭제하지 않는다.

### 정확한 test manifest

- 신규 `pjh/test/main_navigation_test.dart`
- 신규 `pjh/test/shared/widgets/category_chip_test.dart`
- 신규 `pjh/test/shared/widgets/petspace_page_scaffold_test.dart`
- 신규 `pjh/test/shared/widgets/petspace_settings_components_test.dart`
- 신규 `pjh/test/shared/widgets/petspace_state_view_test.dart`
- 기존 `pjh/test/shared/widgets/petspace_wave1_widgets_test.dart`
- 기존 `pjh/test/core/navigation/settings_routes_test.dart`
- 기존 `pjh/test/widget_test.dart`

### 완료 조건

- 다섯 탭의 크기·위계가 동일하고 AI 탭만 떠 있지 않다.
- root 경로와 하위 경로의 nav 표시 계약이 test로 고정된다.
- warm off-white, white surface, deep navy, 얇은 border의 공용 토큰이 light/dark theme에서 안전하다.
- 공용 loading/empty/error와 설정 row가 44pt·시맨틱 이름·선택 상태를 제공한다.

### commit

`[codex] uiux: 공용 내비게이션과 신뢰 디자인 기반 정리`

## 7. W1 — Auth + Onboarding

### 화면 매핑

- `A03` 로그인 선택
- `A04` 이메일 로그인·회원가입
- `A05` 약관·저장 실패
- `A06` 닉네임·프로필 사진
- `A07` 첫 반려동물 등록·나중에

### 수동 수정 허용 production manifest

- `pjh/lib/core/error/error_messages.dart`
- `pjh/lib/core/navigation/app_router.dart`
- `pjh/lib/features/auth/presentation/bloc/auth_bloc.dart`
- `pjh/lib/features/auth/presentation/bloc/auth_event.dart`
- `pjh/lib/features/auth/presentation/bloc/auth_state.dart`
- `pjh/lib/features/auth/presentation/pages/kakao_consent_page.dart`
- `pjh/lib/features/auth/presentation/pages/password_reset_new_password_page.dart`
- `pjh/lib/features/auth/presentation/pages/password_reset_request_page.dart`
- `pjh/lib/features/auth/presentation/pages/password_reset_verification_page.dart`
- `pjh/lib/features/auth/presentation/pages/terms_agreement_page.dart`
- `pjh/lib/features/auth/presentation/pages/terms_detail_page.dart`
- `pjh/lib/features/auth/presentation/widgets/social_login_button.dart`
- `pjh/lib/features/onboarding/presentation/bloc/onboarding_bloc.dart`
- `pjh/lib/features/onboarding/presentation/bloc/onboarding_event.dart`
- `pjh/lib/features/onboarding/presentation/bloc/onboarding_state.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_complete_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_email_verification_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_login_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_pet_registration_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_profile_setup_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_slides_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_tutorial_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/splash_page.dart`

### 정확한 test manifest

- 기존 `pjh/test/features/auth/presentation/bloc/auth_bloc_test.dart`
- 신규 `pjh/test/features/auth/presentation/pages/kakao_consent_page_test.dart`
- 신규 `pjh/test/features/auth/presentation/pages/password_reset_new_password_page_test.dart`
- 신규 `pjh/test/features/auth/presentation/pages/password_reset_request_page_test.dart`
- 신규 `pjh/test/features/auth/presentation/pages/password_reset_verification_page_test.dart`
- 신규 `pjh/test/features/auth/presentation/pages/terms_agreement_page_test.dart`
- 신규 `pjh/test/features/auth/presentation/pages/terms_detail_page_test.dart`
- 신규 `pjh/test/features/onboarding/presentation/pages/onboarding_complete_page_test.dart`
- 신규 `pjh/test/features/onboarding/presentation/pages/onboarding_email_verification_page_test.dart`
- 신규 `pjh/test/features/onboarding/presentation/pages/onboarding_login_page_test.dart`
- 신규 `pjh/test/features/onboarding/presentation/pages/onboarding_pet_registration_page_test.dart`
- 신규 `pjh/test/features/onboarding/presentation/pages/onboarding_profile_setup_page_test.dart`
- 신규 `pjh/test/features/onboarding/presentation/pages/splash_page_test.dart`
- 신규 `pjh/test/contracts/auth_log_redaction_contract_test.dart`
- 신규 `pjh/test/contracts/public_error_message_contract_test.dart`

### 완료 조건

- Apple/Google/Kakao/이메일 버튼의 플랫폼 이름과 pending/취소/실패가 구분된다.
- 약관 저장 실패 시 동의 상태와 스크롤 위치가 유지되고 성공 전 진행하지 않는다.
- 프로필은 닉네임 계약을 사용하고 한 줄 소개를 요구하지 않는다.
- 첫 반려동물 등록을 건너뛰면 완료 가능하며 MY에서 다시 안내한다.
- Apple/OAuth repository와 iOS 보호 파일 diff가 없다.

### commit

`[codex] uiux: 인증과 첫 이용 신뢰 흐름 정리`

## 8. W2 — Pet + MY + Settings

### 화면 매핑

- `B01`~`B12`

### 수동 수정 허용 production manifest

- `pjh/lib/config/injection_container.dart`
- `pjh/lib/core/navigation/app_router.dart`
- `pjh/lib/features/pets/data/repositories/pet_repository_impl.dart`
- `pjh/lib/features/pets/domain/repositories/pet_repository.dart`
- 신규 `pjh/lib/features/pets/domain/usecases/get_selected_pet_id.dart`
- 신규 `pjh/lib/features/pets/domain/usecases/set_selected_pet_id.dart`
- `pjh/lib/features/pets/presentation/bloc/pet_bloc.dart`
- `pjh/lib/features/pets/presentation/bloc/pet_event.dart`
- `pjh/lib/features/pets/presentation/bloc/pet_state.dart`
- `pjh/lib/features/pets/presentation/pages/pet_detail_page.dart`
- `pjh/lib/features/pets/presentation/pages/pet_editor_page.dart`
- `pjh/lib/features/pets/presentation/pages/pet_management_page.dart`
- `pjh/lib/features/pets/presentation/pages/public_pet_page.dart`
- `pjh/lib/features/pets/presentation/widgets/pet_card.dart`
- `pjh/lib/features/pets/presentation/widgets/pet_editor_form_widgets.dart`
- `pjh/lib/features/my/presentation/pages/my_page.dart`
- `pjh/lib/features/my/presentation/pages/my_posts_page.dart`
- `pjh/lib/features/my/presentation/pages/my_saved_posts_page.dart`
- `pjh/lib/features/my/presentation/pages/my_settings_page.dart`
- 신규 `pjh/lib/features/my/presentation/controllers/my_next_health_loader.dart`
- `pjh/lib/features/my/presentation/widgets/my_pet_summary_section.dart`
- `pjh/lib/features/my/presentation/widgets/my_profile_header.dart`
- `pjh/lib/features/my/presentation/widgets/saved_posts_grid.dart`
- `pjh/lib/features/profile/presentation/pages/notification_settings_page.dart`
- `pjh/lib/features/profile/presentation/pages/privacy_settings_page.dart`
- `pjh/lib/features/profile/presentation/pages/profile_edit_page.dart`
- 신규 `supabase/migrations/20260723042242_m1_selected_pet_contract.sql`
- `supabase/petspace_setup.sql`

### M1 데이터 계약

- `public.users.selected_pet_id uuid`는 `public.pets(id) ON DELETE SET NULL`을 참조한다.
- 조회·변경은 `auth.uid()`를 사용하는 신규 RPC로만 수행한다.
- set RPC는 선택하려는 pet의 `pets.user_id = auth.uid()`를 검증한다.
- caller user id 인자를 받지 않는다.
- `SECURITY DEFINER` 사용 시 `search_path`를 고정하고 public 실행권한을 회수한 뒤 authenticated에만 부여한다.
- 기존 K1/H2 함수·정책을 수정하지 않는다.
- migration과 fresh setup SQL은 같은 계약으로 동기화하지만 운영 DB에는 적용하지 않는다.

### 정확한 test manifest

- 신규 `pjh/test/contracts/m1_selected_pet_contract_test.dart`
- 신규 `pjh/test/features/pets/data/pet_selected_repository_test.dart`
- 신규 `pjh/test/features/pets/presentation/bloc/pet_bloc_test.dart`
- 기존 `pjh/test/features/pets/presentation/pages/pet_detail_page_test.dart`
- 기존 `pjh/test/features/pets/presentation/pages/pet_editor_page_test.dart`
- 기존 `pjh/test/features/pets/presentation/pages/pet_management_page_test.dart`
- 신규 `pjh/test/features/pets/presentation/pages/public_pet_page_test.dart`
- 기존 `pjh/test/features/pets/presentation/widgets/pet_card_test.dart`
- 기존 `pjh/test/features/my/pet_life_summary_test.dart`
- 기존 `pjh/test/features/my/pet_summary_section_render_test.dart`
- 기존 `pjh/test/features/my/presentation/pages/my_page_test.dart`
- 신규 `pjh/test/features/my/presentation/pages/my_posts_page_test.dart`
- 기존 `pjh/test/features/my/presentation/pages/my_saved_posts_page_test.dart`
- 기존 `pjh/test/features/my/presentation/pages/my_settings_page_test.dart`
- 기존 `pjh/test/features/my/presentation/widgets/my_profile_header_test.dart`
- 기존 `pjh/test/features/my/presentation/widgets/saved_posts_grid_test.dart`
- 기존 `pjh/test/features/profile/presentation/pages/notification_settings_page_test.dart`
- 기존 `pjh/test/features/profile/presentation/pages/privacy_settings_page_test.dart`
- 기존 `pjh/test/features/profile/presentation/pages/profile_edit_page_test.dart`

### 완료 조건

- 0/1/여러 마리 상태와 대표 선택 pending/success/failure가 구분된다.
- 대표 선택은 RPC 성공 뒤에만 전역 PetBloc에 반영되고 재실행 후 복원된다.
- MY 대표 카드에 가장 가까운 건강 일정이 보이며 건강 데이터 실패가 MY 전체를 막지 않는다.
- 삭제 다이얼로그는 health/emotion/MBTI cascade와 post/walk pet 연결 해제를 구분한다.
- 프로필 편집·설정·알림·개인정보 task 화면에 하단 탭이 없다.

### commit

`[codex] uiux: 반려동물 중심 MY와 대표 선택 계약 구현`

## 9. W3 — Feed + Community + Social Trust

### 화면 매핑

- `C01`~`C12`

### 수동 수정 허용 production manifest

- `pjh/lib/core/navigation/app_router.dart`
- `pjh/lib/features/feed_hub/domain/entities/community_post.dart`
- `pjh/lib/features/feed_hub/presentation/cubit/community_cubit.dart`
- `pjh/lib/features/feed_hub/presentation/cubit/community_state.dart`
- `pjh/lib/features/feed_hub/presentation/pages/create_community_post_page.dart`
- `pjh/lib/features/feed_hub/presentation/pages/feed_hub_page.dart`
- `pjh/lib/features/feed_hub/presentation/widgets/community_post_card.dart`
- `pjh/lib/features/feed_hub/presentation/widgets/post_type_picker_sheet.dart`
- `pjh/lib/features/social/presentation/bloc/bookmark_bloc.dart`
- `pjh/lib/features/social/presentation/bloc/bookmark_event.dart`
- `pjh/lib/features/social/presentation/bloc/bookmark_state.dart`
- `pjh/lib/features/social/presentation/bloc/comment_bloc.dart`
- `pjh/lib/features/social/presentation/bloc/comment_event.dart`
- `pjh/lib/features/social/presentation/bloc/comment_state.dart`
- `pjh/lib/features/social/presentation/bloc/notifications_bloc.dart`
- `pjh/lib/features/social/presentation/bloc/notifications_event.dart`
- `pjh/lib/features/social/presentation/bloc/notifications_state.dart`
- `pjh/lib/features/social/presentation/pages/create_post_page.dart`
- `pjh/lib/features/social/presentation/pages/feed_page.dart`
- `pjh/lib/features/social/presentation/pages/followers_page.dart`
- `pjh/lib/features/social/presentation/pages/hashtag_page.dart`
- `pjh/lib/features/social/presentation/pages/location_picker_page.dart`
- `pjh/lib/features/social/presentation/pages/location_posts_page.dart`
- `pjh/lib/features/social/presentation/pages/notifications_page.dart`
- `pjh/lib/features/social/presentation/pages/post_detail_page.dart`
- `pjh/lib/features/social/presentation/pages/profile_page.dart`
- `pjh/lib/features/social/presentation/pages/search_page.dart`
- `pjh/lib/features/social/presentation/utils/post_draft_storage.dart`
- `pjh/lib/features/social/presentation/widgets/collection_picker_sheet.dart`
- `pjh/lib/features/social/presentation/widgets/comment_composer.dart`
- `pjh/lib/features/social/presentation/widgets/comment_list_item.dart`
- `pjh/lib/features/social/presentation/widgets/comments_bottom_sheet.dart`
- `pjh/lib/features/social/presentation/widgets/likes_bottom_sheet.dart`
- `pjh/lib/features/social/presentation/widgets/notification_card.dart`
- `pjh/lib/features/social/presentation/widgets/post_card.dart`
- `pjh/lib/features/social/presentation/widgets/post_card_actions.dart`
- `pjh/lib/features/social/presentation/widgets/post_card_connector.dart`
- `pjh/lib/features/social/presentation/widgets/post_card_dialogs.dart`
- `pjh/lib/features/social/presentation/widgets/post_card_header.dart`
- `pjh/lib/features/social/presentation/widgets/post_card_media.dart`
- `pjh/lib/features/social/presentation/widgets/social_content_report_sheet.dart`
- `pjh/lib/features/social/presentation/widgets/user_list_tile.dart`
- `pjh/lib/shared/widgets/multi_image_picker.dart`

### 정확한 test manifest

- 기존 `pjh/test/features/feed_hub/domain/community_post_test.dart`
- 기존 `pjh/test/features/feed_hub/presentation/community_cubit_test.dart`
- 신규 `pjh/test/features/feed_hub/presentation/pages/create_community_post_page_test.dart`
- 신규 `pjh/test/features/feed_hub/presentation/pages/feed_hub_page_test.dart`
- 기존 `pjh/test/features/social/data/repositories/social_repository_impl_block_test.dart`
- 기존 `pjh/test/features/social/data/repositories/social_repository_impl_bookmark_test.dart`
- 기존 `pjh/test/features/social/data/repositories/social_repository_impl_follow_test.dart`
- 기존 `pjh/test/features/social/data/repositories/social_repository_impl_like_test.dart`
- 기존 `pjh/test/features/social/data/repositories/social_repository_impl_report_test.dart`
- 기존 `pjh/test/features/social/data/repositories/social_repository_impl_search_test.dart`
- 기존 `pjh/test/features/social/presentation/bloc/bookmark_bloc_test.dart`
- 기존 `pjh/test/features/social/presentation/bloc/comment_bloc_test.dart`
- 기존 `pjh/test/features/social/presentation/bloc/feed_bloc_test.dart`
- 기존 `pjh/test/features/social/presentation/bloc/search_bloc_test.dart`
- 신규 `pjh/test/features/social/presentation/pages/create_post_page_test.dart`
- 기존 `pjh/test/features/social/presentation/pages/feed_comments_entry_test.dart`
- 기존 `pjh/test/features/social/presentation/pages/feed_page_state_test.dart`
- 기존 `pjh/test/features/social/presentation/pages/followers_page_test.dart`
- 기존 `pjh/test/features/social/presentation/pages/hashtag_page_test.dart`
- 기존 `pjh/test/features/social/presentation/pages/location_posts_page_test.dart`
- 신규 `pjh/test/features/social/presentation/pages/notifications_page_test.dart`
- 기존 `pjh/test/features/social/presentation/pages/post_detail_page_test.dart`
- 기존 `pjh/test/features/social/presentation/pages/profile_page_test.dart`
- 기존 `pjh/test/features/social/presentation/pages/search_page_test.dart`
- 기존 `pjh/test/features/social/presentation/widgets/collection_picker_sheet_test.dart`
- 기존 `pjh/test/features/social/presentation/widgets/comment_list_item_test.dart`
- 기존 `pjh/test/features/social/presentation/widgets/comments_bottom_sheet_test.dart`
- 기존 `pjh/test/features/social/presentation/widgets/likes_bottom_sheet_test.dart`
- 기존 `pjh/test/features/social/presentation/widgets/post_card_bookmark_test.dart`
- 기존 `pjh/test/features/social/presentation/widgets/post_card_connector_test.dart`
- 기존 `pjh/test/features/social/presentation/widgets/post_card_like_test.dart`
- 기존 `pjh/test/features/social/presentation/widgets/social_content_report_sheet_test.dart`
- 기존 `pjh/test/features/social/presentation/widgets/user_list_tile_test.dart`
- 기존 `pjh/test/contracts/p2b_block_privacy_contract_test.dart`
- 기존 `pjh/test/core/utils/public_ai_text_test.dart`

### 2026-07-23 W3 audience 보완 manifest

사용자가 아래 6개 경로의 범위 확장을 승인했다. 이 보완은 안전하게 강제되지 않은 팔로워 공개 선택 제거, 빈 피드 CTA의 canonical 작성 화면 연결, 관련 회귀 테스트에만 한정한다.

- `pjh/lib/features/social/presentation/pages/feed_page.dart`
- `pjh/lib/features/social/presentation/widgets/create_post_bottom_sheet.dart`
- `pjh/lib/features/social/presentation/widgets/edit_post_bottom_sheet.dart`
- `pjh/test/features/social/presentation/pages/feed_page_state_test.dart`
- `pjh/test/features/social/presentation/widgets/create_post_bottom_sheet_test.dart`
- `pjh/test/features/social/presentation/widgets/edit_post_bottom_sheet_test.dart`

### 완료 조건

- `피드 / 커뮤니티`와 전체/잡담/자랑/궁금해요/정보가 단일 언어로 표시된다.
- 스토리형 원형 행이 없다.
- feed composer는 사진 최대 10장과 전체 공개만 표시하며 동영상을 약속하지 않는다.
- community는 legacy caption을 안전하게 제목/본문으로 파싱하고 빈 제목 legacy 글도 렌더링한다.
- 댓글 parent id, 신고 사유, K1 차단, 저장 collection과 낙관적 UI rollback을 보존한다.
- `모두 읽음`은 서버 성공 후에만 반영된다.
- 공개 AI 텍스트에 confidence 백분율이 없다.

### commit

`[codex] uiux: 피드와 커뮤니티 소셜 신뢰 흐름 정리`

## 10. W4 — Health Care

### 화면 매핑

- `D01`~`D07`

### 수동 수정 허용 production manifest

- `pjh/lib/core/navigation/app_router.dart`
- `pjh/lib/features/health/presentation/bloc/health_bloc.dart`
- `pjh/lib/features/health/presentation/bloc/health_event.dart`
- `pjh/lib/features/health/presentation/bloc/health_state.dart`
- `pjh/lib/features/health/presentation/pages/health_alert_settings_page.dart`
- `pjh/lib/features/health/presentation/pages/health_main_page.dart`
- `pjh/lib/features/health/presentation/pages/health_pdf_preview_page.dart`
- 신규 `pjh/lib/features/health/presentation/pages/health_record_editor_page.dart`
- `pjh/lib/features/health/presentation/widgets/emotion_trend_mini_chart.dart`
- `pjh/lib/features/health/presentation/widgets/health_pdf_data.dart`
- `pjh/lib/features/health/presentation/widgets/health_pdf_generator.dart`
- `pjh/lib/features/health/presentation/widgets/health_record_card.dart`
- `pjh/lib/features/health/presentation/widgets/health_record_data.dart`
- 신규 `pjh/lib/features/health/presentation/widgets/health_record_form.dart`
- `pjh/lib/features/health/presentation/widgets/health_record_sheets.dart`
- `pjh/lib/features/health/presentation/widgets/weight_trend_chart.dart`
- `pjh/lib/core/services/local_notification_service.dart`

`health_record_sheets.dart`는 새 full screen editor로 이동하는 동안 기존 호출 호환과 안전한 제거를 위해서만 수정한다. 삭제가 필요하면 같은 wave에서 모든 참조 0건과 test 통과를 확인한 후 별도 보고한다.

### 정확한 test manifest

- 기존 `pjh/test/contracts/h1_health_contract_test.dart`
- 기존 `pjh/test/contracts/h1b_health_ui_contract_test.dart`
- 기존 `pjh/test/core/services/local_notification_service_test.dart`
- 기존 `pjh/test/features/health/domain/entities/health_record_test.dart`
- 기존 `pjh/test/features/health/domain/usecases/health_usecases_test.dart`
- 기존 `pjh/test/features/health/presentation/bloc/health_bloc_test.dart`
- 기존 `pjh/test/features/health/presentation/emotion_trend_chart_test.dart`
- 기존 `pjh/test/features/health/presentation/health_alert_settings_page_test.dart`
- 기존 `pjh/test/features/health/presentation/health_emotion_loader_test.dart`
- 신규 `pjh/test/features/health/presentation/health_main_page_test.dart`
- 기존 `pjh/test/features/health/presentation/health_pdf_data_test.dart`
- 신규 `pjh/test/features/health/presentation/health_pdf_preview_page_test.dart`
- 기존 `pjh/test/features/health/presentation/health_record_card_test.dart`
- 기존 `pjh/test/features/health/presentation/health_record_data_test.dart`
- 신규 `pjh/test/features/health/presentation/health_record_editor_page_test.dart`
- 기존 `pjh/test/features/health/presentation/weight_trend_test.dart`

### 완료 조건

- 다음 케어가 최근 기록보다 위에 있고 root FAB 대신 명확한 추가 CTA를 사용한다.
- 예방접종/검진/체중/투약/수술의 필수·선택값과 날짜·상태가 인라인 검증된다.
- 기존 빈 vaccine type 기록은 열 수 있고 저장 시 사용자에게 보완을 요청한다.
- 삭제 대상과 추이·PDF 영향, 복구 불가를 명시한다.
- PDF 미리보기·저장·공유 실패가 안전하며 진단 표현과 공개 confidence가 없다.
- 자동 알림은 `준비 중`, 5초 테스트는 permission/scheduled/unavailable/failed를 구분한다.
- H1 owner contract와 root navigator/context.mounted 안전성이 유지된다.

### commit

`[codex] uiux: 다음 케어 중심 건강 기록 흐름 구현`

## 11. W5 — Chat + Notification Finish

### 화면 매핑

- `D08`~`D12`
- `B10`, `B11`
- `C11`

### 수동 수정 허용 production manifest

- `pjh/lib/core/navigation/app_router.dart`
- `pjh/lib/features/chat/presentation/bloc/chat_detail/chat_detail_bloc.dart`
- `pjh/lib/features/chat/presentation/bloc/chat_detail/chat_detail_event.dart`
- `pjh/lib/features/chat/presentation/bloc/chat_detail/chat_detail_state.dart`
- `pjh/lib/features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc.dart`
- `pjh/lib/features/chat/presentation/bloc/chat_rooms/chat_rooms_event.dart`
- `pjh/lib/features/chat/presentation/bloc/chat_rooms/chat_rooms_state.dart`
- `pjh/lib/features/chat/presentation/pages/chat_detail_page.dart`
- `pjh/lib/features/chat/presentation/pages/chat_room_settings_page.dart`
- `pjh/lib/features/chat/presentation/pages/chat_rooms_page.dart`
- `pjh/lib/features/chat/presentation/pages/create_chat_page.dart`
- `pjh/lib/features/chat/presentation/widgets/chat_bubble.dart`
- `pjh/lib/features/chat/presentation/widgets/chat_input_bar.dart`
- `pjh/lib/features/chat/presentation/widgets/chat_report_sheet.dart`
- `pjh/lib/features/chat/presentation/widgets/chat_room_tile.dart`
- `pjh/lib/features/profile/presentation/pages/notification_settings_page.dart`
- `pjh/lib/features/profile/presentation/pages/privacy_settings_page.dart`
- `pjh/lib/features/social/presentation/pages/notifications_page.dart`
- `pjh/lib/shared/widgets/image_source_picker.dart`

### 정확한 test manifest

- 기존 `pjh/test/features/chat/data/repositories/chat_block_filter_test.dart`
- 기존 `pjh/test/features/chat/data/repositories/chat_repository_impl_test.dart`
- 기존 `pjh/test/features/chat/domain/usecases/report_chat_target_test.dart`
- 기존 `pjh/test/features/chat/presentation/bloc/chat_detail/chat_detail_bloc_test.dart`
- 기존 `pjh/test/features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc_test.dart`
- 기존 `pjh/test/features/chat/presentation/pages/chat_detail_page_test.dart`
- 기존 `pjh/test/features/chat/presentation/pages/chat_room_settings_page_test.dart`
- 기존 `pjh/test/features/chat/presentation/pages/chat_rooms_page_test.dart`
- 기존 `pjh/test/features/chat/presentation/pages/create_chat_page_test.dart`
- 기존 `pjh/test/features/chat/presentation/widgets/chat_bubble_test.dart`
- 기존 `pjh/test/features/chat/presentation/widgets/chat_input_bar_test.dart`
- 기존 `pjh/test/features/chat/presentation/widgets/chat_room_tile_test.dart`
- 기존 `pjh/test/features/profile/presentation/pages/notification_settings_page_test.dart`
- 기존 `pjh/test/features/profile/presentation/pages/privacy_settings_page_test.dart`
- 신규 `pjh/test/features/social/presentation/pages/notifications_page_test.dart`
- 기존 `pjh/test/contracts/p2a1_notification_contract_test.dart`
- 기존 `pjh/test/contracts/p2b_block_privacy_contract_test.dart`

### 완료 조건

- 목록 initial load와 refresh failure를 구분하고 기존 대화를 유지한다.
- 1명은 direct, 2명 이상은 group이며 생성 pending 중 검색·선택을 비활성화한다.
- 텍스트와 사진 최대 10장의 실패 payload를 보존하고 동일 요청을 재전송할 수 있다.
- 직접방 신고·차단과 그룹 참여자 신고·차단이 K1 계약을 따른다.
- 관리자만 방 이름·사진·초대가 가능하고 일반 참여자는 읽기 전용이다.
- 멤버 강제 퇴장과 가짜 방별 알림 switch가 없다.
- 나가기 성공 전 방 목록 이동이나 성공 안내를 하지 않는다.

### commit

`[codex] uiux: 채팅과 알림의 실패 복구 흐름 정리`

## 12. W6 — Documentation + Full QA

### 수동 수정 허용 documentation manifest

- `docs/README.md`
- `docs/DEVELOPER_GUIDE.md`
- `docs/FUNCTIONAL_SPEC.md`
- `docs/USER_FLOW.md`
- `docs/qa/RELEASE_DEPLOY_VERIFY_CHECKLIST.md`
- `docs/reviews/2026-07-22-uiux-product-trust-audit.md`
- `docs/mockups/2026-07-22-uiux-direction-discussion.md`
- `docs/work-orders/2026-07-22-uiux-trust-redesign-master.md`

### 정확한 cross-contract test manifest

- `pjh/test/contracts/auth_log_redaction_contract_test.dart`
- `pjh/test/contracts/h1_health_contract_test.dart`
- `pjh/test/contracts/h1b_health_ui_contract_test.dart`
- `pjh/test/contracts/m1_selected_pet_contract_test.dart`
- `pjh/test/contracts/p2a1_notification_contract_test.dart`
- `pjh/test/contracts/p2b_block_privacy_contract_test.dart`
- `pjh/test/contracts/post_merge_simulator_contract_test.dart`
- `pjh/test/contracts/public_error_message_contract_test.dart`
- `pjh/test/core/utils/public_ai_text_test.dart`
- `pjh/test/widget_test.dart`

### 자동 검증 명령

모든 명령은 정확히 다음 순서로 실행한다.

```bash
cd pjh
dart format --output=none --set-exit-if-changed <해당 wave에서 실제 수정된 Dart 파일의 개별 경로>
flutter analyze --no-pub
flutter test --no-pub <해당 wave test manifest의 개별 경로>
flutter test --no-pub
flutter build ios --release --no-codesign --no-pub
cd ..
git diff --check
rg -n '^(<<<<<<<|=======|>>>>>>>)' pjh/lib pjh/test supabase docs
```

`dart format`과 집중 test는 실행 직전 실제 수정 경로를 공백 구분 개별 인자로 펼친다. 디렉터리·glob·`관련 테스트` 표현을 명령에 사용하지 않는다.

### 시뮬레이터 자동·수동 확인

- iPhone 17 Simulator, 390×844, light/dark mode
- 320×568 논리 크기 widget test
- text scale 100%, 150%, 200%
- 로그인 선택 → 이메일 로그인/회원가입 → 약관 실패/재시도 → 프로필 → 펫 건너뛰기/등록
- MY 0/1/여러 마리 → 대표 선택 재실행 복원 → 다음 건강 일정 → 편집·삭제 확인
- 피드/커뮤니티 전환 → 사진 1/10장 작성 → validation/pending/failure → 상세·댓글·답글·좋아요·저장
- 검색 → 사용자 팔로우 → 신고 시트 취소 → K1 test 계정 간 차단·해제
- 건강 5종 add/edit/delete → 필터 empty → 추이 → PDF preview → 알림 권한 허용/거부
- 채팅 목록 → 1:1 → 그룹 → 텍스트/1장/10장 → 실패 재전송 → 관리자/멤버 설정 → 나가기

게시·팔로우·메시지·차단·해제는 운영 사용자 대신 별도 QA 계정 2개가 준비된 경우에만 실행한다. 신고 접수와 실제 사용자 데이터 삭제는 별도 사용자 승인 없이 실행하지 않는다.

### 최종 read-only review

1. `git diff --name-status`가 승인된 wave manifest의 합집합 안인지 확인한다.
2. Apple/OAuth·URL scheme·entitlement 보호 diff가 0인지 확인한다.
3. K1/H2/H1, `auth.uid()` RPC, 광범위 users SELECT 금지, caller-id RPC 금지를 확인한다.
4. public AI confidence, 진단 오인 문구, 동영상·자동 알림·멤버 강제 퇴장 과대약속을 검색한다.
5. health root navigator/context.mounted와 iPad shareHandler/shareOrigin이 보존됐는지 확인한다.
6. staged manifest에 비밀 파일이 없고 `pjh/lib/config/secrets.dart`가 untracked ignored인지 확인한다.
7. blocker/high와 신규 검증 실패가 0일 때만 로컬 최종 commit을 허용한다.

### commit

`[codex] docs: UIUX 전면 개선 검증 정본 갱신`

## 13. 실행 순서와 commit 정책

1. 기획 문서와 목업을 현재 기획 브랜치에 로컬 commit한다.
2. 같은 전용 worktree에서 W0 → W1 → W2 → W3 → W4 → W5 → W6 순서로 진행한다.
3. 각 wave의 test가 통과하기 전 다음 wave production 파일을 수정하지 않는다.
4. migration 파일은 작성·정적 계약 test만 수행하며 운영 적용하지 않는다.
5. W6 완료 뒤 실제 해결·수정 파일의 SHA-256 manifest와 최종 read-only review를 생성한다.
6. 원격 push와 release branch 반영은 별도 사용자 승인 전까지 실행하지 않는다.

## 14. 기획 3-pass 결과

| 패스 | 확인 기준 | 결과 |
|---|---|---|
| 1 | 목업→화면→production/test 경로 완전성 | A01~D12를 W0~W5에 모두 배정. 홈·AI 콘텐츠 제외와 shell 회귀 범위를 분리 |
| 2 | 보안·데이터·법무 계약 | K1/H2/H1, Apple/OAuth, public AI, 비밀 파일을 보호. 대표 pet은 auth.uid 전용 M1 migration으로 격리 |
| 3 | 실행·검증·중단 가능성 | wave별 수정·test 경로를 개별 열거하고 commit·집중 test·전체 test·iOS build·최종 read-only review를 고정 |

기획 단계 blocker/high는 없다. 구현 중 manifest 밖 변경이나 보호 계약 변경이 필요하면 해당 wave를 중단한다.

## 15. 2026-07-22 로컬 실행 기록

| wave | commit | 결과 |
|---|---|---|
| W0 | `e74bdb4` | 공용 내비게이션·신뢰 디자인 기반 완료 |
| W1 | `8109624` | 인증·온보딩 실패 복구와 접근성 완료 |
| W2 | `b3cfa2a` | 대표 반려동물·MY·M1 로컬 계약 완료 |
| W3 | `50afdce` | 피드·커뮤니티·작성·소셜 신뢰 흐름 완료 |
| W4 | `2283445` | 다음 케어·건강 5종 full task editor 완료 |
| W5 | `dda37b4` | 채팅·알림 실패 복구·dark mode 완료 |
| W6 | 문서 정본 commit | W3 audience 보완·문서 정합성·최종 회귀 검증 완료 |

W5 종료 시점에 지정 테스트 98건을 통과했다. W6에서는 audience 보완 집중 테스트 9건, cross-contract 50건, 전체 테스트 788건, analyze 0 issues, iOS release no-codesign build를 다시 통과했다. `git diff --check`, 충돌 표식 검색과 iPhone 17 Simulator light/dark 및 320×568·200% 글자 검토에서 발견한 문제는 승인된 보완 manifest 안에서 수정 후 재검증했다.

Claude·Anthropic 외부 전송은 사용자 지시에 따라 제외했다. 원격 push, `mac-ios-release` 반영, 운영 DB/RPC·Edge·APNs, signing, TestFlight, 스토어 배포는 실행하지 않았다. 격리 QA 계정 2개와 실제 iOS/Android 기기가 필요한 전수 E2E는 출시 전 잔여 검증이다.

### W6 audience 발견·해결 기록

- 발견: `pjh/lib/features/social/presentation/widgets/create_post_bottom_sheet.dart`와 `pjh/lib/features/social/presentation/widgets/edit_post_bottom_sheet.dart`가 안전한 audience 강제 전에 `팔로워만`을 노출하고 `is_private`를 저장한다.
- 도달 경로: 빈 피드 작성 CTA와 피드·해시태그·위치·게시물 상세 편집.
- 최초 판정: 사용자 개인정보 기대를 잘못 만들 수 있는 high. W3/W6 수동 수정 manifest 밖이므로 임의 수정하지 않고 중단했다.
- 해결: 2026-07-23 사용자가 아래 exact 경로의 W3 보완 manifest 추가를 승인했다. 코드·테스트 로컬 commit은 `ec579fc`다.
  - `pjh/lib/features/social/presentation/pages/feed_page.dart`
  - `pjh/lib/features/social/presentation/widgets/create_post_bottom_sheet.dart`
  - `pjh/lib/features/social/presentation/widgets/edit_post_bottom_sheet.dart`
  - `pjh/test/features/social/presentation/pages/feed_page_state_test.dart`
  - `pjh/test/features/social/presentation/widgets/create_post_bottom_sheet_test.dart`
  - `pjh/test/features/social/presentation/widgets/edit_post_bottom_sheet_test.dart`
- 결과: 빈 피드 CTA를 canonical `/create-post`로 연결했고, 레거시 작성은 전체 공개만 생성하며 레거시 편집은 기존 audience를 바꾸지 않는다. light/dark 실화면과 320×568·200% 회귀를 포함해 재검증했다.

## 16. W0~W6 실제 변경 파일 SHA-256 manifest

- 기준: W0 시작 직전 `db3a65c` 대비 W0~W6 로컬 commit과 W6 정합성 문서의 실제 변경 합집합
- 파일 수: **153개**
- 정렬: path 오름차순
- manifest SHA-256: `f0d88feb695fc0a2765be5e005f4c9bbe752190ab90dd22b16e6037182cbca7b`
- 해시 입력: 아래 Markdown table row의 UTF-8 bytes(각 행 LF 포함)
- carrier 제외: 이 표를 담는 `docs/work-orders/2026-07-22-uiux-trust-redesign-master.md`는 자기 해시 재귀를 피하기 위해 파일 manifest에서 제외한다.
- 비밀 제외: `pjh/lib/config/secrets.dart`, Google service 설정, 환경 파일, 인증서·키·provisioning profile, 로그·빌드 생성물은 포함하지 않는다.

| path | SHA-256 |
|---|---|
| `docs/DEVELOPER_GUIDE.md` | `aa7553dd024e8c18a2244481fec2f0498ee73cdd00da646c7a173da0e9b134ab` |
| `docs/FUNCTIONAL_SPEC.md` | `f4efaab9520d46f38d20a121da11cae6a0b455a865d9875a2f93466c41b56091` |
| `docs/README.md` | `a1b71693b1d925a3e482f0720fbf024985a03a2a59f982c92889fbab9c23665a` |
| `docs/USER_FLOW.md` | `a74461c3852d29b1d3b784204675f76440bcfe29d8a1ee9717cac357d4332844` |
| `docs/mockups/2026-07-22-uiux-direction-discussion.md` | `1153056657937bdffccf0b5f42b3a769605e8c3de58fa6ef44a1515998532493` |
| `docs/qa/RELEASE_DEPLOY_VERIFY_CHECKLIST.md` | `32af5d7c4c0e47c1eaa5a659b3b0f082cf5896aeec75dca3517ef3d107fe446b` |
| `docs/reviews/2026-07-22-uiux-product-trust-audit.md` | `9e272b7f04949c989fa334751de9a3c691963c84f42b5b575be9f245a74d0cf8` |
| `pjh/lib/config/injection_container.dart` | `704e9d28a50e253a5f542acfba960aecccdd2c30726328ed140a600c3963a2f4` |
| `pjh/lib/core/error/error_messages.dart` | `af4648899d8bae38678430122bee218381bd1cfccc0c453ca39112f9e2169895` |
| `pjh/lib/core/navigation/app_router.dart` | `c2a9d0e11172466040800ac1a46fb914d63f6e17ce74a11caa436ebc4d18467c` |
| `pjh/lib/features/auth/presentation/bloc/auth_bloc.dart` | `33971cf33f31481ae2237b4ae3c4d9e8939069a25738727b2ed22a3058415168` |
| `pjh/lib/features/auth/presentation/bloc/auth_state.dart` | `010dd98fb15308949a5a683872a56fd2b5d46439dd3f04372a5c0d2ceb7d0721` |
| `pjh/lib/features/auth/presentation/pages/kakao_consent_page.dart` | `4b0ba29778f5ea56b3e0cef97d551b22a11aad712f6b5e6c9d702f1e551bc9cd` |
| `pjh/lib/features/auth/presentation/pages/password_reset_new_password_page.dart` | `7af0551c04064c93a713771864be1b8074abdd0a96af205a3cebcb933d2961f1` |
| `pjh/lib/features/auth/presentation/pages/password_reset_request_page.dart` | `186df0f250979b6427cf4edc601404113529b6246ec8d1c9935a24dd6c8a1576` |
| `pjh/lib/features/auth/presentation/pages/password_reset_verification_page.dart` | `1c29193e673d7cf4c2c48b6aad78c452f78164cafa7c5774e2d2f6d4e339fb18` |
| `pjh/lib/features/auth/presentation/pages/terms_agreement_page.dart` | `cfeb93a4adeb223476d57cc5cd88eb023bece15278279d231eafdcd278d4127a` |
| `pjh/lib/features/auth/presentation/widgets/social_login_button.dart` | `a5483f0f62eb0e904a6347b83bc1fd35c7bd007b971d7cd15249b5515170de50` |
| `pjh/lib/features/chat/presentation/bloc/chat_detail/chat_detail_bloc.dart` | `031b0fa1f422d0add152095c1e4c7bce7d1c69209ec72df206304547da8dc444` |
| `pjh/lib/features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc.dart` | `38fdcd3c767466cf6c63432ac4760350a8e18a47a5eac32974f8eac1dd3902c2` |
| `pjh/lib/features/chat/presentation/pages/chat_detail_page.dart` | `df8852f2aee9af5e87008eb59fb68fe65a5f4cd16fc8ef37e69b38476a0d1871` |
| `pjh/lib/features/chat/presentation/pages/chat_room_settings_page.dart` | `4ecf1a3bd7b2a4fef60d16c95e6f7d97a2f5a2f19d31cc9467cd708332cdb25e` |
| `pjh/lib/features/chat/presentation/pages/create_chat_page.dart` | `9850961007cc875d8419946d3bc68f932f97b6aca6213fc4bdc7bec346e2d49a` |
| `pjh/lib/features/chat/presentation/widgets/chat_bubble.dart` | `aec9042c225afb91f294958460202783bbe55796541bf3003f0398097c8bba9d` |
| `pjh/lib/features/chat/presentation/widgets/chat_input_bar.dart` | `aa7cfe94f49f0e9d36c3a7a1a1e3ceb8b3bbca0828e1044f83f0d6d596e56574` |
| `pjh/lib/features/feed_hub/domain/entities/community_post.dart` | `520fd17c3419c5f1b63a1f0b7307097b9dc7c8bd40024aebb0338f71395e28fd` |
| `pjh/lib/features/feed_hub/presentation/cubit/community_cubit.dart` | `1a6ea1f64a678b1b5634496353c0bb3cbaccad20dc6728d9faa548c4dab3c629` |
| `pjh/lib/features/feed_hub/presentation/pages/create_community_post_page.dart` | `b5e0f16d3850104de8de09abb60cd441f56fd0d7620616773ed473f5c556b3fb` |
| `pjh/lib/features/feed_hub/presentation/pages/feed_hub_page.dart` | `3f821d1f6acb2f164470ec9d257eb408ffa60a8d65512f35abb253ed130a3175` |
| `pjh/lib/features/feed_hub/presentation/widgets/community_post_card.dart` | `4f6221f476d4cd87b589b85d7c430724b45be3761129da5f0aa73a9360e186c6` |
| `pjh/lib/features/health/presentation/bloc/health_bloc.dart` | `044b774878c68011f89328ea3e6f0b45151959d8436056a89794d4ddc99b24c8` |
| `pjh/lib/features/health/presentation/pages/health_alert_settings_page.dart` | `4e0adabdc2d499f0f39f8cc97c41fa9eebf649a88f2cb96c7d8938b79e227015` |
| `pjh/lib/features/health/presentation/pages/health_main_page.dart` | `e74df8108cfe78a5f71363a7589ba629812e3289926d39fcdfecf859b3748d16` |
| `pjh/lib/features/health/presentation/pages/health_pdf_preview_page.dart` | `a5345aa719ce2d2e2a2c8cf12e4546f040b199e67f245d6959e348d03e5918ec` |
| `pjh/lib/features/health/presentation/pages/health_record_editor_page.dart` | `2d2be06b95597ba5123c8f56bb4e3d4ac54b6ee0e93994c393d3d5f749030b62` |
| `pjh/lib/features/health/presentation/widgets/health_pdf_generator.dart` | `b18ab6c38ff44a520c0acb3b0ea2eedb2cd79282d46dcea31d277f5ac166eb43` |
| `pjh/lib/features/health/presentation/widgets/health_record_data.dart` | `36f3c03d68d5d7a3bc1acf2e6b35c363e062f5c23e12f721a4c096bccbf945c8` |
| `pjh/lib/features/health/presentation/widgets/health_record_form.dart` | `4454704fd8b6ff912b54ffda163461b44c1bd6fc848f11ae8a10ac9621a4f4f0` |
| `pjh/lib/features/health/presentation/widgets/health_record_sheets.dart` | `59032eb121bc8c2f9d401f848c649bb03f0bad9494eb225f61fe856076b2e650` |
| `pjh/lib/features/my/presentation/controllers/my_next_health_loader.dart` | `f49f873214354ba89d9f53196322ebd5e1fbc8ce9e241d3b9bbc8869be6469d8` |
| `pjh/lib/features/my/presentation/pages/my_page.dart` | `c3aacea5c3f5b29e680eaa612cf8b44dfee2d944769d105ca7ff6147e173a657` |
| `pjh/lib/features/my/presentation/pages/my_posts_page.dart` | `7027853d4f85481cc0da335e3a3c6bce6307ae09dbecf68f0dab327a7f15e6ed` |
| `pjh/lib/features/my/presentation/pages/my_saved_posts_page.dart` | `59d6b50f5ce188ed7b9d3dff371708d7c971ee5171209e5e7f0d0d74d32dd9cb` |
| `pjh/lib/features/my/presentation/widgets/my_pet_summary_section.dart` | `b345afa3db093fb60e3392779df2f73d66f470bb84ec5975af302e867ec26b6d` |
| `pjh/lib/features/my/presentation/widgets/my_profile_header.dart` | `5b71cd3755a120ec8f4452b782ec8efa7140a53d359319b7a6edd64afd8b92a1` |
| `pjh/lib/features/my/presentation/widgets/saved_posts_grid.dart` | `bfad6c4216e001473848f1b5aae9a8fd6d81c6c2fb119ce5f678e473bc4889bc` |
| `pjh/lib/features/onboarding/presentation/bloc/onboarding_bloc.dart` | `6c34e061b0cbf1a865ab7ead74eb7906dc31fa2b747a10684b8dd773b70db996` |
| `pjh/lib/features/onboarding/presentation/pages/onboarding_complete_page.dart` | `40fe50ef4c46567b95cce7deef5a72a6400556cd39e744668d6f51d52be33527` |
| `pjh/lib/features/onboarding/presentation/pages/onboarding_email_verification_page.dart` | `1f3d9530a5de1d8e59940c6b9356b52efeb4d5fd9ba9dfbc4229434b9e12e61b` |
| `pjh/lib/features/onboarding/presentation/pages/onboarding_login_page.dart` | `2d94db96cafe1576bccec534fd6fd79d0498a99dcf5cd605ffe9a2c1c38b950f` |
| `pjh/lib/features/onboarding/presentation/pages/onboarding_pet_registration_page.dart` | `c4a3a0176d11f5b00d08a12055d37bcb3f6d14a1a28138446365ab210fddd492` |
| `pjh/lib/features/onboarding/presentation/pages/onboarding_profile_setup_page.dart` | `0f6959818f116331a68b1af027881a67b451abe376d7ebf128b837043144ca68` |
| `pjh/lib/features/onboarding/presentation/pages/splash_page.dart` | `44a640d8309b2f6b11485853795be43312dc17529078a3591c3ab3beae1c67f3` |
| `pjh/lib/features/pets/data/repositories/pet_repository_impl.dart` | `889c63780d2317d41c053776e40e1473cb9b2bf0763dc311bda60f508a2fd89c` |
| `pjh/lib/features/pets/domain/repositories/pet_repository.dart` | `e16f19a1e2d2db6c12ae8375a011c4465ae7971b782087a9b13e335dbaa58358` |
| `pjh/lib/features/pets/domain/usecases/get_selected_pet_id.dart` | `5cc4030bab4e6cfcc242d7e08a250040e716c7d40ba7bea7daafb7cab341e3c4` |
| `pjh/lib/features/pets/domain/usecases/set_selected_pet_id.dart` | `fd5d16262f5d58251095aeaa9f4905aba2180642ee95754c0196f4a3f3faec12` |
| `pjh/lib/features/pets/presentation/bloc/pet_bloc.dart` | `2e0dd31f938d836867cc2cb9263eda1ffec07058d22b854a29dfa4065cc86ec1` |
| `pjh/lib/features/pets/presentation/bloc/pet_state.dart` | `f152a2666cc8bb3ed7781043a565bcb30da4a448ef717a77e5c020591cd63ebe` |
| `pjh/lib/features/pets/presentation/pages/pet_detail_page.dart` | `8ef88c79a79d077e82a5a770a6efcb3ac916818f4b468ed67142800556ff5c38` |
| `pjh/lib/features/pets/presentation/pages/pet_management_page.dart` | `c606b8fd72ea0ab0e29317e781afebd815fcaeb19b930fce83f6fd85c666b0bd` |
| `pjh/lib/features/pets/presentation/pages/public_pet_page.dart` | `f414f8b803cbfb04da370f5e1747a7f9e798ba98bf5e7565c334f226d1958aec` |
| `pjh/lib/features/pets/presentation/widgets/pet_card.dart` | `618cab197df43e4ac7c36c553c3e88c7a9ae4758b33abdc552321aa1187f0526` |
| `pjh/lib/features/profile/presentation/pages/notification_settings_page.dart` | `221e4203cf076d58e2d629a6f412d05808255cc09b23b55570f95701f1791ac4` |
| `pjh/lib/features/profile/presentation/pages/profile_edit_page.dart` | `15d3e116bf293931c2b78d47a83008126c6a8cda20fb6048c75e8f1fea641629` |
| `pjh/lib/features/social/presentation/bloc/notifications_bloc.dart` | `2a1b1b0906fecee3740c0b4c94e73a29f9a4fb236ecb59ba4fff2bc3dadff20b` |
| `pjh/lib/features/social/presentation/bloc/notifications_state.dart` | `136e4dcc69938239ad0991698da71d85cef25ab9f41ce937f9ee40e33283e858` |
| `pjh/lib/features/social/presentation/pages/create_post_page.dart` | `f77e4d12dbe4f2c639a223d1a08f389adf47eb3724b2c43123d83059245c68dc` |
| `pjh/lib/features/social/presentation/pages/feed_page.dart` | `b1c0e0060f88a9201bce6bf14f646a4bad73b1881cc91c160620416abbf55b88` |
| `pjh/lib/features/social/presentation/pages/hashtag_page.dart` | `89591b5a6bfbd5f9ca915d71a66bb92308c570953c6099374158ae823c11e9a2` |
| `pjh/lib/features/social/presentation/pages/location_picker_page.dart` | `ac92a0669892489b2434744699ebd9bb11c9dbffa757fd01f7bf49fcb71e42ca` |
| `pjh/lib/features/social/presentation/pages/location_posts_page.dart` | `b9395179d1f530a3f4bfde6dad840a4151554516725e5630ff643c88f495d8c1` |
| `pjh/lib/features/social/presentation/pages/notifications_page.dart` | `074da5c03d888a3f758a0c4306b972c1c912772ae285be625d6a6c36c44319c8` |
| `pjh/lib/features/social/presentation/pages/post_detail_page.dart` | `08d7fc2e11d88eea0607734e39f52f458049ac0d69fa5af27fa2cbe784e69566` |
| `pjh/lib/features/social/presentation/pages/search_page.dart` | `f63133bff882afd315511c07dea2fc3a8275c2c55ce80c8716512355fcef37da` |
| `pjh/lib/features/social/presentation/utils/post_draft_storage.dart` | `3c98d2d401f8d23531c5699a01b75bd737c93a9a7604d9b21bd52d287cbb4fd9` |
| `pjh/lib/features/social/presentation/widgets/create_post_bottom_sheet.dart` | `551a0ce4d0fca46291a18ae5ca92af958f0a540be5bbb1c477c0d7cf7b63ebab` |
| `pjh/lib/features/social/presentation/widgets/edit_post_bottom_sheet.dart` | `9d4f3f9e88237cbd3db15c5af25aacec4ed96e134f7fad370c1c59dedf836f5a` |
| `pjh/lib/features/social/presentation/widgets/notification_card.dart` | `857484793dd572447ae1fcefc1525968a1363b4ec20b91ad8a731acb8a7db5ec` |
| `pjh/lib/features/social/presentation/widgets/post_card.dart` | `9fa99830b44c850cd53ff9e7c153ebb902338c77dbf4957ed419fb83818c57b1` |
| `pjh/lib/features/social/presentation/widgets/post_card_actions.dart` | `d63af31a33dd1bc52e163814f2e2a7d3740f003e325dd954f31c8c8817cd6cef` |
| `pjh/lib/features/social/presentation/widgets/post_card_dialogs.dart` | `cc4e29df82ebef806582b481774b48e102305a828f421d9e8c013ab6eb63ea6d` |
| `pjh/lib/features/social/presentation/widgets/post_card_header.dart` | `7edebd3ab346ef8a33d13607cb26823b4cd77b3aa3d32fee3bdfc3eafe0897e2` |
| `pjh/lib/main_navigation.dart` | `20b584cd9b3e0e758b7fd1f8661a868f91676d991fa1256513ffecba6186a528` |
| `pjh/lib/shared/models/navigation_item.dart` | `d37c7493ef40b1e1706c16e53e441e0ba5a0fe10ce348e57a7e2cadd76a6e045` |
| `pjh/lib/shared/themes/app_theme.dart` | `dc1050e00bdfdee62516002166c7292f41b650ed75a4b07541344fec15bb0b11` |
| `pjh/lib/shared/widgets/category_chip.dart` | `91ab73ca80870e59bc7afd7c7d96f95eee89d6b4178275bec4106cd688fa6037` |
| `pjh/lib/shared/widgets/info_box.dart` | `280c00570aec5d03a3f50627da69bb6cafaa7492d747a04239ffa180fc5d1322` |
| `pjh/lib/shared/widgets/multi_image_picker.dart` | `e6ee64bdd5664936577f49bfee0ec72230318b7b96c39e4a5f7148da283b1f01` |
| `pjh/lib/shared/widgets/petspace_app_bar.dart` | `0a1642707f6d517dd2ee118d9d1e9f8adb10ec4966e5352f326a91124c8dd78d` |
| `pjh/lib/shared/widgets/petspace_page_scaffold.dart` | `a2d06eeb042413b1c5b1588aebdd1564d55ff43fdfe9b1a5e655815f71500621` |
| `pjh/lib/shared/widgets/petspace_settings_components.dart` | `0a2cf5723bba7623940279dd2c4f52078013d109fc1292bc6088f65a52ac9106` |
| `pjh/lib/shared/widgets/petspace_state_view.dart` | `debc8ae7b6ee30f690ac55d3063d5e165f7f047ac0ebf6446806ad77f774f846` |
| `pjh/lib/shared/widgets/section_header.dart` | `11c71da1d37affcee6eb122c7efbeaf4ab551d2ea93bd0615c389612e8431028` |
| `pjh/test/contracts/auth_log_redaction_contract_test.dart` | `74f13235374823d112945785d62a17050a8f9dddefaa44c1a015585cacbdf427` |
| `pjh/test/contracts/h1b_health_ui_contract_test.dart` | `cf929a7284a992d0e4a232de9706ff7c72b1d01312423b44ddaf5a53254aa0b2` |
| `pjh/test/contracts/m1_selected_pet_contract_test.dart` | `274f493827a20ea7a78145ecc7c62b8b46059f2cb277e645feddec3f149219c2` |
| `pjh/test/contracts/public_error_message_contract_test.dart` | `68410a65141ea439641440cb83b9e9456134c98178278f2a41d05739f38b14dc` |
| `pjh/test/features/auth/presentation/bloc/auth_bloc_test.dart` | `9214331cfb2c52deb1cf4f5041855570bbf51113e0991d8a93b8da543e88fa79` |
| `pjh/test/features/auth/presentation/pages/kakao_consent_page_test.dart` | `7eeae1fd5a64940630bf3822e3ad5ddfbea03117de61085cc71d841586cee1e7` |
| `pjh/test/features/auth/presentation/pages/password_reset_new_password_page_test.dart` | `b5f8adced0d963c62651a116149d5ee9cc547a513d737954fd363647ca45546e` |
| `pjh/test/features/auth/presentation/pages/password_reset_request_page_test.dart` | `ee03e454778ede38b18e6f86acd6be84c258aeb69bada2bee71626ba697e1df6` |
| `pjh/test/features/auth/presentation/pages/password_reset_verification_page_test.dart` | `33b3ba07acd981bfd641dc4f89011d09abbfa7f3765dd74b4ee43319fa70672b` |
| `pjh/test/features/auth/presentation/pages/terms_agreement_page_test.dart` | `d589401cbd1246bded56479636e4609b79f8d160082232a1ce69eec38bdfade1` |
| `pjh/test/features/auth/presentation/pages/terms_detail_page_test.dart` | `b699aad9d9c0c7df30e06684badd651ca24497244df906c3e5555e2e05ffbdfc` |
| `pjh/test/features/chat/presentation/bloc/chat_detail/chat_detail_bloc_test.dart` | `7b00f470aa91d3667c5568cb4fc3cc81cc3b8f4cd7bd0847635549e0a8782d7f` |
| `pjh/test/features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc_test.dart` | `1a46918257dca1afce9da7f7f3aa612bb5cf0f1438cd2fe6c30d16d558848e49` |
| `pjh/test/features/chat/presentation/pages/chat_detail_page_test.dart` | `5654e8d6cb5859de45178e390b33f23d9b8c9bca6b8bde372c21b32f004e4f59` |
| `pjh/test/features/chat/presentation/pages/chat_room_settings_page_test.dart` | `279ed9fee5f923a881fa7df438be562ceffe8b338bf8d895906014eda5da9f24` |
| `pjh/test/features/chat/presentation/pages/chat_rooms_page_test.dart` | `8018e6b847c52b3345bd38efbb6ee9f86c0d23832eefb9e7e0b4f61b034c6121` |
| `pjh/test/features/chat/presentation/pages/create_chat_page_test.dart` | `62c4cd6c0a72110f4c7691f237170e927b69db1c54ebc91a5d2a396a367ad9a3` |
| `pjh/test/features/chat/presentation/widgets/chat_bubble_test.dart` | `aac1a4d8bfe299580e1ea8a88ece61bb220db4bab7789f38369772c1a3398472` |
| `pjh/test/features/chat/presentation/widgets/chat_input_bar_test.dart` | `78718fd9f43bc1e7f968223a4096a4a7cad3b0ea8f3e1c83196ef72c39e3e8e0` |
| `pjh/test/features/feed_hub/domain/community_post_test.dart` | `8d0c83d146e9d7f387b52f3207389b3ea3c113dc71a27155fb6b5d543432a5fb` |
| `pjh/test/features/feed_hub/presentation/pages/create_community_post_page_test.dart` | `1429e7b259e9af9e31d72f6231fcc3b555623d548c887a8faf4e84b236c9925e` |
| `pjh/test/features/feed_hub/presentation/pages/feed_hub_page_test.dart` | `9e14f1836a63e6a387020e46b00189b60d27dca18a2ac8f1ed7cf32f220871ce` |
| `pjh/test/features/health/presentation/bloc/health_bloc_test.dart` | `b7be70ebeb183575f26355429c0705273f4a26b518d23a94fdff188a24d0ffe4` |
| `pjh/test/features/health/presentation/health_alert_settings_page_test.dart` | `0c19b87f09e46556ff47d79f7683fcab1e40959fdd347b5417b82b5e2b51ed26` |
| `pjh/test/features/health/presentation/health_main_page_test.dart` | `b92ef1d0448e2c6b7987700f2e8046da0667ad6287f428b1b4870a87ce6a5127` |
| `pjh/test/features/health/presentation/health_pdf_preview_page_test.dart` | `dc72240f287dcb250b868c4622fb699b86852f2b36ec08ffc16d393b369fdd67` |
| `pjh/test/features/health/presentation/health_record_data_test.dart` | `24eea96821817dfcfa9ed5758e6fd58aec230159d5fee60a7d7b8a067e4e376e` |
| `pjh/test/features/health/presentation/health_record_editor_page_test.dart` | `7cb3015e4bbedf2eb95d0b0560a2eb3f921d50198e638a0b58b1f6f67f4f63c1` |
| `pjh/test/features/my/pet_summary_section_render_test.dart` | `8d86d84489ecd7d5dc7005f5b07b534a312f181229e16e9098b0ee04d12ddb60` |
| `pjh/test/features/my/presentation/pages/my_page_test.dart` | `c129fdb09c599c99e7b573a781b202d160f6dd6a42eeaa9580862bbd925e3479` |
| `pjh/test/features/my/presentation/pages/my_posts_page_test.dart` | `79cf056db282421c7b48a9637300782975988519cd7b682fa335fce0d81a208c` |
| `pjh/test/features/my/presentation/pages/my_saved_posts_page_test.dart` | `6c057eb955432f50e0507b4ba78f2c880b59ead360896a55daf8f5310dfa8a23` |
| `pjh/test/features/onboarding/presentation/pages/onboarding_complete_page_test.dart` | `f49e516ab40b3a2ec44aff57c8975586db005b16e50809717b545fa470957ebd` |
| `pjh/test/features/onboarding/presentation/pages/onboarding_email_verification_page_test.dart` | `d5e7b22d16e26c894b993bce15b585554e1376c054a12e87c408ab2bd4b7ee0b` |
| `pjh/test/features/onboarding/presentation/pages/onboarding_login_page_test.dart` | `fa2777d091250a1af37c73f8162e286e60fae2930f1106d173d3812cc8abe9b1` |
| `pjh/test/features/onboarding/presentation/pages/onboarding_pet_registration_page_test.dart` | `7eb209c54631faf8d59de14d09b0826507e28f1ddece3e24edc443248dd6a3cd` |
| `pjh/test/features/onboarding/presentation/pages/onboarding_profile_setup_page_test.dart` | `d59a73327fabc6296e0647e0eed98dfb93e4f39352ecdcb45971c21139b89fc9` |
| `pjh/test/features/onboarding/presentation/pages/splash_page_test.dart` | `ce6d214ac7de06696c332dc0c392cf149308057449c424fba9169d66d292d9a0` |
| `pjh/test/features/pets/data/pet_selected_repository_test.dart` | `45e5af7651cf5cea76f542535cd52250ac95f66385b18e05fd5682cbb2a229d0` |
| `pjh/test/features/pets/presentation/bloc/pet_bloc_test.dart` | `27040ab8e0fe59035ce1d1d28c0457f6fcb121ce01ddf353fe672694a8375701` |
| `pjh/test/features/pets/presentation/pages/pet_detail_page_test.dart` | `41db8395ca22d4eb04e5e0ca78ec89851c0bfece992d283b6ee592bc2fecbc7a` |
| `pjh/test/features/pets/presentation/pages/pet_editor_page_test.dart` | `cb9a8d6db88efa31a53503810ad69a94f51ca43a0a84142a3acc47bb351ee094` |
| `pjh/test/features/pets/presentation/pages/pet_management_page_test.dart` | `223df8a0fd9b99272f2fa4cababf3d444f522ba858a96a3987d757655b22e6e7` |
| `pjh/test/features/pets/presentation/pages/public_pet_page_test.dart` | `8078b39491e63f12043514c74ea888fc3893168f1f8f8b0cf18de2038f7df351` |
| `pjh/test/features/pets/presentation/widgets/pet_card_test.dart` | `0a2f726834823e98e3176b2f94ddc39d1e06b46401ce5cd34930a752815b62d0` |
| `pjh/test/features/profile/presentation/pages/notification_settings_page_test.dart` | `07967443c9b4aabbe2befae14901a15dee7922ed65b39ea0852f76a59ca0a31d` |
| `pjh/test/features/social/presentation/pages/create_post_page_test.dart` | `985b38b774022bc03b22f986c8e26b329c567e454096138bfc76580ac64a6f33` |
| `pjh/test/features/social/presentation/pages/feed_page_state_test.dart` | `0fad426d8b29816bb82a847af1fd820e2750d70c6210451dcbc6b5c9d68d55fb` |
| `pjh/test/features/social/presentation/pages/notifications_page_test.dart` | `be4acf4b17980a3fea2c96dc56a57119fc9f5ae2d00f4053f7ae7019baea31bb` |
| `pjh/test/features/social/presentation/widgets/create_post_bottom_sheet_test.dart` | `ec2808d23d59e6fef01e1f3868981d3ad2e478be5e5346f0c5912f4621575e6c` |
| `pjh/test/features/social/presentation/widgets/edit_post_bottom_sheet_test.dart` | `93b0605f1eaa1bcecf41b21ea4729cee1f22a9a25fa8b71b2a95c93a5669c392` |
| `pjh/test/features/social/presentation/widgets/post_card_like_test.dart` | `9d99e419d579f6316d546721b7d6b3966286b0443064f1d008904fb7e8a7e61b` |
| `pjh/test/main_navigation_test.dart` | `84691add66e401044dd81304df42cf251a1a69e0a61726b6643046bfeb71a6a8` |
| `pjh/test/shared/widgets/category_chip_test.dart` | `4cd071b228b0b07ad4dea079db6831afe91de1a80484bc4f673d52b391525f10` |
| `pjh/test/shared/widgets/petspace_page_scaffold_test.dart` | `0816cc1f3f08af698b1841f0aee83769a3c487d57623671d43670c8cf0251aef` |
| `pjh/test/shared/widgets/petspace_settings_components_test.dart` | `ae027267a0f749cfcef324cca19ff1aec64744e9d648f92402014ecab51da577` |
| `pjh/test/shared/widgets/petspace_state_view_test.dart` | `6bc62d16400c67fcbed777ae355fe2b88baca67163dc9fe9ee94895a7a5e1878` |
| `supabase/migrations/20260723042242_m1_selected_pet_contract.sql` | `5010f1dea6d5930b417a80263ea898ad0f3fdd9640460d4445fc880d2ba1f8c6` |
| `supabase/petspace_setup.sql` | `bf50af1d1df80b07ae28d3ea271c0433ba5bd9ed0cf02966e2c36919566848ac` |
