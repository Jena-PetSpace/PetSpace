# PetSpace 전수 페이지 감사 진행률

**시작일:** 2026-04-22
**브랜치:** mac-ios-release
**목표:** 67개 페이지의 모든 상호작용 요소를 코드 기반으로 카탈로그화 → 실제 검증 → 버그 기록

---

## 전체 진행률

- **총 페이지 수:** 67개
- **완료:** 8개
- **진행률:** 11.9%

---

## Feature별 진행

- [x] **auth (8/8) ✅ — Phase 1 완료**
- [ ] onboarding (0/9) — Phase 2
- [ ] home (0/1) — Phase 3
- [ ] health (0/2) — Phase 4
- [ ] emotion (0/12) — Phase 5
- [ ] feed_hub (0/2) — Phase 6
- [ ] social (0/13) — Phase 7
- [ ] my (0/6) — Phase 8
- [ ] profile (0/7) — Phase 9
- [ ] pets (0/3) — Phase 10
- [ ] chat (0/4) — Phase 11

---

## Phase별 상세

### Phase 1 — auth (8/8) ✅
- [x] kakao_consent_page.dart — 상호작용 6, 버그 5 (M2/L3)
- [x] login_page.dart — 상호작용 8, 버그 3 (H2/L1) **DEAD CODE**
- [x] password_reset_new_password_page.dart — 상호작용 7, 버그 5 (H1/M1/L3)
- [x] password_reset_request_page.dart — 상호작용 3, 버그 4 (H1/M1/L2)
- [x] password_reset_verification_page.dart — 상호작용 5, 버그 5 (H1/M2/L2)
- [x] register_page.dart — 상호작용 2, 버그 4 (H1/M2/L1) **DEAD CODE**
- [x] terms_agreement_page.dart — 상호작용 10, 버그 5 (H1/M2/L2)
- [x] terms_detail_page.dart — 상호작용 2, 버그 4 (M1/L3)

### Phase 2 — onboarding (0/9)
- [ ] splash_page.dart
- [ ] onboarding_page.dart
- [ ] onboarding_slides_page.dart
- [ ] onboarding_login_page.dart
- [ ] onboarding_email_verification_page.dart
- [ ] onboarding_profile_setup_page.dart
- [ ] onboarding_pet_registration_page.dart
- [ ] onboarding_tutorial_page.dart
- [ ] onboarding_complete_page.dart

### Phase 3 — home (0/1)
- [ ] hospital_search_page.dart

### Phase 4 — health (0/2)
- [ ] health_main_page.dart
- [ ] health_alert_settings_page.dart

### Phase 5 — emotion (0/12)
- [ ] analysis_guide_page.dart
- [ ] emotion_analysis_page.dart
- [ ] emotion_loading_page.dart
- [ ] emotion_result_loader_page.dart
- [ ] emotion_result_page.dart
- [ ] emotion_history_page.dart
- [ ] emotion_calendar_page.dart
- [ ] emotion_trend_page.dart
- [ ] weekly_report_page.dart
- [ ] ai_history_page.dart
- [ ] health_loading_page.dart
- [ ] health_result_page.dart

### Phase 6 — feed_hub (0/2)
- [ ] feed_hub_page.dart
- [ ] create_community_post_page.dart

### Phase 7 — social (0/13)
- [ ] home_page.dart
- [ ] feed_page.dart
- [ ] social_feed_page.dart
- [ ] explore_page.dart
- [ ] search_page.dart
- [ ] create_post_page.dart
- [ ] post_detail_page.dart
- [ ] comments_page.dart
- [ ] notifications_page.dart
- [ ] followers_page.dart
- [ ] profile_page.dart
- [ ] channel_subscription_page.dart
- [ ] location_picker_page.dart

### Phase 8 — my (0/6)
- [ ] my_page.dart
- [ ] my_posts_page.dart
- [ ] my_saved_posts_page.dart
- [ ] my_emotion_history_page.dart
- [ ] my_settings_page.dart
- [ ] reward_store_page.dart

### Phase 9 — profile (0/7)
- [ ] profile_page.dart
- [ ] profile_edit_page.dart
- [ ] settings_page.dart
- [ ] notification_settings_page.dart
- [ ] privacy_settings_page.dart
- [ ] privacy_policy_page.dart
- [ ] help_page.dart

### Phase 10 — pets (0/3)
- [ ] pet_management_page.dart
- [ ] pet_detail_page.dart
- [ ] public_pet_page.dart

### Phase 11 — chat (0/4)
- [ ] chat_rooms_page.dart
- [ ] chat_detail_page.dart
- [ ] create_chat_page.dart
- [ ] chat_room_settings_page.dart

---

## 버그 발견 현황

- 🔴 Critical: 0
- 🟠 High: 10 (Pre-audit 2 + Phase 1 8)
- 🟡 Medium: 12 (Pre-audit 1 + Phase 1 11)
- 🟢 Low: 14
- **합계: 36건**

상세 내역: [BUG_LOG.md](./BUG_LOG.md)

---

## Phase 1 요약 리포트

**auth feature 전수 감사 결과 (8/8 완료):**

| 페이지 | 상호작용 | 버그 | 종합 |
|--------|--------|------|------|
| kakao_consent_page | 6 | 5 | ⚠️ 구 앱명 + 미구현 링크 |
| login_page | 8 | 3 | ❌ **DEAD CODE** (삭제 권장) |
| password_reset_new_password_page | 7 | 5 | ⚠️ Supabase 직접호출 |
| password_reset_request_page | 3 | 4 | ⚠️ Supabase 직접호출 |
| password_reset_verification_page | 5 | 5 | ⚠️ Supabase 3건 + FocusNode 리크 |
| register_page | 2 | 4 | ❌ **DEAD CODE** (삭제 권장) |
| terms_agreement_page | 10 | 5 | ⚠️ 뒤로가기 signOut 누락 |
| terms_detail_page | 2 | 4 | ⚠️ GoRouter 미사용 |
| **합계** | **43** | **35** | — |

**핵심 발견:**
- 🔥 **Dead code 2개 발견** — login_page.dart, register_page.dart (총 417줄 잠재 삭제)
- 🔥 **Supabase 직접 호출 패턴 4건** — AuthRepository에 `sendOtp`, `verifyOtp`, `updateUserPassword`, `signOut` 메서드 추가 필요
- 🔥 **라우팅 불일치 1건** (login_page의 `/password-reset-request` — dead code라 실제 영향 없음)
- 🟡 **iOS Safe Area / Scroll Physics 미흡 다수** — 일괄 개선 가능
- 🟡 **약관 하드코딩** — CMS/원격 로딩 검토 필요

---

*마지막 업데이트: 2026-04-22 Phase 1 완료*
