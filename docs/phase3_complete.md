# Phase 3 완료 — 기능 완성

> 완료일: 2026-03-17  
> 커밋: (phase3 커밋 SHA)  
> 변경 파일: 15개 (신규 5 / 수정 10)

---

## 작업 요약

| # | 항목 | 결과 |
|---|------|------|
| 3-1 | 북마크 시스템 전체 구현 | ✅ 완료 |
| 3-2 | 알림 네비게이션 | ✅ 기존 완성 확인 |
| 3-3 | Realtime 배선 (좋아요·댓글) | ✅ 완료 |
| 3-4 | 멀티이미지 뷰어 | ✅ 완료 |

---

## 3-1. 북마크 시스템

### 아키텍처 흐름

```
Supabase (saved_posts 테이블)
  ↑↓
SocialRepositoryImpl  →  SocialRepository (인터페이스)
  ↑
SavePost / UnsavePost / GetSavedPosts (UseCase)
  ↑
FeedBloc (SavePostRequested / UnsavePostRequested / LoadSavedPostsRequested)
  ↑
MySavedPostsPage → /my/saved 라우트
  ↑
MyMenuList '저장한 글' onTap
```

### 신규 파일

| 파일 | 설명 |
|------|------|
| `social/domain/usecases/save_post.dart` | `SavePostParams(postId, userId)` |
| `social/domain/usecases/unsave_post.dart` | `UnsavePostParams(postId, userId)` |
| `social/domain/usecases/get_saved_posts.dart` | `GetSavedPostsParams(userId, limit)` |
| `my/presentation/pages/my_saved_posts_page.dart` | 저장한 글 목록 화면 |

### 수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `social/domain/repositories/social_repository.dart` | `savePost / unsavePost / getSavedPosts / isPostSaved` 4개 추가 |
| `social/data/repositories/social_repository_impl.dart` | Supabase `saved_posts` 테이블 CRUD 구현 |
| `social/presentation/bloc/feed_event.dart` | `SavePostRequested / UnsavePostRequested / LoadSavedPostsRequested` 추가 |
| `social/presentation/bloc/feed_state.dart` | `FeedSavedPostsLoaded / FeedPostSaved / FeedPostUnsaved` 추가 |
| `social/presentation/bloc/feed_bloc.dart` | 핸들러 3개 + UseCase 필드 추가 |
| `config/injection_container.dart` | UseCase 3개 등록 + FeedBloc 파라미터 업데이트 |
| `core/navigation/app_router.dart` | `/my/saved` 라우트 추가 |
| `my/presentation/widgets/my_menu_list.dart` | `저장한 글` onTap → `context.push('/my/saved')` |

### Supabase saved_posts 테이블 스키마 (적용 필요)

```sql
CREATE TABLE IF NOT EXISTS saved_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- RLS
ALTER TABLE saved_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own saved posts" ON saved_posts
  FOR ALL USING (auth.uid() = user_id);
```

### MySavedPostsPage 동작

- `initState` → `LoadSavedPostsRequested` dispatch
- `FeedSavedPostsLoaded` 상태 → `_SavedPostCard` 리스트 렌더링
- 북마크 아이콘 탭 → `UnsavePostRequested` dispatch → `_load()` 재호출 (낙관적 갱신)
- 빈 목록 시 안내 문구 표시

---

## 3-2. 알림 네비게이션 (기존 완성 확인)

`social/presentation/pages/notifications_page.dart`의 `_navigateToContent()` 이미 완성.

| 알림 타입 | 이동 경로 |
|----------|----------|
| like, comment, mention, postShare | `/post/:postId` |
| follow, friendRequest | `/user-profile/:userId` |
| emotionAnalysis | `/emotion/history` |

---

## 3-3. Realtime 배선

### 변경 파일

| 파일 | 변경 내용 |
|------|----------|
| `social/presentation/bloc/feed_bloc.dart` | `RealtimeService` 필드 추가, `subscribeRealtime()` 메서드, 핸들러 2개 |
| `social/presentation/bloc/feed_event.dart` | `RealtimeLikeReceived / RealtimeCommentReceived` 이벤트 추가 |
| `main.dart` | `AuthAuthenticated` 시 `feedBloc.subscribeRealtime(userId)` 호출 |

### 동작 흐름

```
AuthAuthenticated (main.dart BlocListener)
  → FeedBloc.subscribeRealtime(userId)
      → RealtimeService.subscribeToNotifications(userId)  // 기존
      → RealtimeService.likeStream.listen → RealtimeLikeReceived
      → RealtimeService.commentStream.listen → RealtimeCommentReceived
          → FeedLoaded.posts에서 postId 매칭 → likesCount / commentsCount 업데이트
```

### 핸들러 로직

```dart
// 좋아요 실시간 반영
_onRealtimeLikeReceived:
  delta = event == 'insert' ? +1 : -1
  posts.map(p.id == postId → p.copyWith(likesCount: current + delta))

// 댓글 실시간 반영
_onRealtimeCommentReceived:
  delta = event == 'insert' ? +1 : -1
  posts.map(p.id == postId → p.copyWith(commentsCount: current + delta))
```

---

## 3-4. 멀티이미지 뷰어

### 신규 파일

**`shared/widgets/image_viewer_page.dart`**

- `InteractiveViewer` — 핀치줌 (0.8x ~ 5.0x)
- `PageView.builder` — 좌우 스와이프 멀티이미지
- 탭 → 컨트롤 토글 (상단 닫기 버튼 + 페이지 인덱스 + 하단 dot)
- 진입 시 `SystemUiMode.immersive` (상태바 숨김), 종료 시 복원
- 로딩 → 흰색 CircularProgressIndicator, 에러 → broken_image 아이콘

### PostCard 변경 (`social/presentation/widgets/post_card.dart`)

- `import image_viewer_page.dart` 추가
- 단일 이미지: `GestureDetector.onTap → _openViewer(context, 0)`
- 멀티 이미지: 각 PageView 슬라이드에 `GestureDetector.onTap → _openViewer(context, index)`
- `_openViewer()`: `MaterialPageRoute(fullscreenDialog: true)` 로 `ImageViewerPage` push

---

## 다음: Phase 4

| 항목 | 파일 | 예상 공수 |
|------|------|----------|
| `emotion_result_page` 위젯 분리 | `emotion_result_page.dart` (2,161줄) | 8h |
| BLoC 단위 테스트 | `AuthBloc`, `EmotionAnalysisBloc` | 6h |
| GitHub Actions CI/CD | `.github/workflows/ci.yml` | 4h |

---

## Supabase 적용 체크리스트

Phase 3 완료 후 Supabase 대시보드에서 아래를 직접 적용해야 합니다.

- [ ] `saved_posts` 테이블 생성 (위 SQL 참조)
- [ ] `saved_posts` RLS 정책 활성화
- [ ] Realtime Publication에 `likes`, `comments` 테이블 추가  
  (Supabase Dashboard → Database → Replication → `supabase_realtime` publication)
