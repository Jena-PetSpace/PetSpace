# PetSpace 전수 페이지 감사 진행률

**시작일:** 2026-04-22
**브랜치:** mac-ios-release
**목표:** 67개 페이지의 모든 상호작용 요소를 코드 기반으로 카탈로그화 → 실제 검증 → 버그 기록

---

## 전체 진행률

- **총 페이지 수:** 69개 (win 머지로 emotion +1, social +2)
- **완료:** 69개
- **진행률:** **100% ✅**

---

## Feature별 진행

- [x] **auth (8/8) ✅**
- [x] **onboarding (9/9) ✅**
- [x] **home (1/1) ✅**
- [x] **health (2/2) ✅**
- [x] **emotion (13/13) ✅** (timeline 추가)
- [x] **feed_hub (2/2) ✅**
- [x] **social (15/15) ✅** (hashtag, location_posts 추가)
- [x] **my (6/6) ✅**
- [x] **profile (7/7) ✅**
- [x] **pets (3/3) ✅**
- [x] **chat (4/4) ✅**

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

### Phase 2 — onboarding (9/9) ✅
- [x] splash_page.dart — 상호작용 4(자동), 버그 4 (M1/L3)
- [x] onboarding_page.dart — 상호작용 1, 버그 3 (M1/L2)
- [x] onboarding_slides_page.dart — 상호작용 4, 버그 4 (M2/L2)
- [x] onboarding_login_page.dart — 상호작용 9, 버그 3 (L3)
- [x] onboarding_email_verification_page.dart — 상호작용 5, 버그 6 (H2/M2/L2)
- [x] onboarding_profile_setup_page.dart — 상호작용 5, 버그 6 (M3/L3)
- [x] onboarding_pet_registration_page.dart — 상호작용 12, 버그 9 (**C1**/H2/M3/L3)
- [x] onboarding_tutorial_page.dart — 상호작용 5, 버그 4 (H1/M1/L2)
- [x] onboarding_complete_page.dart — 상호작용 2, 버그 5 (M3/L2)

### Phase 3 — home (1/1) ✅
- [x] hospital_search_page.dart — 상호작용 21, 버그 13 (**C1**/H3/M6/L3)

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

- 🔴 Critical: **2** (Phase 2 pet_registration 경쟁조건, Phase 3 북마크 유실)
- 🟠 High: 41
- 🟡 Medium: 141
- 🟢 Low: 69
- **합계: 253건**

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

**Phase 1 핵심 발견:**
- 🔥 **Dead code 2개 발견** — login_page.dart, register_page.dart (총 417줄 잠재 삭제)
- 🔥 **Supabase 직접 호출 패턴 4건**
- 🔥 **라우팅 불일치 1건** (dead code라 실제 영향 없음)
- 🟡 iOS Safe Area / Scroll Physics 미흡 다수

---

## Phase 2 요약 리포트

**onboarding feature 전수 감사 결과 (9/9 완료):**

| 페이지 | 상호작용 | 버그 | 종합 |
|--------|--------|------|------|
| splash_page | 4(자동) | 4 | ⚠️ 하단 Safe Area |
| onboarding_page | 1 | 3 | ⚠️ 작은 화면 |
| onboarding_slides_page | 4 | 4 | ⚠️ 잠재 미사용 |
| onboarding_login_page | 9 | 3 | ✅ 실제 사용 — 버그 적음 |
| onboarding_email_verification_page | 5 | 6 | ⚠️ Supabase 직접 + 뒤로가기 signOut 누락 |
| onboarding_profile_setup_page | 5 | 6 | ⚠️ ProfileService 직접 주입 |
| onboarding_pet_registration_page | 12 | 9 | 🔴 **Critical 경쟁조건** |
| onboarding_tutorial_page | 5 | 4 | ⚠️ 진입 경로 없음 |
| onboarding_complete_page | 2 | 5 | ⚠️ stream timeout 없음 |
| **합계** | **47** | **44** | — |

**Phase 2 핵심 발견:**
- 🔴 **Critical 1건 발견** — pet_registration의 `AddPetEvent + Future.delayed(500ms)` 경쟁조건
- 🟠 **잠재 미사용 페이지 2개** — slides_page, tutorial_page (진입 경로 없음)
- 🟠 **Supabase 직접 호출 3건** (email_verification 내) — Phase 1 패턴 반복
- 🟠 **뒤로가기 signOut 누락** — email_verification
- 🟡 **ProfileService/PetBloc 주입 경로 불일치** — OnboardingBloc 도입 권장
- 🟡 **iOS 작은 화면 overflow** 다수 (onboarding_page, complete_page)

---

*마지막 업데이트: 2026-04-23 Phase 2 완료*

---

## Phase 3 요약 리포트

**home feature 전수 감사 결과 (1/1 완료):**

| 페이지 | 상호작용 | 버그 | 종합 |
|--------|--------|------|------|
| hospital_search_page | 21 | 13 | 🔴 **Critical** (북마크 유실) |

**Phase 3 핵심 발견:**
- 🔴 **Critical 1건** — `_favoriteIds` 로컬 Set만 사용 → 앱 재시작 시 북마크 전부 유실. "내 장소" 탭도 무의미
- 🟠 **High 3건** — 내 장소 필터 미구현, 권한 영구 거부 설정앱 이동 없음, API 실패 안내 없음
- 🟡 **Medium 6건** — 대부분 에러/타임아웃 UX, mapController dispose, pagination 등
- 🟢 **Low 3건** — Physics, 아이콘 포맷

**1448 LOC 단일 StatefulWidget**로 복잡도 극상. 향후 **HospitalSearchBloc** 분리 권장.

iOS 호환성은 양호:
- kakao_maps_flutter 로컬 패키지 iOS 구현 있음 ✅
- Info.plist 위치 권한 이미 설정됨 ✅
- 시뮬레이터 테스트 시 위치 수동 설정 필요

---

*마지막 업데이트: 2026-04-23 Phase 3 완료*
