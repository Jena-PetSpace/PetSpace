# Phase 6-8 Track B 분할 PR 계획

**작성일:** 2026-04-24
**목적:** Supabase 직접 호출 제거 리팩토링을 PR 단위로 분할해 회귀 리스크 최소화

---

## 원칙

1. **1 PR = 1 ~ 2 파일** (리뷰 가능한 크기)
2. **한 번에 기능 변경 + 리팩토링 금지** — 구조 이전만 수행
3. **각 PR 완료 후 Android + iOS 양쪽 회귀 테스트**
4. **Supabase Realtime 구독 / RPC 호출 / Storage upload는 주의** — 단순 SELECT/INSERT/UPDATE/DELETE부터 이전
5. **`Supabase.instance.client.auth.currentUser?.id`는 즉시 치환 대상 아님** — AuthBloc 활용으로 점진 교체

---

## PR 목록 (우선순위 순)

### Priority 1 — 사용 빈도 최상 (Phase 6)

| PR# | 파일 | 예상 건수 | 예상 시간 | 의존 Repository |
|-----|------|---------|---------|---------------|
| PR-01 | `social/post_detail_page.dart` | 8건 | 1h | PostRepository, PostLikeRepository |
| PR-02 | `pets/public_pet_page.dart` | 7건 | 1h | PetRepository, FollowRepository |
| PR-03 | `chat/chat_room_settings_page.dart` | 8건 | 1.5h | ChatRepository |

**마일스톤**: Phase 6 완료 시 소셜 핵심 3개 페이지 아키텍처 정상화.

---

### Priority 2 — 자주 진입 페이지 (Phase 7)

| PR# | 파일 | 예상 건수 | 예상 시간 | 의존 Repository |
|-----|------|---------|---------|---------------|
| PR-04 | `social/profile_page.dart` | 6건 | 1h | ProfileRepository, FollowRepository |
| PR-05 | `chat/chat_detail_page.dart` | 5건 | 1h | ChatRepository (Realtime 주의) |
| PR-06 | `social/widgets/post_card.dart` | 3건 | 45m | 부모 Page에서 props로 전달 권장 |
| PR-07 | `chat/chat_rooms_page.dart` + `create_chat_page.dart` | 4건 | 1h | ChatRepository |

**마일스톤**: Phase 7 완료 시 채팅/소셜 피드 전체 아키텍처 정상화.

---

### Priority 3 — 보조 페이지 (Phase 8)

| PR# | 파일 | 예상 건수 | 예상 시간 | 비고 |
|-----|------|---------|---------|------|
| PR-08 | `auth/password_reset_*_page.dart` (3개) | 6건 | 1.5h | AuthRepository 확장 필요 |
| PR-09 | `onboarding/onboarding_email_verification_page.dart` | 3건 | 45m | AuthRepository |
| PR-10 | `emotion/ai_history_page.dart` | 2건 (RPC 포함) | 1h | EmotionRepository + HealthRepository |
| PR-11 | `emotion/health_result_page.dart` | 1건 (Storage) | 45m | ImageUploadService |
| PR-12 | `feed_hub/feed_hub_page.dart` + `create_community_post_page.dart` | 2건 | 45m | FeedRepository |
| PR-13 | `my/my_page.dart` + `widgets/user_badges_section.dart` | 5건 | 1h | UserRepository, BadgeRepository |
| PR-14 | `home/widgets/home_quest_card.dart` | 2건 | 45m | QuestRepository (신규) |
| PR-15 | `social/explore_page.dart` + `search_page.dart` + `create_post_page.dart` + `widgets/user_posts_list.dart` + `bloc/search_bloc.dart` | 5건 | 1.5h | FeedRepository 확장 |
| PR-16 | `pets/widgets/add_pet_bottom_sheet.dart` | 1건 | 30m | PetRepository |

**마일스톤**: Phase 8 완료 시 `grep "Supabase.instance.client" pjh/lib/features --include="*.dart" | grep -v "data/datasources"` 결과 ≈ 0.

---

## PR 작업 표준 절차 (per PR)

```bash
# 1. 브랜치 생성
git checkout mac-ios-release
git pull
git checkout -b refactor/track-b-pr-XX-<filename>

# 2. 해당 파일의 Supabase 호출 전수 추출
grep -nE "Supabase\.instance\.client\.(from|rpc|storage|auth)" <file>

# 3. Repository 인터페이스 확인
# - 부족한 메서드가 있다면 추가
# - Data / Remote DataSource까지 따라서 수정

# 4. 페이지 호출 부분 교체
# - context.read<XxxBloc>().add(...) 또는
# - sl<XxxRepository>().method().fold(...)

# 5. 검증
flutter analyze lib/features/<feature>
flutter build ios --simulator  # 해당 화면 확인

# 6. 커밋 & 푸시
git add -A
git commit -m "refactor(<feature>): <file> Supabase 직접 호출 → Repository"
git push -u origin refactor/track-b-pr-XX-<filename>

# 7. GitHub PR 생성
gh pr create --base mac-ios-release --title "..." --body "..."
```

---

## 리팩토링 가이드라인

### ✅ 단순 이전 (쉬움)
```dart
// Before
final data = await Supabase.instance.client
  .from('posts').select().eq('id', postId).single();

// After
final result = await sl<PostRepository>().getPostDetail(postId);
result.fold(
  (failure) => _showError(failure),
  (post) => setState(() => _post = post),
);
```

### ⚠️ Realtime 구독 (신중)
```dart
// Before — page 내부에서 channel 관리
final channel = Supabase.instance.client.channel('room_$id')
  .onPostgresChanges(...)
  .subscribe();

// After — Repository에서 Stream 반환
_subscription = sl<ChatRepository>()
  .subscribeMessages(roomId)
  .listen((message) => _addMessage(message));

// dispose에서 cancel
```

### 🚫 즉시 이전 비권장 (별도 세션)
- 복잡한 RPC 호출 (emotion 분석 타임라인 등)
- Storage 업로드 + 변환 로직
- 트랜잭션성 작업 (여러 테이블 INSERT)

---

## Repository 확장 필요 목록 (예측)

| Repository | 신규 메서드 | PR |
|------------|----------|-----|
| PostRepository | `getPostDetail`, `deletePost`, `updatePost`, `reportPost` | PR-01 |
| PetRepository | `getPublicPetProfile`, `getPetFollowers` | PR-02 |
| ChatRepository | `updateRoomSettings`, `leaveRoom`, `addMembers`, `setNotification` | PR-03, PR-05, PR-07 |
| ProfileRepository | `blockUser` (BlockService 연동), `reportUser` | PR-04 |
| AuthRepository | `sendPasswordResetOtp`, `verifyPasswordResetOtp`, `updatePassword` | PR-08 |
| EmotionRepository | `getHealthByAreaRpc` | PR-10 |
| FeedRepository | `getCommunityPosts`, `searchPosts` | PR-12, PR-15 |
| QuestRepository | **신규 작성 필요** | PR-14 |
| BadgeRepository | **신규 작성 필요** | PR-13 |

---

## 체크리스트 (완료 시 체크)

### Phase 6 (Priority 1)
- [ ] PR-01: post_detail_page
- [ ] PR-02: public_pet_page
- [ ] PR-03: chat_room_settings_page

### Phase 7 (Priority 2)
- [ ] PR-04: social/profile_page
- [ ] PR-05: chat_detail_page (Realtime)
- [ ] PR-06: post_card widget
- [ ] PR-07: chat_rooms + create_chat

### Phase 8 (Priority 3)
- [ ] PR-08: password_reset trio
- [ ] PR-09: onboarding_email_verification
- [ ] PR-10: ai_history (RPC)
- [ ] PR-11: health_result (Storage)
- [ ] PR-12: feed_hub
- [ ] PR-13: my_page + user_badges
- [ ] PR-14: home_quest_card
- [ ] PR-15: social extras (explore/search/create_post/bloc)
- [ ] PR-16: add_pet_bottom_sheet

### Phase 9 (최종 검증)
- [ ] grep count = 0
- [ ] flutter analyze 0 errors
- [ ] flutter build apk --release 성공
- [ ] flutter build ios --release 성공
- [ ] Android 핵심 시나리오 5개 수동 검증
- [ ] iOS 시뮬레이터 동일 시나리오
- [ ] test_reports/release_readiness.md 작성

---

## 예상 소요

| Phase | 파일 수 | 예상 시간 |
|-------|--------|---------|
| Phase 6 (PR 1-3) | 3 | 3.5h |
| Phase 7 (PR 4-7) | 5 | 3.75h |
| Phase 8 (PR 8-16) | 18 | 8.75h |
| Phase 9 (검증) | - | 1.5h |
| **합계** | **26 파일** | **~17.5h** |

→ 주당 5-6h 배정 시 **3주** 소요 예상.

---

*PetSpace Track B 리팩토링 계획 | 2026-04-24*
