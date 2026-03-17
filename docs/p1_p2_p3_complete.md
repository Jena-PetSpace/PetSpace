# PetSpace 코드 개선 작업 완료 (P1~P3)

> 기준일: 2026-03-17  
> 커밋 범위: `95a7f52` → `d42a23a`

---

## P1 — 앱 안정성 직결 ✅ 완료

| 항목 | 내용 | 커밋 |
|------|------|------|
| 댓글 알림 미발송 | CommentBloc에 PushNotificationService 연결 | `95a7f52` |
| 팔로우 알림 미발송 | ProfileBloc follow 성공 시 sendFollowNotification | `95a7f52` |
| 차단 사용자 피드 필터링 | getFeedPosts에 user_blocks JOIN + 제외 쿼리 | `95a7f52` |
| 커뮤니티 포스트 글쓰기 | CreateCommunityPostPage 신규 + FAB 연결 | `95a7f52` |

### 주요 변경 상세

**댓글 알림** (`comment_bloc.dart`)
```dart
// 댓글 생성 성공 시 게시글 작성자에게 발송 (자기 자신 제외)
if (event.postAuthorId != null && event.postAuthorId != _currentUserId) {
  _pushService.sendCommentNotification(
    toUserId: event.postAuthorId!,
    fromUserId: _currentUserId,
    fromUserName: event.senderName ?? '사용자',
    postId: event.postId,
    commentPreview: event.content,
  );
}
```

**차단 사용자 피드 필터** (`social_remote_data_source_post.dart`)
```dart
// user_blocks 테이블에서 차단 목록 조회 후 피드에서 제외
final blockedIds = await supabaseClient
    .from('user_blocks').select('blocked_id').eq('blocker_id', userId);
query = query.not('author_id', 'in', '(${blockedIds...})');
```

---

## P2 — UX 완성 ✅ 완료

| 항목 | 내용 | 커밋 |
|------|------|------|
| 게시글 상세 페이지 개선 | 댓글만 → 게시글 본문+이미지+댓글 통합 | `234ba12` |
| 검색 기능 진입 경로 | FeedHubPage AppBar 검색 버튼 추가 | `234ba12` |
| 프로필 편집 후 캐시 갱신 | push<bool> 반환값으로 ProfileBloc 재요청 | `234ba12` |
| 댓글 Realtime 업데이트 | CommentBloc subscribeToPostComments 연결 | `d42a23a` |
| 팔로우 알림 이름 전달 | FollowUserRequested에 followerName(AuthBloc 읽기) | `d42a23a` |
| CI secrets.dart 누락 | test job에 더미 파일 생성 단계 추가 | `234ba12` |

### PostDetailPage 개선 요약
- Before: 댓글 목록만 표시, 게시글 내용 없음
- After: `CustomScrollView` + `SliverList` 구조
  - 상단: 작성자 프로필 / 이미지 / 본문 / 좋아요·댓글 수
  - 하단: 댓글 헤더 / 댓글 목록 (무한스크롤)
  - 하단 고정: 댓글 입력 + 전송 버튼

### 댓글 Realtime 구조
```
PostDetailPage 진입
    → CommentBloc(LoadComments)
    → _subscribeToRealtime(postId)
        → RealtimeService.subscribeToPostComments(postId)
        → commentStream.listen → insert/delete → LoadComments 재요청
    → close() → _commentSub?.cancel()
```

---

## P3 — 품질/최적화 ✅ 완료

| 항목 | 내용 | 커밋 |
|------|------|------|
| FeedBloc 테스트 | 12케이스 (피드로드/좋아요/북마크/새로고침) | `d42a23a` |
| 이미지 캐시 크기 제한 | imageCache 200개 / 50MB 명시 | `d42a23a` |

### 누적 테스트 현황

| 파일 | 케이스 |
|------|------|
| `auth_bloc_test.dart` | 11 |
| `emotion_analysis_bloc_test.dart` | 11 |
| `health_usecases_test.dart` | 9 |
| `bookmark_usecases_test.dart` | 8 |
| `feed_bloc_test.dart` | 12 |
| **합계** | **51케이스** |

---

## CI 이메일 알림 이슈 해결

**원인**: `secrets.dart`가 `.gitignore`에 포함되어 레포에 없는데, CI의
`Analyze & Test` job에 더미 파일 생성 단계가 없어 `flutter analyze` 실패.

**수정**: `.github/workflows/ci.yml` test job에 `secrets.dart` 생성 단계 추가.

```yaml
- name: secrets.dart 생성 (CI용 더미)
  working-directory: pjh
  run: |
    mkdir -p lib/config
    cat > lib/config/secrets.dart << 'EOF'
    const String supabaseUrl = '';
    ...
    EOF
```

---

## 잔여 작업

### 즉시 가능 (Claude)

| 우선순위 | 항목 |
|--------|------|
| P3 | 다크모드 색상 완성 |
| P3 | 접근성 (Semantics) 주요 화면 적용 |

### 정현이 직접 필요

| 항목 |
|------|
| Supabase SQL 실행 (`petspace_setup.sql`) |
| Edge Function Secret 등록 (`FCM_SERVER_KEY`) |
| AndroidManifest `POST_NOTIFICATIONS` + FCM 서비스 등록 |
| 릴리즈 서명 키 생성 → `key.properties` 작성 |
| Google Play Console 계정 ($25) |
