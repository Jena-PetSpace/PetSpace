# PetSpace 전체 UI/UX 감사 정확한 파일 인벤토리

기준일: 2026-08-04

이 문서는 디렉터리 전체나 glob을 구현 범위로 승인하기 위한 문서가 아니다.
전체 기획에서 빠지는 화면과 기존 검증 파일이 없도록 개별 경로를 고정한
read-only 인벤토리다. 실제 구현은 배치별 작업지시서에서 이 목록의 일부만
다시 선택한다.

## Presentation page 파일 80개

- `pjh/lib/features/auth/presentation/pages/kakao_consent_page.dart`
- `pjh/lib/features/auth/presentation/pages/password_reset_new_password_page.dart`
- `pjh/lib/features/auth/presentation/pages/password_reset_request_page.dart`
- `pjh/lib/features/auth/presentation/pages/password_reset_verification_page.dart`
- `pjh/lib/features/auth/presentation/pages/terms_agreement_page.dart`
- `pjh/lib/features/auth/presentation/pages/terms_detail_page.dart`
- `pjh/lib/features/chat/presentation/pages/chat_detail_page.dart`
- `pjh/lib/features/chat/presentation/pages/chat_room_settings_page.dart`
- `pjh/lib/features/chat/presentation/pages/chat_rooms_page.dart`
- `pjh/lib/features/chat/presentation/pages/create_chat_page.dart`
- `pjh/lib/features/emotion/presentation/pages/ai_history_page.dart`
- `pjh/lib/features/emotion/presentation/pages/analysis_guide_page.dart`
- `pjh/lib/features/emotion/presentation/pages/emotion_analysis_page.dart`
- `pjh/lib/features/emotion/presentation/pages/emotion_loading_page.dart`
- `pjh/lib/features/emotion/presentation/pages/emotion_result_loader_page.dart`
- `pjh/lib/features/emotion/presentation/pages/emotion_result_page.dart`
- `pjh/lib/features/emotion/presentation/pages/emotion_timeline_page.dart`
- `pjh/lib/features/emotion/presentation/pages/emotion_trend_page.dart`
- `pjh/lib/features/emotion/presentation/pages/guided_camera_page.dart`
- `pjh/lib/features/emotion/presentation/pages/health_loading_page.dart`
- `pjh/lib/features/emotion/presentation/pages/health_result_page.dart`
- `pjh/lib/features/emotion/presentation/pages/weekly_report_page.dart`
- `pjh/lib/features/feed_hub/presentation/pages/create_community_post_page.dart`
- `pjh/lib/features/feed_hub/presentation/pages/feed_hub_page.dart`
- `pjh/lib/features/fortune/presentation/pages/fortune_detail_page.dart`
- `pjh/lib/features/health/presentation/pages/health_alert_settings_page.dart`
- `pjh/lib/features/health/presentation/pages/health_main_page.dart`
- `pjh/lib/features/health/presentation/pages/health_pdf_preview_page.dart`
- `pjh/lib/features/health/presentation/pages/health_record_editor_page.dart`
- `pjh/lib/features/home/presentation/pages/hospital_search_page.dart`
- `pjh/lib/features/home/presentation/pages/hospital_search_page_actions.dart`
- `pjh/lib/features/home/presentation/pages/hospital_search_page_map.dart`
- `pjh/lib/features/home/presentation/pages/hospital_search_page_search.dart`
- `pjh/lib/features/home/presentation/pages/hospital_search_page_ui.dart`
- `pjh/lib/features/mbti/presentation/pages/mbti_result_page.dart`
- `pjh/lib/features/mbti/presentation/pages/mbti_test_page.dart`
- `pjh/lib/features/my/presentation/pages/app_info_page.dart`
- `pjh/lib/features/my/presentation/pages/my_emotion_history_page.dart`
- `pjh/lib/features/my/presentation/pages/my_page.dart`
- `pjh/lib/features/my/presentation/pages/my_posts_page.dart`
- `pjh/lib/features/my/presentation/pages/my_saved_posts_page.dart`
- `pjh/lib/features/my/presentation/pages/my_settings_page.dart`
- `pjh/lib/features/my/presentation/pages/open_source_licenses_page.dart`
- `pjh/lib/features/my/presentation/pages/reward_store_page.dart`
- `pjh/lib/features/news/presentation/pages/news_list_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_complete_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_email_verification_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_login_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_pet_registration_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_profile_setup_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_slides_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_tutorial_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/splash_page.dart`
- `pjh/lib/features/pets/presentation/pages/pet_detail_page.dart`
- `pjh/lib/features/pets/presentation/pages/pet_editor_page.dart`
- `pjh/lib/features/pets/presentation/pages/pet_management_page.dart`
- `pjh/lib/features/pets/presentation/pages/public_pet_page.dart`
- `pjh/lib/features/profile/presentation/pages/community_guidelines_page.dart`
- `pjh/lib/features/profile/presentation/pages/help_page.dart`
- `pjh/lib/features/profile/presentation/pages/notification_settings_page.dart`
- `pjh/lib/features/profile/presentation/pages/privacy_policy_page.dart`
- `pjh/lib/features/profile/presentation/pages/privacy_settings_page.dart`
- `pjh/lib/features/profile/presentation/pages/profile_edit_page.dart`
- `pjh/lib/features/quiz/presentation/pages/quiz_play_page.dart`
- `pjh/lib/features/quiz/presentation/pages/quiz_result_page.dart`
- `pjh/lib/features/social/presentation/pages/channel_subscription_page.dart`
- `pjh/lib/features/social/presentation/pages/comments_page.dart`
- `pjh/lib/features/social/presentation/pages/create_post_page.dart`
- `pjh/lib/features/social/presentation/pages/explore_page.dart`
- `pjh/lib/features/social/presentation/pages/feed_page.dart`
- `pjh/lib/features/social/presentation/pages/followers_page.dart`
- `pjh/lib/features/social/presentation/pages/hashtag_page.dart`
- `pjh/lib/features/social/presentation/pages/home_page.dart`
- `pjh/lib/features/social/presentation/pages/location_picker_page.dart`
- `pjh/lib/features/social/presentation/pages/location_posts_page.dart`
- `pjh/lib/features/social/presentation/pages/notifications_page.dart`
- `pjh/lib/features/social/presentation/pages/post_detail_page.dart`
- `pjh/lib/features/social/presentation/pages/profile_page.dart`
- `pjh/lib/features/social/presentation/pages/search_page.dart`

## 80개 화면 배치 매핑 (80/80)

완료 조건 코드는 아래와 같다. 모든 코드는 공통적으로 정상·로딩·빈 상태·오프라인·
부분 실패·서버 실패·세션 만료, 44pt 터치, VoiceOver, 키보드, SafeArea,
Dynamic Type 200%, 라이트/다크 토큰, 장식 이모지 제거를 포함한다.

| 코드 | 추가 완료 조건 |
|---|---|
| C-AUTH | 입력 보존, 계정 열거 방지, 5상태 redirect, pending deep link, OAuth 보호 |
| C-CHAT | client id 멱등, REST backfill 후 realtime 재구독, 차단·신고·사진 실패 |
| C-AI-LOCK | 기획·read-only 검토만; 의료 고지와 0마리 상태를 별도 해제 승인 후 구현 |
| C-FEED | 작성 draft, 업로드 재시도, 카운터 정합, 신고·차단, visibility fail-closed |
| C-HEALTH | 0마리, 5종 기록, 단위·날짜, 소유권, 알림 권한, PDF 실패 |
| C-HOME-LOCK | 기획·read-only 검토만; 여권 카드·Home 현행을 별도 승인 전 보존 |
| C-MY | 현행 MY 상단 보존, 0/1/다견, soft delete 30일, 대표 직접 재지정 |
| C-ENGAGE | MBTI 이어하기, 퀴즈 멱등, 운세 고지, 뉴스 출처, 포인트 이력 |
| C-INFO | 법적 문구 원문 보존, 외부 링크 실패, 오픈소스 목록 성능·검색·접근성 |

`내부 전환`은 독립 GoRoute가 없고 명시된 소유 화면에서만 여는 페이지 또는
구성 파일이라는 뜻이다. `잠금` 배치는 현재 구현 대상이 아니다.

| path | route/entry | batch | mockup/evidence | completion |
|---|---|---|---|---|
| `pjh/lib/features/auth/presentation/pages/kakao_consent_page.dart` | `/onboarding/kakao-consent` | B1 | W1 auth | C-AUTH |
| `pjh/lib/features/auth/presentation/pages/password_reset_new_password_page.dart` | `/auth/password-reset/new-password` | B1 | W1 auth | C-AUTH |
| `pjh/lib/features/auth/presentation/pages/password_reset_request_page.dart` | `/auth/password-reset/request` | B1 | W1 auth | C-AUTH |
| `pjh/lib/features/auth/presentation/pages/password_reset_verification_page.dart` | `/auth/password-reset/verify` | B1 | W1 auth | C-AUTH |
| `pjh/lib/features/auth/presentation/pages/terms_agreement_page.dart` | `/onboarding/terms` | B1 | W1 auth | C-AUTH |
| `pjh/lib/features/auth/presentation/pages/terms_detail_page.dart` | 내부 전환: terms agreement | B1 | W1 auth | C-AUTH |
| `pjh/lib/features/chat/presentation/pages/chat_detail_page.dart` | `/chat/:roomId` | B4 | Set D chat | C-CHAT |
| `pjh/lib/features/chat/presentation/pages/chat_room_settings_page.dart` | `/chat/:roomId/settings` | B4 | Set D chat | C-CHAT |
| `pjh/lib/features/chat/presentation/pages/chat_rooms_page.dart` | `/chat` | B4 | Set D chat | C-CHAT |
| `pjh/lib/features/chat/presentation/pages/create_chat_page.dart` | `/chat/new` | B4 | Set D chat | C-CHAT |
| `pjh/lib/features/emotion/presentation/pages/ai_history_page.dart` | `/ai-history-page` | B7 잠금 | 2026-07-30 `05-ai-history` | C-AI-LOCK |
| `pjh/lib/features/emotion/presentation/pages/analysis_guide_page.dart` | 내부 전환: `/emotion` | B7 잠금 | AI 현행 캡처 | C-AI-LOCK |
| `pjh/lib/features/emotion/presentation/pages/emotion_analysis_page.dart` | `/emotion` | B7 잠금 | AI 현행 캡처 | C-AI-LOCK |
| `pjh/lib/features/emotion/presentation/pages/emotion_loading_page.dart` | `/emotion/loading` | B7 잠금 | AI 현행 캡처 | C-AI-LOCK |
| `pjh/lib/features/emotion/presentation/pages/emotion_result_loader_page.dart` | `/emotion/result/:analysisId` | B7 잠금 | `07-emotion-result` | C-AI-LOCK |
| `pjh/lib/features/emotion/presentation/pages/emotion_result_page.dart` | 내부 전환: result loader | B7 잠금 | `07-emotion-result` | C-AI-LOCK |
| `pjh/lib/features/emotion/presentation/pages/emotion_timeline_page.dart` | `/emotion-timeline` | B7 잠금 | `05-ai-history` | C-AI-LOCK |
| `pjh/lib/features/emotion/presentation/pages/emotion_trend_page.dart` | 내부 전환: AI history | B7 잠금 | `05-ai-history` | C-AI-LOCK |
| `pjh/lib/features/emotion/presentation/pages/guided_camera_page.dart` | 내부 전환: `/emotion` | B7 잠금 | AI 현행 캡처 | C-AI-LOCK |
| `pjh/lib/features/emotion/presentation/pages/health_loading_page.dart` | 내부 전환: health analysis | B7 잠금 | AI 현행 캡처 | C-AI-LOCK |
| `pjh/lib/features/emotion/presentation/pages/health_result_page.dart` | `/health/result` | B7 잠금 | `07-emotion-result` | C-AI-LOCK |
| `pjh/lib/features/emotion/presentation/pages/weekly_report_page.dart` | `/emotion/weekly-report` | B7 잠금 | `05-ai-history` | C-AI-LOCK |
| `pjh/lib/features/feed_hub/presentation/pages/create_community_post_page.dart` | 내부 전환: `/feed` community | B3 | Set C compose | C-FEED |
| `pjh/lib/features/feed_hub/presentation/pages/feed_hub_page.dart` | `/feed` | B3 | Set C root | C-FEED |
| `pjh/lib/features/fortune/presentation/pages/fortune_detail_page.dart` | `/fortune` | B6 | W5 v2 engagement | C-ENGAGE |
| `pjh/lib/features/health/presentation/pages/health_alert_settings_page.dart` | `/health/alert-settings` | B5 | Set D health | C-HEALTH |
| `pjh/lib/features/health/presentation/pages/health_main_page.dart` | `/health` | B5 | Set D health | C-HEALTH |
| `pjh/lib/features/health/presentation/pages/health_pdf_preview_page.dart` | 내부 전환: `/health` | B5 | Set D health | C-HEALTH |
| `pjh/lib/features/health/presentation/pages/health_record_editor_page.dart` | 내부 전환: `/health` | B5 | Set D health | C-HEALTH |
| `pjh/lib/features/home/presentation/pages/hospital_search_page.dart` | `/hospital` | B8 잠금 | Home 현행 캡처 | C-HOME-LOCK |
| `pjh/lib/features/home/presentation/pages/hospital_search_page_actions.dart` | 내부 구성: `/hospital` | B8 잠금 | Home 현행 캡처 | C-HOME-LOCK |
| `pjh/lib/features/home/presentation/pages/hospital_search_page_map.dart` | 내부 구성: `/hospital` | B8 잠금 | Home 현행 캡처 | C-HOME-LOCK |
| `pjh/lib/features/home/presentation/pages/hospital_search_page_search.dart` | 내부 구성: `/hospital` | B8 잠금 | Home 현행 캡처 | C-HOME-LOCK |
| `pjh/lib/features/home/presentation/pages/hospital_search_page_ui.dart` | 내부 구성: `/hospital` | B8 잠금 | Home 현행 캡처 | C-HOME-LOCK |
| `pjh/lib/features/mbti/presentation/pages/mbti_result_page.dart` | `/mbti/result` | B6 | W5 v2 engagement | C-ENGAGE |
| `pjh/lib/features/mbti/presentation/pages/mbti_test_page.dart` | `/mbti` | B6 | W5 v2 engagement | C-ENGAGE |
| `pjh/lib/features/my/presentation/pages/app_info_page.dart` | 내부 전환: `/settings/my` | B1 | 2026-07-31 release mockup | C-INFO |
| `pjh/lib/features/my/presentation/pages/my_emotion_history_page.dart` | `/history` | B7 잠금 | `05-ai-history` | C-AI-LOCK |
| `pjh/lib/features/my/presentation/pages/my_page.dart` | `/my` | B2 | Set B MY | C-MY |
| `pjh/lib/features/my/presentation/pages/my_posts_page.dart` | `/my/posts` | B2 | Set B MY | C-MY |
| `pjh/lib/features/my/presentation/pages/my_saved_posts_page.dart` | `/my/saved` | B2 | Set B MY | C-MY |
| `pjh/lib/features/my/presentation/pages/my_settings_page.dart` | `/settings/my` | B1 | W1 settings | C-INFO |
| `pjh/lib/features/my/presentation/pages/open_source_licenses_page.dart` | 내부 전환: app info | B1 | 2026-07-31 release mockup | C-INFO |
| `pjh/lib/features/my/presentation/pages/reward_store_page.dart` | `/reward` | B6 | W5 v2 engagement | C-ENGAGE |
| `pjh/lib/features/news/presentation/pages/news_list_page.dart` | `/news` | B6 | W5 v2 engagement | C-ENGAGE |
| `pjh/lib/features/onboarding/presentation/pages/onboarding_complete_page.dart` | `/onboarding/complete` | B1 | W1 auth | C-AUTH |
| `pjh/lib/features/onboarding/presentation/pages/onboarding_email_verification_page.dart` | `/onboarding/email-verification` | B1 | W1 auth | C-AUTH |
| `pjh/lib/features/onboarding/presentation/pages/onboarding_login_page.dart` | `/onboarding/login` | B1 | W1 auth | C-AUTH |
| `pjh/lib/features/onboarding/presentation/pages/onboarding_page.dart` | `/onboarding` | B1 | W1 auth | C-AUTH |
| `pjh/lib/features/onboarding/presentation/pages/onboarding_pet_registration_page.dart` | `/onboarding/pet-registration` | B1 | W1 auth | C-AUTH |
| `pjh/lib/features/onboarding/presentation/pages/onboarding_profile_setup_page.dart` | `/onboarding/profile` | B1 | W1 auth | C-AUTH |
| `pjh/lib/features/onboarding/presentation/pages/onboarding_slides_page.dart` | `/onboarding/slides` | B1 | W1 auth | C-AUTH |
| `pjh/lib/features/onboarding/presentation/pages/onboarding_tutorial_page.dart` | `/onboarding/tutorial` | B1 | W1 auth | C-AUTH |
| `pjh/lib/features/onboarding/presentation/pages/splash_page.dart` | `/splash` | B1 | W1 auth | C-AUTH |
| `pjh/lib/features/pets/presentation/pages/pet_detail_page.dart` | 내부 전환: `/pets` | B2 | Set B pets | C-MY |
| `pjh/lib/features/pets/presentation/pages/pet_editor_page.dart` | PetEditor create/edit routes | B2 | Set B pets | C-MY |
| `pjh/lib/features/pets/presentation/pages/pet_management_page.dart` | `/pets` | B2 | Set B pets | C-MY |
| `pjh/lib/features/pets/presentation/pages/public_pet_page.dart` | `/pet/public/:petId` | B3 | Set C social profile | C-FEED |
| `pjh/lib/features/profile/presentation/pages/community_guidelines_page.dart` | `/community-guidelines` | B1 | W1 settings | C-INFO |
| `pjh/lib/features/profile/presentation/pages/help_page.dart` | `/settings/help` | B1 | W1 settings | C-INFO |
| `pjh/lib/features/profile/presentation/pages/notification_settings_page.dart` | `/settings/notification` | B1 | W1 settings | C-AUTH |
| `pjh/lib/features/profile/presentation/pages/privacy_policy_page.dart` | `/privacy` | B1 | W1 settings | C-INFO |
| `pjh/lib/features/profile/presentation/pages/privacy_settings_page.dart` | `/settings/privacy` | B1 | W1 settings | C-AUTH |
| `pjh/lib/features/profile/presentation/pages/profile_edit_page.dart` | `/my/edit-profile` | B2 | Set B profile | C-MY |
| `pjh/lib/features/quiz/presentation/pages/quiz_play_page.dart` | `/quiz/play` | B6 | W5 v2 engagement | C-ENGAGE |
| `pjh/lib/features/quiz/presentation/pages/quiz_result_page.dart` | `/quiz/result` | B6 | W5 v2 engagement | C-ENGAGE |
| `pjh/lib/features/social/presentation/pages/channel_subscription_page.dart` | `/channels` | B3 | Set C social | C-FEED |
| `pjh/lib/features/social/presentation/pages/comments_page.dart` | 내부 전환: post/feed | B3 | Set C detail | C-FEED |
| `pjh/lib/features/social/presentation/pages/create_post_page.dart` | `/create-post` | B3 | Set C compose | C-FEED |
| `pjh/lib/features/social/presentation/pages/explore_page.dart` | `/explore` | B3 | Set C root | C-FEED |
| `pjh/lib/features/social/presentation/pages/feed_page.dart` | 내부 전환: `/feed` | B3 | Set C root | C-FEED |
| `pjh/lib/features/social/presentation/pages/followers_page.dart` | `/followers/:uid`, `/following/:uid` | B3 | Set C profile | C-FEED |
| `pjh/lib/features/social/presentation/pages/hashtag_page.dart` | `/hashtag/:tag` | B3 | Set C search | C-FEED |
| `pjh/lib/features/social/presentation/pages/home_page.dart` | `/home` | B8 잠금 | Home 현행 캡처 | C-HOME-LOCK |
| `pjh/lib/features/social/presentation/pages/location_picker_page.dart` | 내부 전환: 작성, 정책 확정 전 숨김 | B3 | 위치 미수집 정책 | C-FEED |
| `pjh/lib/features/social/presentation/pages/location_posts_page.dart` | `/location`, 정책 확정 전 숨김 | B3 | 위치 미수집 정책 | C-FEED |
| `pjh/lib/features/social/presentation/pages/notifications_page.dart` | `/notifications` | B3 | Set C social | C-FEED |
| `pjh/lib/features/social/presentation/pages/post_detail_page.dart` | `/post/:postId` | B3 | Set C detail | C-FEED |
| `pjh/lib/features/social/presentation/pages/profile_page.dart` | `/user-profile/:userId` | B3 | Set C profile | C-FEED |
| `pjh/lib/features/social/presentation/pages/search_page.dart` | `/search` | B3 | Set C search | C-FEED |

## Feature 테스트 파일 155개

- `pjh/test/features/auth/data/services/apple_account_deletion_authorization_test.dart`
- `pjh/test/features/auth/domain/services/account_deletion_policy_test.dart`
- `pjh/test/features/auth/presentation/bloc/auth_bloc_test.dart`
- `pjh/test/features/auth/presentation/pages/kakao_consent_page_test.dart`
- `pjh/test/features/auth/presentation/pages/password_reset_new_password_page_test.dart`
- `pjh/test/features/auth/presentation/pages/password_reset_request_page_test.dart`
- `pjh/test/features/auth/presentation/pages/password_reset_verification_page_test.dart`
- `pjh/test/features/auth/presentation/pages/terms_agreement_page_test.dart`
- `pjh/test/features/auth/presentation/pages/terms_detail_page_test.dart`
- `pjh/test/features/chat/data/repositories/chat_block_filter_test.dart`
- `pjh/test/features/chat/data/repositories/chat_repository_impl_test.dart`
- `pjh/test/features/chat/domain/usecases/report_chat_target_test.dart`
- `pjh/test/features/chat/presentation/bloc/chat_detail/chat_detail_bloc_test.dart`
- `pjh/test/features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc_test.dart`
- `pjh/test/features/chat/presentation/pages/chat_detail_page_test.dart`
- `pjh/test/features/chat/presentation/pages/chat_room_settings_page_test.dart`
- `pjh/test/features/chat/presentation/pages/chat_rooms_page_test.dart`
- `pjh/test/features/chat/presentation/pages/create_chat_page_test.dart`
- `pjh/test/features/chat/presentation/widgets/chat_bubble_test.dart`
- `pjh/test/features/chat/presentation/widgets/chat_input_bar_test.dart`
- `pjh/test/features/chat/presentation/widgets/chat_room_tile_test.dart`
- `pjh/test/features/emotion/ai_history_behavior_test.dart`
- `pjh/test/features/emotion/ai_history_bloc_test.dart`
- `pjh/test/features/emotion/ai_history_presentation_test.dart`
- `pjh/test/features/emotion/ai_history_ui_consistency_test.dart`
- `pjh/test/features/emotion/domain/usecases/get_previous_analysis_test.dart`
- `pjh/test/features/emotion/emotion_result_loader_page_test.dart`
- `pjh/test/features/emotion/emotion_timeline_page_test.dart`
- `pjh/test/features/emotion/presentation/bloc/emotion_analysis_bloc_test.dart`
- `pjh/test/features/emotion/presentation/constants/camera_overlay_content_test.dart`
- `pjh/test/features/emotion/presentation/constants/capture_guide_content_test.dart`
- `pjh/test/features/emotion/presentation/pages/analysis_guide_page_test.dart`
- `pjh/test/features/emotion/presentation/widgets/bottom_action_bar_test.dart`
- `pjh/test/features/emotion/widgets/paw_position_calculator_test.dart`
- `pjh/test/features/feed_hub/domain/community_post_test.dart`
- `pjh/test/features/feed_hub/presentation/community_cubit_test.dart`
- `pjh/test/features/feed_hub/presentation/pages/create_community_post_page_test.dart`
- `pjh/test/features/feed_hub/presentation/pages/feed_hub_page_test.dart`
- `pjh/test/features/feed_hub/presentation/widgets/community_post_card_test.dart`
- `pjh/test/features/fortune/data/fortune_content_test.dart`
- `pjh/test/features/fortune/data/fortune_seen_test.dart`
- `pjh/test/features/fortune/domain/fortune_generator_test.dart`
- `pjh/test/features/fortune/domain/fortune_group_test.dart`
- `pjh/test/features/fortune/fortune_analytics_test.dart`
- `pjh/test/features/fortune/presentation/fortune_detail_page_test.dart`
- `pjh/test/features/fortune/presentation/fortune_share_card_test.dart`
- `pjh/test/features/fortune/presentation/home_fortune_card_test.dart`
- `pjh/test/features/health/domain/entities/health_record_test.dart`
- `pjh/test/features/health/domain/usecases/health_usecases_test.dart`
- `pjh/test/features/health/presentation/bloc/health_bloc_test.dart`
- `pjh/test/features/health/presentation/emotion_trend_chart_test.dart`
- `pjh/test/features/health/presentation/health_alert_settings_page_test.dart`
- `pjh/test/features/health/presentation/health_emotion_loader_test.dart`
- `pjh/test/features/health/presentation/health_main_page_test.dart`
- `pjh/test/features/health/presentation/health_pdf_data_test.dart`
- `pjh/test/features/health/presentation/health_pdf_preview_page_test.dart`
- `pjh/test/features/health/presentation/health_record_card_test.dart`
- `pjh/test/features/health/presentation/health_record_data_test.dart`
- `pjh/test/features/health/presentation/health_record_editor_page_test.dart`
- `pjh/test/features/health/presentation/weight_trend_test.dart`
- `pjh/test/features/home/hospital_search_page_widget_test.dart`
- `pjh/test/features/home/passport_mood_mapper_test.dart`
- `pjh/test/features/home/presentation/widgets/home_quick_actions_test.dart`
- `pjh/test/features/mbti/data/mbti_content_test.dart`
- `pjh/test/features/mbti/domain/mbti_scorer_test.dart`
- `pjh/test/features/mbti/mbti_reward_gating_test.dart`
- `pjh/test/features/my/pet_life_summary_test.dart`
- `pjh/test/features/my/pet_summary_section_render_test.dart`
- `pjh/test/features/my/presentation/pages/app_release_info_pages_test.dart`
- `pjh/test/features/my/presentation/pages/my_page_test.dart`
- `pjh/test/features/my/presentation/pages/my_posts_page_test.dart`
- `pjh/test/features/my/presentation/pages/my_saved_posts_page_test.dart`
- `pjh/test/features/my/presentation/pages/my_settings_page_test.dart`
- `pjh/test/features/my/presentation/widgets/my_profile_header_test.dart`
- `pjh/test/features/my/presentation/widgets/saved_posts_grid_test.dart`
- `pjh/test/features/news/data/news_article_model_test.dart`
- `pjh/test/features/news/data/news_repository_impl_test.dart`
- `pjh/test/features/news/presentation/news_bloc_test.dart`
- `pjh/test/features/onboarding/presentation/pages/onboarding_complete_page_test.dart`
- `pjh/test/features/onboarding/presentation/pages/onboarding_email_verification_page_test.dart`
- `pjh/test/features/onboarding/presentation/pages/onboarding_login_page_test.dart`
- `pjh/test/features/onboarding/presentation/pages/onboarding_pet_registration_page_test.dart`
- `pjh/test/features/onboarding/presentation/pages/onboarding_profile_setup_page_test.dart`
- `pjh/test/features/onboarding/presentation/pages/splash_page_test.dart`
- `pjh/test/features/pets/data/pet_repository_passport_test.dart`
- `pjh/test/features/pets/data/pet_selected_repository_test.dart`
- `pjh/test/features/pets/domain/passport_number_generator_test.dart`
- `pjh/test/features/pets/presentation/bloc/pet_bloc_test.dart`
- `pjh/test/features/pets/presentation/pages/pet_detail_page_test.dart`
- `pjh/test/features/pets/presentation/pages/pet_editor_page_test.dart`
- `pjh/test/features/pets/presentation/pages/pet_management_page_test.dart`
- `pjh/test/features/pets/presentation/pages/public_pet_page_test.dart`
- `pjh/test/features/pets/presentation/widgets/pet_card_test.dart`
- `pjh/test/features/profile/presentation/pages/community_guidelines_page_test.dart`
- `pjh/test/features/profile/presentation/pages/help_page_test.dart`
- `pjh/test/features/profile/presentation/pages/notification_settings_page_test.dart`
- `pjh/test/features/profile/presentation/pages/privacy_settings_page_test.dart`
- `pjh/test/features/profile/presentation/pages/profile_edit_page_test.dart`
- `pjh/test/features/quiz/data/quiz_content_test.dart`
- `pjh/test/features/quiz/data/quiz_local_test.dart`
- `pjh/test/features/quiz/domain/quiz_prng_test.dart`
- `pjh/test/features/quiz/domain/quiz_selector_test.dart`
- `pjh/test/features/quiz/presentation/home_quiz_card_test.dart`
- `pjh/test/features/quiz/presentation/quiz_feedback_color_test.dart`
- `pjh/test/features/quiz/presentation/quiz_play_page_test.dart`
- `pjh/test/features/quiz/presentation/quiz_result_page_test.dart`
- `pjh/test/features/social/data/datasources/social_remote_data_source_impl_like_test.dart`
- `pjh/test/features/social/data/datasources/social_remote_data_source_impl_user_search_test.dart`
- `pjh/test/features/social/data/models/notification_model_test.dart`
- `pjh/test/features/social/data/post_model_category_test.dart`
- `pjh/test/features/social/data/repositories/social_repository_impl_block_test.dart`
- `pjh/test/features/social/data/repositories/social_repository_impl_bookmark_test.dart`
- `pjh/test/features/social/data/repositories/social_repository_impl_follow_test.dart`
- `pjh/test/features/social/data/repositories/social_repository_impl_like_test.dart`
- `pjh/test/features/social/data/repositories/social_repository_impl_report_test.dart`
- `pjh/test/features/social/data/repositories/social_repository_impl_search_test.dart`
- `pjh/test/features/social/domain/entities/post_likes_page_test.dart`
- `pjh/test/features/social/domain/entities/saved_posts_page_test.dart`
- `pjh/test/features/social/domain/usecases/bookmark_usecases_test.dart`
- `pjh/test/features/social/presentation/bloc/bookmark_bloc_test.dart`
- `pjh/test/features/social/presentation/bloc/comment_bloc_test.dart`
- `pjh/test/features/social/presentation/bloc/feed_bloc_test.dart`
- `pjh/test/features/social/presentation/bloc/notification_badge_bloc_test.dart`
- `pjh/test/features/social/presentation/bloc/search_bloc_test.dart`
- `pjh/test/features/social/presentation/controllers/post_interaction_coordinator_test.dart`
- `pjh/test/features/social/presentation/pages/comments_page_test.dart`
- `pjh/test/features/social/presentation/pages/create_post_page_test.dart`
- `pjh/test/features/social/presentation/pages/explore_route_test.dart`
- `pjh/test/features/social/presentation/pages/feed_comments_entry_test.dart`
- `pjh/test/features/social/presentation/pages/feed_page_state_test.dart`
- `pjh/test/features/social/presentation/pages/followers_page_test.dart`
- `pjh/test/features/social/presentation/pages/hashtag_page_test.dart`
- `pjh/test/features/social/presentation/pages/location_picker_page_test.dart`
- `pjh/test/features/social/presentation/pages/location_posts_page_test.dart`
- `pjh/test/features/social/presentation/pages/notifications_page_test.dart`
- `pjh/test/features/social/presentation/pages/post_detail_page_test.dart`
- `pjh/test/features/social/presentation/pages/profile_page_test.dart`
- `pjh/test/features/social/presentation/pages/search_page_test.dart`
- `pjh/test/features/social/presentation/utils/post_draft_storage_test.dart`
- `pjh/test/features/social/presentation/utils/saved_posts_change_notifier_test.dart`
- `pjh/test/features/social/presentation/widgets/collection_picker_sheet_test.dart`
- `pjh/test/features/social/presentation/widgets/comment_card_test.dart`
- `pjh/test/features/social/presentation/widgets/comment_list_item_test.dart`
- `pjh/test/features/social/presentation/widgets/comments_bottom_sheet_test.dart`
- `pjh/test/features/social/presentation/widgets/create_post_bottom_sheet_test.dart`
- `pjh/test/features/social/presentation/widgets/edit_post_bottom_sheet_test.dart`
- `pjh/test/features/social/presentation/widgets/likes_bottom_sheet_test.dart`
- `pjh/test/features/social/presentation/widgets/post_card_bookmark_test.dart`
- `pjh/test/features/social/presentation/widgets/post_card_connector_test.dart`
- `pjh/test/features/social/presentation/widgets/post_card_like_test.dart`
- `pjh/test/features/social/presentation/widgets/profile_stats_card_test.dart`
- `pjh/test/features/social/presentation/widgets/social_content_report_sheet_test.dart`
- `pjh/test/features/social/presentation/widgets/social_user_actions_sheet_test.dart`
- `pjh/test/features/social/presentation/widgets/user_list_tile_test.dart`
- `pjh/test/features/social/presentation/widgets/user_posts_list_test.dart`

## 별도 공통·계약 검증

- `pjh/test/contracts/auth_log_redaction_contract_test.dart`
- `pjh/test/contracts/p2a1_notification_contract_test.dart`
- `pjh/test/contracts/p2b_block_privacy_contract_test.dart`
- `pjh/test/core/navigation/settings_routes_test.dart`
- `pjh/test/core/services/local_notification_service_test.dart`
- `pjh/test/core/services/profile_service_test.dart`
- `pjh/test/shared/widgets/petspace_settings_components_test.dart`
- `pjh/test/shared/widgets/petspace_state_view_test.dart`

## 보호 범위

- `pjh/lib/features/home/`: 이번 정본에서는 기획만 허용, 구현 잠금
- `pjh/lib/features/emotion/presentation/pages/emotion_result_page.dart`: 기획만 허용, 구현 잠금
- Apple 로그인·OAuth·URL scheme·entitlement
- `pjh/ios/Podfile`
- `pjh/ios/Podfile.lock`
- `pjh/ios/Runner/Runner.entitlements`
- `pjh/ios/Runner/Info.plist`
- `pjh/ios/Runner.xcodeproj/project.pbxproj`
- `pjh/lib/firebase_options.dart`
- `pjh/lib/core/utils/share_origin.dart`
- `pjh/lib/features/auth/data/repositories/auth_repository_impl.dart`
- `supabase/petspace_setup.sql`

비밀 파일, Firebase plist 내용, 환경변수, 인증서, 키, provisioning profile,
사용자 데이터, 로그, 빌드 생성물은 기획·목업·외부 리뷰 인벤토리에 포함하지
않는다.
