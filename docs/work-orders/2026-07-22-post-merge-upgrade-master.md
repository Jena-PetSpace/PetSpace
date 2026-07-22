# PetSpace 통합 후 업그레이드 Master Work Order

> 기준 SHA: `c49a8c4`
> 기획 리뷰: Codex 단독 3-pass 완료
> 상태: 기획 완료, 구현 미승인
> 제외: 홈 탭, AI 분석 탭·결과·히스토리, 하단 5탭 재설계, 운영 배포

## 1. 공통 실행 계약

1. wave마다 `c49a8c4` 이상 최신 `mac-ios-release`에서 별도 feature worktree를 만든다.
2. 구현 전 production file, test file, 보호 file을 개별 경로로 고정한다.
3. 화면 코드보다 실패·빈 상태·접근성 test를 먼저 또는 같은 commit에 추가한다.
4. `secrets.dart`, `.env*`, Google plist, 인증서·키·provisioning profile은 stage·commit·log·manifest에 넣지 않는다.
5. Apple/OAuth URL scheme·entitlement, K1/H2, `auth.uid()` RPC, health root navigator, iPad `shareOrigin`은 보호한다.
6. raw exception, UID, 이메일, OAuth URL/token, SQL, storage path를 사용자 메시지나 운영 log에 넣지 않는다.
7. `git add -A`를 쓰지 않고 manifest 경로만 stage한다.
8. DB/RPC·Edge·APNs가 필요하면 해당 wave를 멈추고 별도 backend work order를 만든다.

## 2. UI/UX 공통 완료 기준

- 화면 상태는 loading / content / empty / recoverable error / blocking error를 구분한다.
- 제출 중 action은 1회만 실행되고 입력·선택값을 보존한다.
- 성공 안내는 repository/server 성공 뒤에만 표시한다.
- 모든 아이콘 action과 선택 control은 한국어 이름, 역할, 선택 상태를 제공한다.
- interactive target은 최소 44×44pt다.
- iPhone 320×568, 390×844, text scale 100%·150%·200%에서 overflow가 없다.
- 키보드, 뒤로 가기, 앱 background/foreground에서 입력 손실이 없다.
- 내부 오류 대신 사용자가 다음 행동을 알 수 있는 안전한 한국어 메시지를 사용한다.
- 다크 모드와 고대비에서 텍스트·선택 상태를 색 하나에만 의존하지 않는다.

## 3. W0 — 인증·온보딩 신뢰도

### 목표

- 약관 저장 성공과 화면 진행을 원자적으로 맞춘다.
- OAuth·이메일 로그인·재설정·계정 복구의 신규/기존/취소/실패 상태를 고정한다.
- PII·raw exception 노출을 차단한다.
- 온보딩 15화면의 최소 page test 안전망을 만든다.

### 예상 production manifest

- `pjh/lib/core/navigation/app_router.dart`
- `pjh/lib/core/error/error_messages.dart`
- `pjh/lib/features/auth/presentation/bloc/auth_bloc.dart`
- `pjh/lib/features/auth/presentation/pages/kakao_consent_page.dart`
- `pjh/lib/features/auth/presentation/pages/password_reset_request_page.dart`
- `pjh/lib/features/auth/presentation/pages/password_reset_verification_page.dart`
- `pjh/lib/features/auth/presentation/pages/password_reset_new_password_page.dart`
- `pjh/lib/features/auth/presentation/pages/terms_agreement_page.dart`
- `pjh/lib/features/auth/presentation/pages/terms_detail_page.dart`
- `pjh/lib/features/onboarding/presentation/bloc/onboarding_bloc.dart`
- `pjh/lib/features/onboarding/presentation/pages/splash_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_slides_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_login_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_email_verification_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_profile_setup_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_pet_registration_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_tutorial_page.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_complete_page.dart`

이 목록은 최대 후보 집합이다. 실제 구현 전 하위 작업을 W0-A 약관·로그, W0-B 로그인·재설정, W0-C 프로필·펫·완료로 나누고 각 manifest를 축소한다.

### 정확한 test manifest

- 기존: `pjh/test/features/auth/presentation/bloc/auth_bloc_test.dart`
- 기존: `pjh/test/features/auth/domain/services/account_deletion_policy_test.dart`
- 신규: `pjh/test/features/auth/presentation/pages/terms_agreement_page_test.dart`
- 신규: `pjh/test/features/auth/presentation/pages/password_reset_request_page_test.dart`
- 신규: `pjh/test/features/auth/presentation/pages/password_reset_verification_page_test.dart`
- 신규: `pjh/test/features/auth/presentation/pages/password_reset_new_password_page_test.dart`
- 신규: `pjh/test/features/auth/presentation/pages/kakao_consent_page_test.dart`
- 신규: `pjh/test/features/onboarding/presentation/pages/splash_page_test.dart`
- 신규: `pjh/test/features/onboarding/presentation/pages/onboarding_login_page_test.dart`
- 신규: `pjh/test/features/onboarding/presentation/pages/onboarding_email_verification_page_test.dart`
- 신규: `pjh/test/features/onboarding/presentation/pages/onboarding_profile_setup_page_test.dart`
- 신규: `pjh/test/features/onboarding/presentation/pages/onboarding_pet_registration_page_test.dart`
- 신규: `pjh/test/features/onboarding/presentation/pages/onboarding_complete_page_test.dart`
- 신규: `pjh/test/contracts/public_error_message_contract_test.dart`
- 신규: `pjh/test/contracts/auth_log_redaction_contract_test.dart`

### 사용자 승인 전 결정할 문구

- 회원가입 `성명/실명`을 실제 법적 이름이 아닌 `닉네임`으로 바꿀지 여부
- 필수 동의 저장 실패 시 오프라인 진행을 완전히 막을지, 임시 로컬 큐를 둘지 여부
- 온보딩 완료의 기본 CTA를 홈으로 둘지, 현행 AI 시작 CTA를 유지할지 여부

### 검증 시나리오

- Apple/Google/Kakao: 성공, 사용자 취소, 네트워크 실패, 기존 계정, soft-delete 복구
- 이메일: 로그인, 회원가입, 인증 재발송 rate limit, 잘못된 코드, 비밀번호 재설정
- 약관: 필수 미동의, 선택 미동의, 저장 성공, 저장 실패·재시도, 중복 탭
- 프로필·펫: 사진 취소, 업로드 실패·재시도, 작은 화면·키보드, 앱 재진입

## 4. W1 — 공용 접근성·상태 표현

### 목표

실제 Simulator AX에서 확인된 이름·역할 누락을 공용 위젯에서 먼저 고친다.

### production manifest

- `pjh/lib/shared/widgets/category_chip.dart`
- `pjh/lib/shared/widgets/petspace_settings_components.dart`
- `pjh/lib/shared/widgets/image_viewer_page.dart`
- `pjh/lib/features/my/presentation/pages/my_page.dart`
- `pjh/lib/features/feed_hub/presentation/pages/feed_hub_page.dart`

### test manifest

- 신규: `pjh/test/shared/widgets/category_chip_test.dart`
- 신규: `pjh/test/shared/widgets/petspace_settings_components_test.dart`
- 신규: `pjh/test/shared/widgets/image_viewer_page_test.dart`
- 기존: `pjh/test/features/my/presentation/pages/my_page_test.dart`
- 신규: `pjh/test/features/feed_hub/presentation/pages/feed_hub_page_test.dart`
- 기존: `pjh/test/widget_test.dart`

### 완료 조건

- `내 게시물`, `저장한 게시물` 탭 이름과 selected 상태가 읽힌다.
- 라운지 칩이 button + selected 상태로 읽힌다.
- 설정 행이 하나의 button으로 읽히고 제목·부제·상태가 중복 낭독되지 않는다.
- 미디어 닫기, 페이지 위치, 이미지 로드 실패가 의미 있게 읽힌다.
- 홈 헤더 아이콘 문제는 이 wave에서 수정하지 않고 홈 전용 backlog로 이관한다.

## 5. W2 — 반려동물·MY 일관성

### 목표

- 온보딩과 일반 editor의 검증·업로드·품종 계약을 공유한다.
- MY의 내 글·저장·프로필·펫 전환 상태를 일관되게 만든다.
- 내부 예외 문자열을 반려동물 오류 화면에 노출하지 않는다.

### 예상 production manifest

- `pjh/lib/features/pets/presentation/pages/pet_editor_page.dart`
- `pjh/lib/features/pets/presentation/widgets/pet_editor_form_widgets.dart`
- `pjh/lib/features/pets/presentation/pages/pet_management_page.dart`
- `pjh/lib/features/pets/presentation/pages/pet_detail_page.dart`
- `pjh/lib/features/pets/presentation/pages/public_pet_page.dart`
- `pjh/lib/features/pets/presentation/bloc/pet_bloc.dart`
- `pjh/lib/features/onboarding/presentation/pages/onboarding_pet_registration_page.dart`
- `pjh/lib/features/my/presentation/pages/my_page.dart`
- `pjh/lib/features/my/presentation/pages/my_posts_page.dart`
- `pjh/lib/features/my/presentation/pages/my_saved_posts_page.dart`
- `pjh/lib/features/my/presentation/widgets/my_profile_header.dart`

### test manifest

- `pjh/test/features/pets/presentation/pages/pet_editor_page_test.dart`
- `pjh/test/features/pets/presentation/pages/pet_management_page_test.dart`
- `pjh/test/features/pets/presentation/pages/pet_detail_page_test.dart`
- 신규: `pjh/test/features/pets/presentation/pages/public_pet_page_test.dart`
- `pjh/test/features/pets/presentation/widgets/pet_card_test.dart`
- `pjh/test/features/my/presentation/pages/my_page_test.dart`
- 신규: `pjh/test/features/my/presentation/pages/my_posts_page_test.dart`
- `pjh/test/features/my/presentation/pages/my_saved_posts_page_test.dart`
- `pjh/test/features/my/presentation/widgets/my_profile_header_test.dart`

### UX 결정

- 필수 정보와 선택 정보의 단계는 유지한다.
- 업로드 실패 시 텍스트 입력과 선택한 로컬 사진을 보존한다.
- 대표 반려동물 변경은 성공 후에만 전역 선택·테두리·홈/건강 소비 상태에 반영한다.
- MY에서 숨겨진 MBTI·펫 요약은 사용자 승인 전 재노출하지 않는다.

## 6. W3 — 피드·소셜 마감

### 목표

- 작성·임시저장·위치·알림 화면의 page test 공백을 닫는다.
- 발견/라운지의 상태·카테고리·작성 진입을 명확히 한다.
- 좋아요·저장·댓글·신고·차단·공유가 카드·상세·MY에서 같은 서버 정본을 따른다.

### 예상 production manifest

- `pjh/lib/features/feed_hub/presentation/pages/feed_hub_page.dart`
- `pjh/lib/features/feed_hub/presentation/pages/create_community_post_page.dart`
- `pjh/lib/features/feed_hub/presentation/cubit/community_cubit.dart`
- `pjh/lib/features/social/presentation/pages/feed_page.dart`
- `pjh/lib/features/social/presentation/pages/create_post_page.dart`
- `pjh/lib/features/social/presentation/pages/search_page.dart`
- `pjh/lib/features/social/presentation/pages/explore_page.dart`
- `pjh/lib/features/social/presentation/pages/post_detail_page.dart`
- `pjh/lib/features/social/presentation/pages/notifications_page.dart`
- `pjh/lib/features/social/presentation/pages/location_picker_page.dart`
- `pjh/lib/features/social/presentation/pages/location_posts_page.dart`
- `pjh/lib/features/social/presentation/pages/profile_page.dart`
- `pjh/lib/features/social/presentation/pages/followers_page.dart`
- `pjh/lib/features/social/presentation/widgets/post_card.dart`
- `pjh/lib/features/social/presentation/widgets/comments_bottom_sheet.dart`
- `pjh/lib/features/social/presentation/widgets/likes_bottom_sheet.dart`
- `pjh/lib/features/social/presentation/widgets/collection_picker_sheet.dart`

### 필수 test manifest

- 신규: `pjh/test/features/feed_hub/presentation/pages/feed_hub_page_test.dart`
- 신규: `pjh/test/features/feed_hub/presentation/pages/create_community_post_page_test.dart`
- 신규: `pjh/test/features/social/presentation/pages/create_post_page_test.dart`
- 신규: `pjh/test/features/social/presentation/pages/notifications_page_test.dart`
- 신규: `pjh/test/features/social/presentation/pages/location_picker_page_test.dart`
- `pjh/test/features/social/presentation/pages/search_page_test.dart`
- `pjh/test/features/social/presentation/pages/feed_page_state_test.dart`
- `pjh/test/features/social/presentation/pages/post_detail_page_test.dart`
- `pjh/test/features/social/presentation/pages/followers_page_test.dart`
- `pjh/test/features/social/presentation/pages/location_posts_page_test.dart`
- `pjh/test/features/social/presentation/widgets/post_card_connector_test.dart`
- `pjh/test/features/social/presentation/widgets/comments_bottom_sheet_test.dart`
- `pjh/test/features/social/presentation/widgets/likes_bottom_sheet_test.dart`
- `pjh/test/features/social/presentation/widgets/collection_picker_sheet_test.dart`
- `pjh/test/core/utils/public_ai_text_test.dart`

### 별도 결정

- `/channels`를 제품에 재노출할지 제거할지
- 구형 `comments_page.dart`를 삭제하고 bottom sheet만 정본으로 둘지
- `/explore`를 딥링크 호환 redirect로만 유지할지

## 7. W4 — 건강 기록 무결성·도구

### 목표

- 의미 없는 빈 기록 생성을 방지한다.
- 유형별 필수값과 오류 위치를 명확히 한다.
- PDF·알림이 실제 제공 범위를 과장하지 않도록 한다.

### production manifest

- `pjh/lib/features/health/presentation/pages/health_main_page.dart`
- `pjh/lib/features/health/presentation/widgets/health_record_sheets.dart`
- `pjh/lib/features/health/presentation/widgets/health_record_data.dart`
- `pjh/lib/features/health/presentation/widgets/health_record_card.dart`
- `pjh/lib/features/health/presentation/pages/health_pdf_preview_page.dart`
- `pjh/lib/features/health/presentation/widgets/health_pdf_data.dart`
- `pjh/lib/features/health/presentation/widgets/health_pdf_generator.dart`
- `pjh/lib/features/health/presentation/pages/health_alert_settings_page.dart`
- `pjh/lib/features/health/presentation/bloc/health_bloc.dart`

### test manifest

- 신규: `pjh/test/features/health/presentation/health_main_page_test.dart`
- 신규: `pjh/test/features/health/presentation/health_record_sheets_test.dart`
- `pjh/test/features/health/presentation/health_record_data_test.dart`
- `pjh/test/features/health/presentation/health_record_card_test.dart`
- `pjh/test/features/health/presentation/health_pdf_data_test.dart`
- 신규: `pjh/test/features/health/presentation/health_pdf_preview_page_test.dart`
- `pjh/test/features/health/presentation/health_alert_settings_page_test.dart`
- `pjh/test/features/health/presentation/bloc/health_bloc_test.dart`
- `pjh/test/features/health/presentation/weight_trend_test.dart`
- `pjh/test/features/health/presentation/emotion_trend_chart_test.dart`

### 시뮬레이터 시나리오

- pet 0/1/2마리, 빠른 전환, 늦은 응답
- 각 5유형 add/edit/delete, 빈값, 중복 탭, 실패·재시도
- 필터 empty와 전체 empty, 과거/오늘/미래 날짜와 D-day
- PDF 빈 섹션·한글·공유 취소·실패
- 알림 허용/거부/설정 이동과 `준비 중` 문구

## 8. W5 — 채팅·알림 실사용 검증

### 목표

- 2계정에서 1:1·그룹·실시간·읽음·차단 계약을 증명한다.
- 실패한 메시지·이미지의 입력과 재시도 상태를 보존한다.
- 관리자와 일반 멤버 권한을 서버·UI에서 일치시킨다.

### production manifest

- `pjh/lib/features/chat/presentation/pages/chat_rooms_page.dart`
- `pjh/lib/features/chat/presentation/pages/create_chat_page.dart`
- `pjh/lib/features/chat/presentation/pages/chat_detail_page.dart`
- `pjh/lib/features/chat/presentation/pages/chat_room_settings_page.dart`
- `pjh/lib/features/chat/presentation/widgets/chat_input_bar.dart`
- `pjh/lib/features/chat/presentation/widgets/chat_bubble.dart`
- `pjh/lib/features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc.dart`
- `pjh/lib/features/chat/presentation/bloc/chat_detail/chat_detail_bloc.dart`
- `pjh/lib/features/profile/presentation/pages/notification_settings_page.dart`

### test manifest

- `pjh/test/features/chat/presentation/pages/chat_rooms_page_test.dart`
- `pjh/test/features/chat/presentation/pages/create_chat_page_test.dart`
- `pjh/test/features/chat/presentation/pages/chat_detail_page_test.dart`
- `pjh/test/features/chat/presentation/pages/chat_room_settings_page_test.dart`
- `pjh/test/features/chat/presentation/widgets/chat_input_bar_test.dart`
- `pjh/test/features/chat/presentation/widgets/chat_bubble_test.dart`
- `pjh/test/features/chat/presentation/bloc/chat_rooms/chat_rooms_bloc_test.dart`
- `pjh/test/features/chat/presentation/bloc/chat_detail/chat_detail_bloc_test.dart`
- `pjh/test/features/profile/presentation/pages/notification_settings_page_test.dart`
- 신규: `pjh/integration_test/chat_two_account_smoke_test.dart`

실제 2계정 test는 테스트 프로젝트·데이터 정리 절차를 먼저 승인받는다. 운영 사용자 데이터로 실행하지 않는다.

## 9. W6 — 휴면 경로·문서·QA 정본화

### 검토 대상 production 경로

- `pjh/lib/core/navigation/app_router.dart`
- `pjh/lib/features/social/presentation/pages/channel_subscription_page.dart`
- `pjh/lib/features/social/presentation/pages/comments_page.dart`
- `pjh/lib/features/my/presentation/pages/reward_store_page.dart`
- `pjh/lib/features/my/presentation/pages/my_page.dart`

### 문서 경로

- `docs/README.md`
- `docs/DEVELOPER_GUIDE.md`
- `docs/qa/RELEASE_DEPLOY_VERIFY_CHECKLIST.md`
- `docs/MAC_MINI_HANDOFF.md`
- `docs/reviews/2026-07-22-post-merge-full-app-audit.md`
- `docs/work-orders/2026-07-22-post-merge-upgrade-master.md`

### 결정 기준

- 외부 딥링크·푸시·저장된 URL 호환이 있으면 redirect로 보존한다.
- 진입점·데이터·제품 가치가 없고 호환 의무도 없으면 별도 삭제 manifest를 만든다.
- 숨김 기능을 코드 상수만 바꿔 재노출하지 않는다.

## 10. wave별 검증 명령

각 wave의 정확한 modified/test manifest로 format과 집중 test 인자를 확정한 뒤 다음을 실행한다.

```bash
cd pjh
dart format --output=none --set-exit-if-changed <modified-dart-paths>
flutter analyze --no-pub
flutter test --no-pub <exact-test-path-1> <exact-test-path-2>
flutter test --no-pub
flutter build ios --release --no-codesign --no-pub
cd ..
git diff --check
rg -n '^(<<<<<<<|=======|>>>>>>>)' pjh/lib pjh/test
```

추가 확인:

- stage 직전 `git diff --cached --name-only`에 secret 경로가 없어야 한다.
- `git ls-files --error-unmatch pjh/lib/config/secrets.dart`는 실패해야 한다.
- 보호 파일 diff가 있으면 즉시 중단한다.
- 신규 실패를 baseline으로 재분류하거나 test를 skip하지 않는다.

## 11. 중단 조건

- Apple/OAuth·URL scheme·entitlement 변경 필요
- K1/H2, `auth.uid()` RPC, RLS 변경 필요
- 광범위 `public.users SELECT` 또는 caller-id RPC 복구 필요
- manifest 밖 production 파일 변경 필요
- raw secret·PII 노출
- 테스트 삭제·skip·기대값 약화 필요
- blocker/high가 해결되지 않은 상태에서 release merge 요청

이 경우 구현을 멈추고 정확한 추가 manifest와 사용자 결정을 요청한다.

## 12. 권고하는 다음 실행

가장 작은 첫 구현은 **W0-A 약관 저장·PII log redaction·해당 test**다. UI 전면 개편 없이 법적 증빙과 오류 경계를 먼저 닫을 수 있다. 그다음 **W1 공용 접근성**을 진행하고, 화면별 W2~W5로 이동한다.
