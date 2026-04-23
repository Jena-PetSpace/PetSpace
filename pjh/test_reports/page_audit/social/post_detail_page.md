# post_detail_page.dart

**LOC:** 737 | BLoC: FeedBloc, CommentBloc | **Supabase 직접 호출 8건**

## 🎯 상호작용 (5+)
- 좋아요, 북마크, 공유, 댓글 작성, 댓글 좋아요, 대댓글, 삭제/수정, 더보기 메뉴

## 🐛 이슈
| # | 심각도 | 요약 |
|---|-------|------|
| 1 | 🟠 High | **Supabase 직접 호출 8건** — 최다. 아키텍처 위반 심각 |
| 2 | 🟡 Medium | 737 LOC 단일 페이지 |
| 3 | 🟡 Medium | 대댓글 시스템 (win 머지 추가) — parent_id 처리 검증 필요 |
| 4 | 🟡 Medium | Realtime 구독 dispose 확인 필요 |
| 5 | 🟢 Low | BouncingScrollPhysics |

**평가:** 정상 | 버그 5 (H1/M3/L1) — **가장 큰 아키텍처 위반**
