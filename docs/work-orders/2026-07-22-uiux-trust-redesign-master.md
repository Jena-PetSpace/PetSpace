# PetSpace UI/UX 신뢰도 전면 개선 Master Work Order v1

> 기획 기준일: 2026-07-22
> 앱 코드 기준: `c49a8c4`
> 기획 브랜치 기준: `604e9f1`
> 구현 상태: 미착수
> 기획 검토: Codex 단독 3-pass
> 외부 검토: Claude·Anthropic 전송 제외
> 상위 승인: Set A~D 목업 및 아래 사용자 결정 승인

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
- 신규 `supabase/migrations/M1_selected_pet_contract.sql`
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
