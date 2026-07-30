# PetSpace 승인 UI/UX 구현 manifest

- 작성일: 2026-07-30
- 브랜치: `mac-ios-release`
- 기준 HEAD: `02f74e50d645a2e4eb29cb0d4ac735ff40d39445`
- 선행 기획: `docs/work-orders/2026-07-30-post-windows-merge-uiux-plan.md`
- 상태: 사용자 방향 승인, Claude 1차 `CHANGES_REQUIRED` 보완 반영

## 1. 이번 구현에서 고정하는 계약

1. 홈 탭과 홈 탭 전용 위젯은 수정하지 않는다.
2. 감정·건강 AI 분석 결과 화면과 결과 전용 위젯은 수정하지 않는다.
3. 로그인 화면은 이메일 폼 아래에 Apple, Google, 카카오톡의 **원형 버튼**
   세 개를 유지한다. 가로 전체 버튼이나 텍스트형 제공사 버튼으로 바꾸지 않는다.
4. Apple OAuth, Google OAuth, Kakao 인증 이벤트·딥링크·URL scheme·entitlement
   계약은 변경하지 않는다.
5. 기존 Windows→Mac 안정화 변경은 보존한다. 특히 iOS Kakao 지도 준비·실패·
   재시도, 장소 오탐 필터, AI 오류 비공개화 변경을 되돌리지 않는다.
6. K1/H2, `auth.uid()` 기반 RPC, iPad `shareOrigin`, health root navigator와
   `context.mounted` 계약을 변경하지 않는다.
7. `pjh/lib/config/secrets.dart`, `GoogleService-Info.plist`, `.env*`, 인증서,
   키, provisioning profile은 읽기·출력·stage·commit·외부 전송하지 않는다.
8. 이번 구현에서는 전역 `AppTheme`, `ThemeData`, 기존 공용 scaffold·app bar·
   state·bottom CTA를 수정하지 않는다. 승인 화면만 명시적으로 import하는
   `petspace_uiux_v3.dart`를 신설해 간접 렌더링 변경을 차단한다.

## 2. 명시적 제외 경로

### 2.1 홈 탭

- `pjh/lib/features/social/presentation/pages/home_page.dart`
- `pjh/lib/features/home/presentation/widgets/community_preview.dart`
- `pjh/lib/features/home/presentation/widgets/feed_preview_widget.dart`
- `pjh/lib/features/home/presentation/widgets/home_ad_banner.dart`
- `pjh/lib/features/home/presentation/widgets/home_dashboard_header.dart`
- `pjh/lib/features/home/presentation/widgets/home_news_section.dart`
- `pjh/lib/features/home/presentation/widgets/home_quest_card.dart`
- `pjh/lib/features/home/presentation/widgets/home_quick_actions.dart`
- `pjh/lib/features/home/presentation/widgets/hot_issue_card.dart`
- `pjh/lib/features/home/presentation/widgets/hot_topic_banner.dart`
- `pjh/lib/features/home/presentation/widgets/magazine_grid.dart`
- `pjh/lib/features/home/presentation/widgets/passport_mood_mapper.dart`
- `pjh/lib/features/home/presentation/widgets/pet_passport_card.dart`
- `pjh/lib/features/home/presentation/widgets/pet_passport_carousel.dart`
- `pjh/lib/features/home/presentation/widgets/pet_profile_card.dart`
- `pjh/lib/features/home/presentation/widgets/quick_actions_widget.dart`
- `pjh/lib/features/home/presentation/widgets/recent_emotion_card.dart`
- `pjh/lib/features/home/presentation/widgets/statistics_summary_card.dart`

`pjh/lib/features/home/presentation/pages/hospital_search_page.dart`,
`pjh/lib/features/home/presentation/pages/hospital_search_page_actions.dart`,
`pjh/lib/features/home/presentation/pages/hospital_search_page_map.dart`,
`pjh/lib/features/home/presentation/pages/hospital_search_page_search.dart`,
`pjh/lib/features/home/presentation/pages/hospital_search_page_ui.dart`는 홈 탭이
아닌 `/hospital` 독립 플레이스 흐름이다. 병합 직후 이미 존재하는 안정화
diff는 보존하고, Wave 4에서 지도 실패 대체 UI 검증에 한해 수정할 수 있다.

### 2.2 AI 분석 결과

- `pjh/lib/features/emotion/presentation/pages/emotion_result_loader_page.dart`
- `pjh/lib/features/emotion/presentation/pages/emotion_result_page.dart`
- `pjh/lib/features/emotion/presentation/pages/health_result_page.dart`
- `pjh/lib/features/emotion/presentation/theme/emotion_result_tokens.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/ai_insight_card.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/bottom_action_bar.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/breed_guide_card.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/context_card.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/diagnosis_findings_card.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/emotion_distribution_card.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/emotion_share_card.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/emotion_summary_card.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/fullscreen_photo_viewer.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/health_disclaimer_card.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/health_findings_card.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/health_next_action_card.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/health_score_card.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/history_result_banner.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/memo_save_modal.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/next_action_card.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/part_analysis_card.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/photo_slider.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/stress_card.dart`
- `pjh/lib/features/emotion/presentation/widgets/result/vet_consult_card.dart`

AI 기록 목록은 결과 화면이 아니므로 아래 Wave 4의 명시 경로만 허용한다.

### 2.3 제외 화면의 의존성 동결

조사 결과 홈 탭과 AI 결과 화면은 `AppTheme`를 직접 소비하지만, Wave 0에서
검토했던 기존 `PetSpacePageScaffold`, `PetSpaceAppBar`, `PetSpaceStateView`,
`PetSpaceBottomActionBar`를 직접 소비하지 않는다. 따라서 아래 파일은 이번
작업에서 내용까지 동결한다.

| 파일 | 기준 SHA-256 |
|---|---|
| `pjh/lib/shared/themes/app_theme.dart` | `53d3be329febc1b9c0e9581f707f2f5376ed74723c1a5217ca47c37649d24bcb` |
| `pjh/lib/shared/widgets/petspace_page_scaffold.dart` | `f045eeb73197ba772ea4d2155dae9f52e2e6d5b7bcc12a86d6828407adb9d8be` |
| `pjh/lib/shared/widgets/petspace_app_bar.dart` | `ee24af4abbc21e2a12af453e9fade220c4b12e470862928faef7b4ea27d4f983` |
| `pjh/lib/shared/widgets/petspace_state_view.dart` | `44f12af40d9582e064a5f4649489c89659417a088b0d6510e6b173ff3cb3308e` |
| `pjh/lib/shared/widgets/petspace_bottom_action_bar.dart` | `7face4bcb1a9c3e5f229d9b38396787ecd596438a557ab37d0f1bd78bc5958da` |
| `pjh/lib/features/social/presentation/pages/home_page.dart` | `f9b05b08e1e76f22a6e6885ceef7c92d6b56c3001a29f00563b5bf588782f133` |
| `pjh/lib/features/emotion/presentation/pages/emotion_result_loader_page.dart` | `ff32396aa434ef54b6b04b3f1918bf2121295dabf621a29e566cd8ede9c56471` |
| `pjh/lib/features/emotion/presentation/pages/emotion_result_page.dart` | `d2f4f513fd1de1bb38580332b4e0d20afc0dc850b9e263eaf3c24be357f0c102` |
| `pjh/lib/features/emotion/presentation/pages/health_result_page.dart` | `2e9f26d9691d6039bbb5bd2a508ed41c2cc6a6dfc6ca5a0e3e1a824974799e3d` |
| `pjh/lib/features/emotion/presentation/theme/emotion_result_tokens.dart` | `a0ce6f675e94c6578bbd01bd3ec3752245e11b445fbce129ad82798016b8b824` |

각 Wave 종료 시 SHA 재계산과 `uiux_scope_boundary_contract_test.dart`를 함께
통과해야 한다. 새 opt-in UI 파일을 제외 경로가 import하면 실패한다. 전역
테마와 제외 화면 의존성을 동결하므로 제외 화면 golden을 새로 생성하거나
제외 화면 코드를 수정하지 않는다.

## 3. 수동 수정 허용 manifest

아래 경로만 UI/UX 구현을 위해 수동 수정한다. 실제로 변경하지 않은 허용 경로는
최종 diff에 포함하지 않는다. 새 테스트가 필요하면 각 Wave의 테스트 디렉터리에
정확한 단일 파일을 추가하고 이 문서에 먼저 기록한다.

### Wave 0 — 공용 foundation

- `pjh/tool/verify_uiux_scope.dart` (`NEW`)
- `pjh/tool/uiux_frozen_scope.sha256` (`NEW`)
- `pjh/tool/uiux_protected_scope.sha256` (`NEW`)
- `.github/workflows/uiux-scope.yml` (`NEW`)
- `pjh/lib/shared/widgets/petspace_uiux_v3.dart` (`NEW`)
- `pjh/test/shared/widgets/petspace_uiux_v3_test.dart` (`NEW`)
- `pjh/test/contracts/uiux_scope_boundary_contract_test.dart` (`NEW`)
- `pjh/test/tool/verify_uiux_scope_test.dart` (`NEW`)

Acceptance:

- 흰색 카드, `#E5E8EC` 1px 경계, 12px radius의 동일 문법을 사용한다.
- `#E5E8EC`는 그룹의 장식적 분리를 돕는 선이며 상호작용 가능 여부의 유일한
  단서로 사용하지 않는다. 버튼/행은 텍스트, 아이콘, focus·pressed 상태로
  별도 식별한다.
- 주요 CTA는 `#2F6399`와 흰색 조합을 사용한다.
- 장식 이모지 없는 최초·빈 결과·오류 상태를 구분한다.
- 네트워크, 서버, 권한, 세션 만료가 서로 다른 복구 행동을 제공한다.
- 320×568과 200% 글자에서도 주요 행동이 사라지거나 겹치지 않는다.
- 320×568은 출시 지원 기기 선언이 아니라 작은 viewport 회귀 stress test다.
- 전역 `AppTheme`, `ThemeData`, 기존 공용 위젯 및 제외 화면 SHA가 모두
  기준값과 같아야 한다.
- 홈/AI 결과 엔트리의 transitive Dart import closure를 자동 계산한다.
  `pjh/lib/config/secrets.dart`는 폐포 존재 여부만 확인하고 내용·SHA·크기는
  절대 읽거나 기록하지 않는다. snapshot에도 경로를 남기지 않으며 로컬에
  있으면 ignored·untracked여야 한다.
- `lib/main.dart`, `lib/core/navigation/app_router.dart`,
  `lib/core/navigation/auth_guard.dart`, `lib/main_navigation.dart`,
  `lib/shared/models/navigation_item.dart`와 위 2절에 개별 열거한 모든 제외
  화면·위젯을 import closure와 별도로 동결한다.
- 위 명시 경로 52개는 `uiux_protected_scope.sha256`에 별도로 고정하고,
  보호 manifest 자체 SHA-256도 contract test 리터럴로 잠근다. 승인된 자산
  추가로 전체 snapshot을 재생성하더라도 이 52개 파일의 변경은 통과할 수 없다.
- `pubspec.yaml`, `pubspec.lock`, `lib/l10n/*.arb`, `assets/` 전체를 non-Dart
  렌더 입력으로 같은 snapshot에 포함한다.
- snapshot 누락·추가·리네임·SHA 불일치는 verifier exit code 1로 실패하며
  `.github/workflows/uiux-scope.yml`에서 강제한다.
- verifier 자체 회귀 테스트는 정상·변경·누락·추가 입력, conditional import,
  비밀 경계 실패 시 즉시 중단을 각각 확인한다.
- 환경 기준은 Flutter `3.41.7`/Dart `3.11.5`, Xcode `26.4`로 고정한다.

### Wave 1 — 인증·설정·반려동물

- `pjh/lib/features/onboarding/presentation/pages/onboarding_login_page.dart`
- `pjh/lib/features/auth/presentation/pages/password_reset_request_page.dart`
- `pjh/lib/features/auth/presentation/pages/password_reset_verification_page.dart`
- `pjh/lib/features/auth/presentation/pages/password_reset_new_password_page.dart`
- `pjh/lib/features/auth/presentation/pages/terms_agreement_page.dart`
- `pjh/lib/features/auth/presentation/pages/terms_detail_page.dart`
- `pjh/lib/features/my/presentation/pages/my_settings_page.dart`
- `pjh/lib/features/profile/presentation/pages/notification_settings_page.dart`
- `pjh/lib/features/profile/presentation/pages/privacy_settings_page.dart`
- `pjh/lib/features/profile/presentation/pages/help_page.dart`
- `pjh/lib/features/profile/presentation/pages/community_guidelines_page.dart`
- `pjh/lib/features/pets/presentation/pages/pet_management_page.dart`
- `pjh/lib/features/pets/presentation/pages/pet_editor_page.dart`
- `pjh/lib/features/pets/presentation/pages/pet_detail_page.dart`
- `pjh/lib/features/pets/presentation/widgets/pet_card.dart`
- `pjh/lib/features/pets/presentation/widgets/pet_editor_form_widgets.dart`
- `pjh/test/features/onboarding/presentation/pages/onboarding_login_page_test.dart`
- `pjh/test/features/auth/presentation/pages/password_reset_request_page_test.dart`
- `pjh/test/features/auth/presentation/pages/password_reset_verification_page_test.dart`
- `pjh/test/features/auth/presentation/pages/password_reset_new_password_page_test.dart`
- `pjh/test/features/auth/presentation/pages/terms_agreement_page_test.dart`
- `pjh/test/features/auth/presentation/pages/terms_detail_page_test.dart`
- `pjh/test/features/my/presentation/pages/my_settings_page_test.dart`
- `pjh/test/features/profile/presentation/pages/notification_settings_page_test.dart`
- `pjh/test/features/profile/presentation/pages/privacy_settings_page_test.dart`
- `pjh/test/features/profile/presentation/pages/help_page_test.dart`
- `pjh/test/features/profile/presentation/pages/community_guidelines_page_test.dart`
- `pjh/test/features/pets/presentation/pages/pet_management_page_test.dart`
- `pjh/test/features/pets/presentation/pages/pet_editor_page_test.dart`
- `pjh/test/features/pets/presentation/pages/pet_detail_page_test.dart`
- `pjh/test/features/pets/presentation/widgets/pet_card_test.dart`

Acceptance:

- 로그인 소셜 버튼은 Apple·Google·카카오톡 원형 58pt 버튼 세 개다.
- iOS 순서는 Apple → Google → 카카오톡, Apple 미지원 플랫폼은 Google →
  카카오톡이다. 버튼 사이 간격은 16pt이며 200% 글자에서도 시각 지름 58pt를
  유지하고 주변 문구만 reflow한다.
- 한국어 semantics와 tooltip은 각각 `Apple로 로그인하기`,
  `Google로 로그인하기`, `카카오톡으로 로그인하기`로 고정한다.
  `button: true`, `enabled`, 장식 아이콘 `ExcludeSemantics`를 적용한다.
- 버튼과 이벤트는 Apple=`AuthSignInWithAppleRequested`, Google=
  `AuthSignInWithGoogleRequested`, Kakao=`AuthSignInWithKakaoRequested`의
  1:1 매핑이다.
- 인증 진행 중에는 세 버튼과 이메일 제출을 모두 비활성화하고 탭한 제공사에만
  progress를 표시한다. 중복 탭은 새 인증 세션을 만들지 않는다. 사용자 취소는
  오류가 아니며 provider 오류·네트워크 오류와 분리한다.
- Kakao는 카카오톡 설치 시 톡 로그인, 미설치 시 카카오계정 로그인 폴백이라는
  기존 repository 계약을 유지한다. 자동 검증은 mock widget/BLoC 범위이고
  실제 OAuth는 서명 실기기 수동 검증으로 분리한다.
- Google은 Google Identity가 2026-07-07 공개한 pre-approved iOS Light
  round icon-only 4x PNG 원본 bytes를
  `assets/images/google_sign_in_round_light.png.b64`에 base64 transport로
  보존해 사용한다. 런타임에는 whitespace를 제거해 원본 PNG bytes로
  복원하며, 낮은 해상도의 인라인 PNG나 지원되지 않는 SVG filter를 쓰지
  않는다. Apple은 `sign_in_with_apple` 패키지의 전용
  `AppleLogoPainter`로 Material 근사 아이콘을 제거하고 마크 구현을 한 곳에
  격리한다. Apple 공식 다운로드 자산은 별도 라이선스 동의가 필요하므로 이
  작업에서 동의하거나 반입하지 않았으며, App Store 제출 전 계정 소유자가
  라이선스를 확인한 공식 logo-only 자산으로 최종 대체해야 한다.
- 카카오 원형은 사용자 확정 UI를 유지하되 Kakao 공식 디자인이 label+12px
  radius container를 권고한다는 출시 심사 위험을 기록하며, Apple 공식 자산
  대체와 함께 배포 전 점검한다. 별도 사용자 결정 없이는 형태를 임의 변경하지
  않는다.
- 참고 공식 문서:
  `https://developer.apple.com/design/resources/`,
  `https://developers.google.com/identity/branding-guidelines`,
  `https://developers.kakao.com/docs/ko/kakaologin/design-guide`
- 로그인·회원가입·비밀번호 재설정은 하나의 캔버스와 동일 입력·CTA 규칙을
  사용한다.
- 이메일 형식, 영문·숫자 포함 8자 비밀번호, 인증 코드 흐름을 인라인 검증한다.
- 반려동물 0마리, 대표 반려동물 변경, 마지막 반려동물 삭제를 안전하게 안내한다.

### Wave 2 — MY·피드·커뮤니티·소셜

- `pjh/lib/shared/widgets/petspace_uiux_v3.dart` (Wave 0 신설 파일의
  `searchEmpty`·`blockedHidden` 확장)
- `pjh/test/shared/widgets/petspace_uiux_v3_test.dart` (위 확장 회귀 검증)
- `pjh/lib/features/my/presentation/pages/my_page.dart`
- `pjh/lib/features/my/presentation/pages/my_posts_page.dart`
- `pjh/lib/features/my/presentation/pages/my_saved_posts_page.dart`
- `pjh/lib/features/my/presentation/widgets/my_profile_header.dart`
- `pjh/lib/features/my/presentation/widgets/my_pet_summary_section.dart`
- `pjh/lib/features/my/presentation/widgets/saved_posts_grid.dart`
- `pjh/lib/features/feed_hub/presentation/pages/feed_hub_page.dart`
- `pjh/lib/features/feed_hub/presentation/pages/create_community_post_page.dart`
- `pjh/lib/features/feed_hub/presentation/cubit/community_cubit.dart`
- `pjh/lib/features/feed_hub/presentation/widgets/community_post_card.dart`
- `pjh/lib/features/feed_hub/presentation/widgets/post_type_picker_sheet.dart`
- `pjh/lib/features/social/presentation/pages/feed_page.dart`
- `pjh/lib/features/social/presentation/pages/create_post_page.dart`
- `pjh/lib/features/social/presentation/pages/post_detail_page.dart`
- `pjh/lib/features/social/presentation/pages/comments_page.dart`
- `pjh/lib/features/social/presentation/pages/profile_page.dart`
- `pjh/lib/features/social/presentation/pages/followers_page.dart`
- `pjh/lib/features/social/presentation/pages/search_page.dart`
- `pjh/lib/features/social/presentation/pages/explore_page.dart`
- `pjh/lib/features/social/presentation/pages/notifications_page.dart`
- `pjh/lib/features/social/presentation/widgets/comment_composer.dart`
- `pjh/lib/features/social/presentation/widgets/comment_card.dart`
- `pjh/lib/features/social/presentation/widgets/comment_list_item.dart`
- `pjh/lib/features/social/presentation/widgets/post_card.dart`
- `pjh/lib/features/social/presentation/widgets/post_card_actions.dart`
- `pjh/lib/features/social/presentation/widgets/post_card_dialogs.dart`
- `pjh/lib/features/social/presentation/widgets/post_card_header.dart`
- `pjh/lib/features/social/presentation/widgets/post_card_media.dart`
- `pjh/lib/features/social/presentation/widgets/social_content_report_sheet.dart`
- `pjh/lib/features/social/presentation/widgets/social_user_actions_sheet.dart` (`NEW`)
- `pjh/lib/features/social/presentation/widgets/user_list_tile.dart`
- `pjh/lib/features/social/presentation/widgets/user_posts_list.dart`
- `pjh/lib/features/social/presentation/utils/post_draft_storage.dart`
- `pjh/test/features/my/presentation/pages/my_page_test.dart`
- `pjh/test/features/my/presentation/pages/my_posts_page_test.dart`
- `pjh/test/features/my/presentation/pages/my_saved_posts_page_test.dart`
- `pjh/test/features/my/presentation/widgets/my_profile_header_test.dart`
- `pjh/test/features/my/presentation/widgets/saved_posts_grid_test.dart`
- `pjh/test/features/feed_hub/presentation/pages/feed_hub_page_test.dart`
- `pjh/test/features/feed_hub/presentation/pages/create_community_post_page_test.dart`
- `pjh/test/features/feed_hub/presentation/widgets/community_post_card_test.dart` (`NEW`)
- `pjh/test/features/social/presentation/pages/create_post_page_test.dart`
- `pjh/test/features/social/presentation/pages/comments_page_test.dart` (`NEW`)
- `pjh/test/features/social/presentation/pages/feed_page_state_test.dart`
- `pjh/test/features/social/presentation/pages/followers_page_test.dart`
- `pjh/test/features/social/presentation/pages/notifications_page_test.dart`
- `pjh/test/features/social/presentation/pages/post_detail_page_test.dart`
- `pjh/test/features/social/presentation/pages/profile_page_test.dart`
- `pjh/test/features/social/presentation/pages/search_page_test.dart`
- `pjh/test/features/social/presentation/widgets/comment_list_item_test.dart`
- `pjh/test/features/social/presentation/widgets/comment_card_test.dart` (`NEW`)
- `pjh/test/features/social/presentation/widgets/post_card_bookmark_test.dart`
- `pjh/test/features/social/presentation/widgets/post_card_connector_test.dart`
- `pjh/test/features/social/presentation/widgets/post_card_like_test.dart`
- `pjh/test/features/social/presentation/widgets/social_content_report_sheet_test.dart`
- `pjh/test/features/social/presentation/widgets/social_user_actions_sheet_test.dart` (`NEW`)
- `pjh/test/features/social/presentation/utils/post_draft_storage_test.dart` (`NEW`)
- `pjh/test/contracts/p2b_block_privacy_contract_test.dart`

Acceptance:

- MY 상단은 프로필·게시글/팔로워/팔로잉·대표 반려동물이 한 그룹으로 읽힌다.
- 피드는 사진 1장 이상이 필요한 일상 스트림, 커뮤니티는
  `질문/정보/자랑/일상` 텍스트 게시판으로 시각·작성 흐름을 분리한다.
- 피드/커뮤니티 draft는 유형별로 분리하고 이탈 시 입력 손실을 막는다.
- draft 유형 간 직접 전환은 허용하지 않는다. 피드 draft는 피드에서만,
  커뮤니티 draft는 커뮤니티에서만 복구한다.
- 게시물·댓글·사용자 신고 및 사용자 차단 진입점이 대상별로 정확하다.
- 피드와 커뮤니티 모두 게시물→게시물 신고, 댓글→댓글 신고, 사용자
  overflow→사용자 신고·차단으로 고정한다. 차단 확정 직후 현재 클라이언트의
  기존 콘텐츠를 즉시 숨기고 다음 fetch에서도 서버 필터를 적용한다.
- 비어 있음·검색 결과 없음·차단으로 숨김·서버 실패 상태를 혼용하지 않는다.

### Wave 3 — 건강

- `pjh/lib/features/health/presentation/pages/health_main_page.dart`
- `pjh/lib/features/health/presentation/pages/health_record_editor_page.dart`
- `pjh/lib/features/health/presentation/pages/health_alert_settings_page.dart`
- `pjh/lib/features/health/presentation/pages/health_pdf_preview_page.dart`
- `pjh/lib/features/health/presentation/widgets/health_record_card.dart`
- `pjh/lib/features/health/presentation/widgets/health_record_form.dart`
- `pjh/lib/features/health/presentation/widgets/health_record_sheets.dart`
- `pjh/lib/features/health/presentation/widgets/weight_trend.dart`
- `pjh/lib/features/health/presentation/widgets/weight_trend_chart.dart`
- `pjh/test/features/health/presentation/health_main_page_test.dart`
- `pjh/test/features/health/presentation/health_record_editor_page_test.dart`
- `pjh/test/features/health/presentation/health_alert_settings_page_test.dart`
- `pjh/test/features/health/presentation/health_pdf_preview_page_test.dart`
- `pjh/test/features/health/presentation/health_record_card_test.dart`
- `pjh/test/features/health/presentation/weight_trend_test.dart`
- `pjh/test/contracts/h1_health_contract_test.dart`
- `pjh/test/contracts/h1b_health_ui_contract_test.dart`

Acceptance:

- 선택 반려동물 → 다음 케어 → 기록 추가 → 최근 기록 → 변화 순서를 유지한다.
- 일정 개수, 목록, 빈 상태는 같은 계산 결과를 사용한다.
- 건강 기록 필수·선택, 날짜, 저장 오류, 로딩 상태를 명확히 구분한다.
- PDF 미리보기와 공유는 민감정보·파일 실패를 사용자 친화적으로 처리한다.

### Wave 4 — 플레이스·위치 선택·AI 기록 목록

- `pjh/lib/features/home/presentation/pages/hospital_search_page.dart`
- `pjh/lib/features/home/presentation/pages/hospital_search_page_actions.dart`
- `pjh/lib/features/home/presentation/pages/hospital_search_page_map.dart`
- `pjh/lib/features/home/presentation/pages/hospital_search_page_search.dart`
- `pjh/lib/features/home/presentation/pages/hospital_search_page_ui.dart`
- `pjh/lib/features/social/presentation/pages/location_picker_page.dart`
- `pjh/lib/features/social/presentation/widgets/location_picker_sheet.dart`
- `pjh/lib/features/emotion/presentation/pages/ai_history_page.dart`
- `pjh/lib/features/emotion/presentation/widgets/history/ai_history_filter_bar.dart`
- `pjh/lib/features/emotion/presentation/widgets/history/ai_history_filter_sheet.dart`
- `pjh/lib/features/emotion/presentation/widgets/history/ai_history_pet_inline_dropdown.dart`
- `pjh/lib/features/emotion/presentation/widgets/history/ai_history_record_card.dart`
- `pjh/test/features/home/hospital_search_page_widget_test.dart`
- `pjh/test/features/social/presentation/pages/location_posts_page_test.dart`
- `pjh/test/features/social/presentation/pages/location_picker_page_test.dart` (신규)
- `pjh/test/features/emotion/ai_history_presentation_test.dart`
- `pjh/test/features/emotion/ai_history_ui_consistency_test.dart`
- `pjh/test/features/emotion/ai_history_behavior_test.dart` (신규)
- `pjh/test/core/place_search/place_search_query_test.dart`
- `pjh/test/contracts/windows_to_mac_integration_contract_test.dart`

Acceptance:

- 지도 성공, 실패 후 재시도, 리스트 전용 모드를 제공한다.
- iOS Kakao 401에서도 검색·상세·저장은 가능한 상태를 유지한다.
- 위치는 기본 미첨부이며 공개 값은 시·군·구 단위로 제한한다.
- Kakao Local 응답에 없는 별점·리뷰 수를 만들지 않는다.
- AI 기록 목록만 정리하며 분석·건강 결과 페이지와 결과 위젯은 변경하지 않는다.
- AI 기록 목록은 기존 `ai_history_record_card.dart`만 사용하며 result 전용
  위젯을 import하거나 재사용하지 않는다.
- 최신 사용자 지시에 따라 `pjh/lib/features/home/**`는 Wave 4에서도 읽기·
  테스트만 허용하고 신규 수정하지 않는다.
- 위치 선택 직접 테스트는 초기·검색 중·성공·빈 결과·네트워크·시간 초과·
  지도 실패 목록 전용·권한 거부·320×568 200% 글자를 개별 검증한다.
- AI 기록 직접 테스트는 빈 상태·전체 실패·부분 실패·추가 로딩·펫 범위
  전환·정성 신뢰도 문구·320×568 200% 글자를 개별 검증한다.

병합 직후 iOS Kakao 안정화 보존 기준 SHA-256:

| 파일 | 기준 SHA-256 |
|---|---|
| `pjh/lib/features/home/presentation/pages/hospital_search_page.dart` | `93e800dca271502cf863829ae66deaae2698f4f0a82a94aa11d5ca2af9e8c8d0` |
| `pjh/lib/features/home/presentation/pages/hospital_search_page_actions.dart` | `3c476f67928ec00cb757c4a7134f8efeb91af188b89ee24db28301ac54f3a870` |
| `pjh/lib/features/home/presentation/pages/hospital_search_page_map.dart` | `d6e2da57f91302f4af4552d6920767f9f5bba603ec50bb2291dc85b84f5b615c` |
| `pjh/lib/features/home/presentation/pages/hospital_search_page_search.dart` | `452a4de24ab66811a25e01fc4c93a00a19664fd836667bf32a658f9da30686eb` |
| `pjh/lib/features/home/presentation/pages/hospital_search_page_ui.dart` | `3df62580346013c8ec7921a3a475c8fc6722a27c75fc6d2582839061065231de` |
| `pjh/lib/features/social/presentation/pages/location_picker_page.dart` | `af1900ad7a9a3ec5bbe9e19ef2fe424955e7be2f03155e687e40512f86004a22` |
| `pjh/packages/kakao_maps_flutter/ios/kakao_maps_flutter/Sources/kakao_maps_flutter/KakaoMapController.swift` | `dee806730c039eca557198b59ca95aa714eeb97d1558b6bf4a5c7c3fe76baa20` |
| `pjh/packages/kakao_maps_flutter/lib/src/platform/kakao_map_controller/method_channel/method_channel_kakao_map_controller.dart` | `78a1b6f3a126833aa35e724077b4a303b618ece8c6a98a3fade78104255a92f7` |

Wave 4에서 허용된 UI 파일의 SHA는 변경될 수 있지만, `isMapReady`,
`onMapFailed`/`onMapError` 호환, 12초 ready timeout, 새 platform view
generation, REST list-only fallback의 회귀 테스트는 계속 통과해야 한다.

## 4. 매 Wave 검증 명령

모든 Flutter 명령은 `pjh/`에서 실행한다.

```bash
dart format --output=none --set-exit-if-changed <변경된 Dart 파일>
git diff --check
flutter analyze --no-pub
flutter test --no-pub <해당 Wave의 개별 테스트 파일>
flutter test --no-pub
flutter build ios --release --no-codesign --no-pub
```

iOS 시뮬레이터 검증 전에 `uiux_scope_boundary_contract_test.dart`와 제외 화면
의존성 SHA를 재검증한다.

iOS 시뮬레이터에서는 각 Wave의 주요 성공·빈 상태·입력 오류·서버 실패·
뒤로가기·키보드·200% 글자 흐름을 직접 수행한다. 소셜 인증은 이벤트 연결과
취소/실패 UI까지 검증하며 실제 운영 계정 토큰이나 비밀값은 출력하지 않는다.

## 5. 중단 조건

- 제외 경로를 수정해야 하는 경우
- manifest 밖 수동 코드 수정이 필요한 경우
- Apple/OAuth, K1/H2, `auth.uid()`, `shareOrigin` 계약 변경이 필요한 경우
- 비밀 파일 또는 사용자 데이터가 diff, 로그, Claude 입력에 포함되는 경우
- blocker/high 결함, 신규 analyze/test/build 실패가 발생한 경우
- 기존 Windows→Mac 안정화 변경을 되돌려야 하는 경우

중단 조건이 발생하면 해당 Wave를 멈추고 원인과 필요한 추가 승인을 보고한다.
원격 push, 운영 DB/RPC, Edge, APNs, signing 자산, TestFlight 및 배포는 이번
manifest의 실행 권한에 포함하지 않는다.
