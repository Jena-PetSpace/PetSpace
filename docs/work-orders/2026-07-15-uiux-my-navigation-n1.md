# 작업지시서 초안: MY-N1 — 소셜 탐색과 게시물 상호작용 신뢰도

- 작성일: 2026-07-15
- 상태: Codex·Claude Opus 4.8 기획 합의 완료, blocker/high 0, exact manifest 사용자 구현 승인 대기
- 상위 기획: `docs/reviews/2026-07-14-my-navigation-wave2-plan.md`
- 승인 목업: 팔로워·팔로잉 목록, 타인 프로필, 게시물 상세
- 구현 방식: N1A와 N1B를 순차 실행하고 각 단위별 자동 검증·독립 리뷰 후 다음 단위로 이동
- 구현 초안 담당: Codex
- 독립 검토: Claude Opus 4.8
- commit·merge·push·deploy·운영 DB 작업: 금지

## 1. 목표

MY에서 시작하는 `팔로워/팔로잉 → 타인 프로필 → 게시물 상세` 여정을 신뢰 가능한 하나의 흐름으로 만든다.

1. 수십·수백 명의 팔로워·팔로잉에서도 이름 또는 사용자 아이디로 서버 검색하고 계속 불러올 수 있게 한다.
2. 타인 프로필의 정보 위계와 오류·빈 상태를 정돈하고 정본 팔로워/팔로잉 화면으로 연결한다.
3. 게시물 상세의 좋아요 수와 댓글 총계를 일관되게 표시한다.
4. 댓글과 1단계 답글의 작성·삭제·좋아요·실패 복구가 화면 상태와 실제 데이터에 맞게 동작하도록 한다.
5. 하단 5탭, 홈, AI 분석, 운영 DB 및 법무 계약은 변경하지 않는다.

## 2. 실행 단위 분리

### N1A — 팔로워 검색·타인 프로필

- 화면 2개: 팔로워/팔로잉 목록, 타인 프로필
- 핵심 위험: 50명 제한 로컬 검색, 불안정한 페이지네이션, profile posts error→empty 혼합
- N1A 자동 검증과 Codex·Claude 리뷰가 끝나기 전 N1B 코드를 수정하지 않는다.

### N1B — 게시물 상세 상호작용 정합성

- 화면 1개: 게시물 상세과 그 안의 댓글·답글 상태
- 핵심 위험: 좋아요 연속 탭 경합, 댓글 총계 불일치, 답글 삭제·좋아요 UI 미반영, 실패 시 입력 손실
- N1A와 파일이 겹치지 않는 독립 manifest를 사용한다.

두 단위를 나눈 이유는 화면 수가 아니라 데이터 계약의 복잡도다. 사용자 승인 시 두 manifest를 함께 승인할 수 있지만 구현·검증·리뷰는 N1A → N1B 순서로 각각 닫는다.

## 3. 확인된 사실

### 3.1 팔로워·프로필

- `FollowersPage`는 팔로워와 팔로잉을 각각 한 번만 조회하며 검색과 추가 페이지 조회가 없다.
- `SocialRepositoryImpl.getFollowers/getFollowing`은 remote source를 `limit 50, cursor null`로 고정 호출한다. 따라서 현재 목록에 로컬 필터만 추가하면 51번째 이후 사용자를 찾지 못한다.
- remote source는 `users.display_name`, `username`, `photo_url`을 이미 조회하지만 Repository가 `Follow`로 변환할 때 username을 버린다.
- remote source의 `lastUserId` 인자는 현재 쿼리에 적용되지 않는다.
- `UserPostsList`는 최초 조회 실패를 기록만 하고 empty UI와 구분하지 않는다. 추가 조회 실패도 이미 보이는 목록 옆에 재시도 상태를 제공하지 않는다.
- 타인 프로필은 내부 TabBarView에서 팔로워/팔로잉을 다시 조회해 정본 `FollowersPage`와 중복된다.

### 3.2 게시물 좋아요

- `PostDetailPage`는 서버 `posts.likes_count`를 초기값으로 사용한다.
- 현재 좋아요는 300ms Timer 기반 optimistic toggle이며 이미 시작된 비동기 요청과 다음 탭을 직렬화하지 않는다. 느린 네트워크에서 오래된 rollback이 최신 화면 상태를 덮을 수 있다.
- 실패 시 사용자 안내가 없고, 감소 시 0 미만 방어가 없다.
- canonical schema인 `supabase/petspace_setup.sql`은 `likes` INSERT/DELETE 트리거가 `posts.likes_count`를 갱신하고 `increment_post_likes/decrement_post_likes` RPC는 호환용 0-op이라고 명시한다.
- 위 트리거/RPC 정의는 현재 개별 migration 파일에는 없으므로 운영 DB와 canonical schema의 일치 여부는 이 UI 작업만으로 증명하지 않는다.

### 3.3 댓글 총계

- canonical schema의 comments INSERT/DELETE 트리거는 `parent_id`와 관계없이 `posts.comments_count`를 증감한다. 즉 게시물의 댓글 수는 최상위 댓글과 답글을 모두 포함하는 참여 총계다.
- canonical schema의 `comments.parent_id`는 `REFERENCES comments(id) ON DELETE CASCADE`다(`supabase/petspace_setup.sql:112-121`). 따라서 답글이 있는 최상위 댓글을 삭제하면 부모와 자식 각 행의 DELETE trigger가 실행되어 총계가 `1 + 답글 수`만큼 감소한다. 운영 DB가 이 canonical 정의와 다르다는 증거가 있으면 UI에서 추정하지 않고 중단한다.
- 게시물 액션 행은 `posts.comments_count`를 표시하지만 댓글 헤더는 `state.comments.length`를 사용한다. 후자는 현재 불러온 최상위 댓글 수일 뿐이라 첫 20개, 다음 20개 로드에 따라 숫자가 바뀌고 답글을 제외한다.
- 댓글/답글 작성·삭제 후 게시물 액션 행의 정적 `comments_count`가 즉시 갱신되지 않는다.

### 3.4 댓글·답글 상태

- 댓글은 최상위 20개 단위로 불러오지만 각 최상위 댓글마다 답글을 별도 조회해 N+1 쿼리가 발생한다.
- 최상위 커서는 `created_at < lastCreatedAt`만 사용해 동일 시각 행의 누락·중복 가능성이 있다.
- 각 댓글의 `is_liked_by_current_user`를 읽는 모델 필드는 있으나 현재 comments select가 로그인 사용자의 `comment_likes`를 계산해 넣지 않는다.
- 답글 삭제 event는 전송되지만 BLoC는 최상위 목록에서 같은 id만 제거해 중첩 답글을 즉시 제거하지 못한다.
- 답글 좋아요도 API는 호출하지만 optimistic update가 최상위 댓글만 순회해 화면에 반영되지 않는다.
- 댓글 작성 성공 시 기존 `hasMore`가 기본값으로 되돌아갈 수 있다.
- 추가 조회와 답글 작성 실패는 `CommentLoaded.error`에 담기지만 `PostDetailPage` listener는 `CommentError`만 처리한다.
- 댓글/답글 전송 시 입력과 답글 대상이 성공 전에 지워져 실패 후 재시도할 내용을 잃는다.
- 댓글 상세 라우트 `/post/:postId`는 `ShellRoute` 밖 fullscreen이다. 따라서 하단 중앙 발바닥 회피가 아니라 키보드·시스템 SafeArea가 이 화면의 실제 하단 제약이다.

## 4. N1A 요구사항

### 4.1 팔로워·팔로잉 검색과 페이지네이션

1. 상단 segmented tab 아래에 `이름 또는 사용자 아이디 검색` 입력을 둔다.
2. 검색어는 trim하고 `@` 접두사는 검색 비교에서 제거한다. display name과 username을 대소문자 비구분으로 서버 검색한다.
3. 300ms debounce와 요청 generation/token을 사용해 오래된 응답이 최신 검색 결과를 덮지 못하게 한다.
4. 검색어는 탭 전환 후에도 유지하되 팔로워와 팔로잉의 목록·cursor·loading/error 상태는 독립 관리한다.
5. 기본 조회와 검색 조회 모두 20명 단위 서버 페이지네이션을 사용한다.
6. 현재 사용되지 않는 `lastUserId`는 관계의 마지막 사용자 id로 실제 적용한다. remote source는 해당 관계 행의 `(created_at, id)`를 조회해 `created_at DESC, id DESC` keyset 조건을 적용한다. 동률 tie-breaker 없이 timestamp만 비교하는 구현은 금지한다.
7. embedded users 검색은 inner relation/filter를 사용해 관계 밖 사용자가 섞이지 않게 한다. 새 RPC나 DB migration은 만들지 않는다.
8. `Follow`에 팔로워/팔로잉 username 전달 필드를 추가하고 remote → repository → presentation에서 보존한다. 기존 필드는 소스 호환을 유지한다.
9. 관계 목록 empty와 검색 결과 empty를 다른 문구로 표시한다.
10. 추가 조회 실패는 이미 표시한 행을 지우지 않고 inline 재시도를 제공한다.
11. raw exception을 사용자에게 노출하지 않는다.

### 4.2 사용자 행과 타인 프로필

1. 사용자 행 전체와 주요 액션은 최소 44px 터치 영역을 보장한다.
2. 프로필 사진이 없으면 표시 이름 첫 글자를 사용한다. pet용 paw fallback과 혼용하지 않는다.
3. 실제 username이 있을 때만 `@username`을 표시한다.
4. 타인 프로필의 큰 gradient hero를 표준 top bar + compact identity로 정돈한다.
5. 실제 display name, username, bio만 표시하며 값이 없으면 임의 대체 문구를 만들지 않는다.
6. 게시글·팔로워·팔로잉 통계 탭은 정본 FollowersPage로 이동한다. 기존 inline follow TabBarView는 제거한다.
   - `ProfileStatsCard`에 게시물·팔로워·팔로잉별 optional callback과 44px semantics를 추가한다.
   - 팔로워는 `initialTab=0`, 팔로잉은 `initialTab=1` 의미의 기존 route로 이동한다. 카드 전체를 하나의 GestureDetector로 감싸 세 구역을 구분하지 못하는 구현은 금지한다.
7. 본인 `isMyProfile` 분기의 cover 편집, 프로필 편집, 설정, 본인 pet switcher는 회귀시키지 않는다.
8. 타인 분기의 pet switcher와 감정 timeline 진입은 공개 정책이 확정되지 않았으므로 숨긴다.
9. 팔로우/팔로우 중은 같은 위치에서 상태만 바뀌고 요청 중 중복 제출을 막는다. 실패 시 이전 상태를 복구하고 안전한 안내를 표시한다.
10. 메시지 동선은 기존 route 의미를 유지한다.
11. `UserPostsList`는 loading, success-empty, success-populated, first-load error/retry, load-more error/retry를 구분한다.
12. 이미지 없는 게시물은 임의 원색 한 글자 블록 대신 중립적인 텍스트 미리보기로 표시한다.

## 5. N1A 정확한 manifest

- 경로 목록 SHA-256: `9be6d69f38bd18769af24ea5b91e3870673e200bd3dbfa65b25572f0da37b0d2`

### 수정 10개

1. `pjh/lib/features/social/presentation/pages/followers_page.dart`
   - 기준 SHA-256: `9545ec285bc6ec85aa5f73284519fbe6da98a040b1eac0c1ff926c3c83a0eaaa`
2. `pjh/lib/features/social/presentation/pages/profile_page.dart`
   - 기준 SHA-256: `1480448d8d321b6ed9fa78dbee5648939b4578484692184a1a6aefbba9a964d0`
3. `pjh/lib/features/social/presentation/widgets/user_posts_list.dart`
   - 기준 SHA-256: `b576f7620edf4330ab5a31d0e52df8d146b5093f674b935748e0308b16c453ee`
4. `pjh/lib/features/social/presentation/widgets/user_list_tile.dart`
   - 기준 SHA-256: `36fe398f19e0ab6e527f85dd2e293676c30aab08828b7aa0cec47406aed693b5`
5. `pjh/lib/features/social/data/datasources/social_remote_data_source.dart`
   - 기준 SHA-256: `50309948b0dc319d0765765c54c56c26e053c0da03e59aa3e2f281df8b499868`
6. `pjh/lib/features/social/data/datasources/social_remote_data_source_impl_follow.dart`
   - 기준 SHA-256: `7c0eb58220f5315269780b9e775c518f4b825ae4eff1f200933261b610d72c76`
7. `pjh/lib/features/social/domain/repositories/social_repository.dart`
   - 기준 SHA-256: `729f1ccdeabe81ddafc2d36ae69e41d51d31a8e368cf8f1c38e2896a9ce315cb`
8. `pjh/lib/features/social/data/repositories/social_repository_impl.dart`
   - 기준 SHA-256: `8250b017ff82d01e57271fe35e782bdc6be20a878a2ad2fbb276d784148666de`
9. `pjh/lib/features/social/domain/entities/follow.dart`
   - 기준 SHA-256: `5f7fd225d33ae6e0e78cd51fc8b18e1fc73930c1fdc72da581cedf4634da4efd`
10. `pjh/lib/features/social/presentation/widgets/profile_stats_card.dart`
   - 기준 SHA-256: `2672fdc37e72bacde53a249819ce82860cd7ac16f86c78d7b55117f9d86b925b`

### 생성 6개

11. `pjh/test/features/social/presentation/pages/followers_page_test.dart`
12. `pjh/test/features/social/presentation/pages/profile_page_test.dart`
13. `pjh/test/features/social/presentation/widgets/user_posts_list_test.dart`
14. `pjh/test/features/social/presentation/widgets/user_list_tile_test.dart`
15. `pjh/test/features/social/presentation/widgets/profile_stats_card_test.dart`
16. `pjh/test/features/social/data/repositories/social_repository_impl_follow_test.dart`

## 6. N1B 요구사항

### 6.1 게시물 로드와 좋아요

1. 게시물 최초 loading, error/retry, not-found를 구분한다. 실패나 null 응답에서 빈 화면을 렌더하지 않는다.
2. 좋아요는 요청 단위 잠금으로 직렬화한다. 요청 중 같은 버튼을 다시 눌러 중복 mutation을 만들지 않는다.
3. optimistic update는 가능하지만 실패 시 해당 요청의 이전 `isLiked/likesCount`만 복구한다. 오래된 rollback이 이후 상태를 덮지 않아야 한다.
4. 좋아요 수는 0 미만으로 내려가지 않는다.
5. 실패 안내는 내부 예외 없이 floating SnackBar 또는 동등한 비차단 안내를 사용한다.
6. 좋아요 버튼은 semantics와 최소 44px 터치 영역을 제공한다.
7. 이번 manifest는 likes data source와 RPC 호출을 수정하지 않는다. canonical schema의 호환 RPC는 0-op이고 실제 count는 trigger가 담당한다. 운영 DB trigger/RPC가 canonical과 다르다는 증거가 있으면 N1B를 멈추고 별도 DB 승인으로 분리한다.
8. 좋아요 mutation 성공 뒤 기존 `getPostDetail()`과 `isPostLiked()`로 count/icon을 재조정한다. 재조정 실패 시 성공한 optimistic 상태를 유지하고 내부 오류를 노출하지 않는다.

### 6.2 댓글 총계의 단일 기준

1. 게시물 액션 행과 댓글 섹션 헤더는 같은 `totalCount`를 표시한다.
2. `totalCount`는 서버 `posts.comments_count`로 초기화하고 최상위 댓글과 답글을 모두 포함한다.
3. 댓글 또는 답글 생성 성공 시 +1 한다.
4. 답글 삭제 성공 시 -1 한다.
5. 최상위 댓글 삭제 성공 시 해당 댓글과 현재 데이터 계약상 함께 삭제되는 1단계 답글 수를 합산해 감소시킨다. 0 미만으로 내려가지 않는다.
6. mutation 실패 시 totalCount를 바꾸지 않는다.
7. 페이지네이션으로 최상위 댓글을 더 불러와도 totalCount는 loaded length로 교체하지 않는다.

### 6.3 댓글·답글 상태와 네트워크

1. `CommentLoaded`는 loaded threads, totalCount, hasMore, load-more 상태, 전송 상태, pending like ids, 일회성 action outcome을 명시적으로 보존한다.
2. 최초 댓글 조회 실패는 안전한 error/retry를 표시한다.
3. 추가 조회 실패는 기존 threads를 유지하고 inline retry를 표시한다.
4. 댓글/답글 전송 중 중복 제출을 막는다.
5. 입력과 답글 대상은 성공 후에만 지운다. 실패하면 내용과 대상, 키보드 재시도 가능 상태를 보존한다.
6. 댓글 생성 성공은 기존 `hasMore`와 이미 불러온 페이지를 보존한다.
7. 답글 생성·삭제·좋아요는 중첩 reply list를 재귀 또는 명시적 helper로 갱신한다.
8. 댓글/답글 좋아요 요청은 대상 id별로 직렬화하고 실패 시 그 대상만 rollback한다.
9. 로그인 사용자의 `comment_likes`를 현재 페이지의 댓글·답글 ids에 대해 한 번에 조회해 `isLikedByCurrentUser`를 채운다.
10. 현재 페이지의 모든 답글은 최상위 댓글마다 개별 요청하지 않고 parent ids 묶음으로 조회한다.
11. 최상위 페이지 cursor는 `created_at DESC, id DESC` tie-breaker를 사용한다.
12. 답글은 1단계만 작성한다. 답글에 다시 답글을 달아 2단계 이상 깊이를 새로 만들지 않는다.
13. 답글은 처음 2개만 펼쳐 보이고 `답글 N개 더 보기/접기`로 나머지를 제어한다. 이는 표시 제어이며 새 DB count를 만들지 않는다.
14. realtime 삭제 때문에 전체 페이지가 갑자기 첫 20개로 초기화되지 않게 한다. 이번 사용자 mutation은 optimistic/confirmed 상태로 닫고, 외부 realtime 동기화의 범위 확대가 필요하면 별도 기능 부채로 기록한다.
15. 댓글/답글 생성·삭제는 임시 id를 넣는 optimistic mutation을 강제하지 않는다. 서버 응답을 기다리는 동안 대상 action을 pending 처리하고, 성공 후 목록·totalCount를 바꾸며 실패 시 기존 목록과 입력을 보존하는 server-confirmed 방식을 정본으로 한다.
16. 댓글 totalCount는 기존 `getPostDetail()` 응답의 `comments_count`로만 초기화·재조정한다. N1B는 `social_remote_data_source.dart`에 새 메서드나 시그니처를 추가하지 않는다.
17. 댓글/답글 mutation 성공 후 local delta를 적용하고 기존 `getPostDetail()`로 totalCount를 재동기화한다. 재동기화 실패 시 성공한 mutation의 local delta를 유지하되 raw error를 노출하지 않는다.
18. external realtime insert/delete는 짧게 debounce해 현재 로드한 최상위 개수 범위에서 목록을 재조정하고 기존 loaded page와 totalCount를 갑자기 초기화하지 않는다. 재조정 실패 시 현재 목록을 유지한다.
19. `getPostDetail()` 반환의 `comments_count: int` 키는 N1A와 N1B 모두의 불변 계약이다. N1A의 follow/search 시그니처 작업은 post detail 반환 shape를 변경하지 않는다.
20. 이번 N1B에서 현재 페이지의 parent ids를 묶어 replies를 batch 조회하는 것은 필수다. 후속으로 미루는 것은 thread별 서버 pagination과 reply_count/preview 신규 DB 계약뿐이다.

### 6.4 게시물 상세 UI

1. route가 fullscreen인 현재 계약을 유지하고 하단 5탭을 이 화면에 새로 넣지 않는다.
2. top bar, 작성자, 본문/미디어, 감정 분석 요약, 참여 수, 댓글 목록, 입력 순서로 정돈한다.
3. confidence와 진단 표현을 새로 노출하지 않는다.
4. 댓글 작성자 사진 없음은 표시 이름 첫 글자를 사용하고 pet paw fallback과 구분한다.
5. 키보드 viewInsets, system SafeArea, 150% text scale에서 입력창과 전송 버튼을 사용할 수 있어야 한다.
6. 삭제는 댓글과 답글 모두 확인 후 실행하고, 실패 시 항목을 유지한다.
7. 신고·차단·운영 메뉴를 새로 만들지 않는다.

## 7. N1B 정확한 manifest

- 경로 목록 SHA-256: `3bd8cb00d242426ab0447b55c1c393c2bcc3bcf7b9455ede360bd52a21b46b13`

### 수정 6개

1. `pjh/lib/features/social/presentation/pages/post_detail_page.dart`
   - 기준 SHA-256: `48fee7d4bfcb1ce115ddfd884148eabaa454ba908170f170e02a2f7883c77dac`
2. `pjh/lib/features/social/presentation/bloc/comment_bloc.dart`
   - 기준 SHA-256: `9c6736b3838c992fbbc9d35cb3fd5cfa70ed20727091b9f8da117a5b3259a0d0`
3. `pjh/lib/features/social/presentation/bloc/comment_event.dart`
   - 기준 SHA-256: `b99efe2763648cdf295cfa9c86bad9a0009f655d1b5ae444fb14a05f03485612`
4. `pjh/lib/features/social/presentation/bloc/comment_state.dart`
   - 기준 SHA-256: `ea1bf9970f7df0e1294564271eed8ab7b5843c75f57f17f25b00ac94dc7b2c37`
5. `pjh/lib/features/social/presentation/widgets/comment_list_item.dart`
   - 기준 SHA-256: `86b9c6c5f6638464de586eced93c8a3608403676c7312de67752a30290a03482`
6. `pjh/lib/features/social/data/datasources/social_remote_data_source_impl_comment.dart`
   - 기준 SHA-256: `a281bff437064621171ee9ec877fa536d5fc86fc66e4df90a06d93e893b94d6b`

### 생성 3개

7. `pjh/test/features/social/presentation/pages/post_detail_page_test.dart`
8. `pjh/test/features/social/presentation/bloc/comment_bloc_test.dart`
9. `pjh/test/features/social/presentation/widgets/comment_list_item_test.dart`

## 8. 명시적 범위 제외

- 하단 5탭의 구조·중앙 버튼·아이콘·라벨·색·배지
- `main_navigation.dart`, `app_router.dart`
- 홈 화면, AI 분석 화면, emotion presentation
- 신고·차단·moderation 메뉴와 운영 SLA
- 팔로우 추천, 정렬, 연락처 동기화
- 댓글 2단계 이상 nesting
- 답글 서버 pagination과 reply_count 신규 DB 필드/RPC
- 운영 DB 조회·수정, migration, RLS, Edge Function
- 댓글/좋아요 기존 count의 운영 데이터 일괄 보정
- `social_remote_data_source_impl_like.dart`와 likes RPC/trigger 정리
- commit, merge, push, deploy

답글 수가 매우 큰 thread의 서버 pagination은 현재 schema에 reply_count/preview 계약이 없어 source-only로 완결하지 않는다. 이번 N1B는 N+1을 batch 조회로 줄이고 표시를 접되, 운영 규모에서 별도 답글 pagination이 필요하면 DB/API 승인 wave로 분리한다.

## 9. 보호·불변 계약

- 직접 수정 금지:
  - `pjh/lib/features/social/presentation/pages/home_page.dart`
  - `pjh/lib/features/home/**`
  - `pjh/lib/features/emotion/presentation/**`
- `/followers/:uid`, `/following/:uid`, `/user-profile/:userId`, `/post/:postId`, `/chat/new` route 의미를 유지한다.
- 본인 프로필 분기와 현재 프로필 편집·설정 동선을 보존한다.
- post/comments/likes/comment_likes table 구조와 RLS를 변경하지 않는다.
- `getPostDetail()`의 `comments_count: int` 반환 키와 의미를 변경하지 않는다.
- 신규 임의 빨강, raw exception, confidence, 진단·치료 표현을 추가하지 않는다.
- 기준 hash가 달라지면 자동 덮어쓰지 않고 manifest를 재비준한다.

## 10. 자동 테스트 요구

### N1A

- followers/following: 첫 조회, 추가 조회, 정확히 page-size, 마지막 페이지, duplicate 방지
- 검색: display name, username, `@username`, 공백, debounce, stale response 무효화
- 탭별 독립 cursor/loading/error, 검색어 유지
- 관계 empty vs 검색 empty, first error/retry, load-more error/retry
- username 전달과 사진 없음 첫 글자 fallback
- 타인 profile compact identity, stats route, follow pending/success/failure rollback, message route
- 본인 profile 분기 기능 보존
- UserPostsList loading/empty/populated/first error/retry/load-more error/retry, 중립 text tile
- 360×800, 390×844, 150% text scale overflow 0

### N1B

- post loading/error/not-found/retry
- post like 성공/실패 rollback, 0 clamp, 빠른 연속 탭에서 mutation 1개
- action row와 댓글 header가 같은 totalCount를 사용
- top-level create +1, reply create +1, reply delete -1, parent+replies delete 정확한 감소, 실패 delta 0
- parent delete는 canonical `ON DELETE CASCADE`를 전제로 하고 mutation 성공 뒤 서버 totalCount 재동기화
- exact page-size hasMore, load more success, load more failure 기존 목록 유지
- create failure 입력·reply target 유지, 성공 후에만 clear
- reply create/delete/like가 nested list에 즉시 반영
- comment/reply like 대상별 pending, 실패 시 대상만 rollback
- 로그인 사용자 liked ids mapping
- 현재 페이지 parent ids batch replies 조회로 top-level별 N+1 제거
- 답글 2개 preview, 더 보기/접기, 삭제 확인
- 키보드 viewInsets·SafeArea·150% text scale overflow 0
- raw failure 문자열 비노출

## 11. 검증 명령과 게이트

각 실행 단위에서 아래를 따로 수행한다.

```powershell
dart format --output=none --set-exit-if-changed <해당 manifest source/test>
flutter analyze --no-pub
flutter test --no-pub <해당 신규 테스트>
flutter test --no-pub
git diff --check
```

추가 검증:

1. manifest 밖 app/test 변경 0
2. 하단 5탭·router·home·emotion 보호 hash 불변
3. 기존 전체 테스트 실패와 신규 실패 분리
4. Codex diff 리뷰와 Claude Opus 4.8 독립 diff 리뷰 각각 blocker/high 0
5. N1A 승인 완료 전 N1B source 변경 0

## 12. 사람 실기기 검증

### N1A

- 팔로워/팔로잉 0명, 1명, 20명 초과, 50명 초과 계정
- 한글 display name, 영문 username, `@` 검색, 빠른 입력 후 결과 역전 없음
- 느린 네트워크에서 추가 조회 실패 후 retry
- 타인 profile 팔로우 왕복, 메시지 왕복, sparse/empty/posts error
- 본인 profile 기능이 그대로인지 확인

### N1B

- 좋아요 연속 탭, 느린 네트워크, 실패 후 count와 icon 복구
- 다른 화면에서 본 count와 상세 진입 count 일치
- 댓글/답글 작성 성공·실패, 입력 보존, 중복 전송 방지
- 댓글과 답글 각각 좋아요·취소·삭제
- 답글이 여러 개인 최상위 댓글 삭제 후 참여 총계
- 댓글 헤더 수는 `답글 포함 전체 댓글 수`라는 제품 의미로 QA한다.
- 댓글 20개 초과 추가 조회와 동일 시각 데이터의 누락·중복 여부
- 키보드 열림, 작은 Android, 100%·150% 글자, TalkBack 읽기 순서

운영 DB의 trigger/RPC 정의와 기존 count drift는 이 실기기 검증만으로 확정하지 않는다. 실제 count가 한 번의 mutation에 2 이상 변하거나 갱신되지 않으면 자동 수정하지 말고 DB 계약 검증 단계로 중단한다.

## 13. 중단 조건

- embedded relation search가 현재 Supabase/PostgREST 버전에서 안정적 keyset과 함께 구현되지 않음
- 운영 DB의 likes/comments trigger가 canonical schema와 다르다는 증거가 발견됨
- 댓글 총계의 제품 의미를 최상위 thread 수로 바꿔야 한다는 요구가 생김
- 답글 서버 pagination을 위해 schema/RPC 변경이 필요함
- manifest 밖 router, DB, DI 전역 구조 변경이 필요함
- 보호 파일 hash 변경 또는 blocker/high 판정

## 14. Claude Opus 4.8 검토 질문

1. N1A 16파일과 N1B 9파일 manifest가 각 목표에 필요충분하고 서로 독립적인가?
2. 50명 제한 로컬 검색을 피하는 서버 검색·keyset 계약이 현재 source/API 안에서 DB 변경 없이 구현 가능한가?
3. `posts.comments_count = 최상위 댓글 + 답글`을 단일 totalCount로 쓰는 계획이 trigger와 UI 의미에 맞는가?
4. 댓글/답글 생성·삭제·좋아요의 nested update와 실패 복구 계획에 누락된 경합이 있는가?
5. likes data source/RPC를 이번 manifest에서 수정하지 않고 UI 직렬화와 실기기 +1 검증으로 제한한 경계가 충분한가?
6. blocker/high 수준의 회귀, 개인정보, 법무, 접근성, 테스트 공백 또는 범위 초과가 있는가?

## 15. 승인 게이트

1. Codex가 이 작업지시서와 기준 hash를 작성한다.
2. Claude Opus 4.8이 승인된 목업·상위 기획·위 source 범위를 read-only로 검토한다.
3. Claude findings를 문서에 반영하고 blocker/high 0, exact manifest 합의 여부를 기록한다.
4. 사용자에게 N1A 16파일과 N1B 9파일을 분리해 최종 보고한다.
5. 사용자가 exact manifest 구현을 승인하기 전 Flutter source/test를 수정하지 않는다.
6. 구현 승인 후에도 N1A → 검증·양쪽 리뷰 → N1B → 검증·양쪽 리뷰 순서를 지킨다.

## 16. Claude Opus 4.8 1차 검토와 반영

- 1차 판정: `changes_required`, blocker 0, high 1, medium 5, low 1
- high: 부모 댓글 삭제 시 답글 cascade와 `comments_count` 감소 근거가 제공된 schema 발췌에 없어 정합을 확정할 수 없음
  - 반영: canonical `comments.parent_id REFERENCES comments(id) ON DELETE CASCADE`(`petspace_setup.sql:117`)를 확인하고 부모+답글 DELETE trigger 동작, 운영 DB 불일치 중단 조건, mutation 후 서버 totalCount 재동기화를 명문화
- medium: 통계 구역별 route callback에 필요한 `profile_stats_card.dart`가 manifest에 없음
  - 반영: N1A 수정 1개와 테스트 1개를 추가해 총 16파일로 조정
- medium: N1A가 소유한 `social_remote_data_source.dart`와 N1B가 충돌할 수 있음
  - 반영: N1B는 기존 `getPostDetail.comments_count`만 사용하고 abstract data source 시그니처를 변경하지 않는다고 명문화
- medium: 댓글 생성 성공/실패에서 `CommentLoaded` 필드 손실 가능
  - 반영: 모든 mutation에서 `copyWith`로 loaded threads, totalCount, hasMore, pending, action outcome을 보존하도록 재강조
- medium: 임시 optimistic reply와 realtime dedupe 권고
  - 판단: 정확성과 입력 보존을 우선해 create/delete는 server-confirmed pending 방식으로 확정하고, external realtime은 debounce reconcile로 분리
- likes RPC: canonical trigger + 0-op 호환 RPC 계약은 정합하다는 검토 결과를 반영해 data source 수정 자체를 manifest에서 제외
- 2차 검토 기준: 위 반영으로 blocker/high 0, N1A 16파일·N1B 9파일 exact manifest 합의가 성립해야 사용자 구현 승인 단계로 이동한다.

## 17. Claude Opus 4.8 2차 검토 결과

- 최종 판정: `approve`
- blocker/high: 0
- manifest: N1A 수정 10 + 생성 6 = 16파일, N1B 수정 6 + 생성 3 = 9파일, 경로·개수 일치
- count contract: canonical `ON DELETE CASCADE`, 행별 count trigger, local delta, 기존 `getPostDetail.comments_count` 재동기화 조합 정합
- likes boundary: data source/RPC/trigger 무수정, UI 요청 직렬화와 성공 후 서버 재조정, 실기기 단일 +1 검증 정합
- medium 1건 반영: N1A가 `social_remote_data_source.dart`를 수정하더라도 `getPostDetail.comments_count:int` 반환 계약은 변경하지 않도록 불변 조건 추가
- low 처리:
  1. current-page reply batch 조회는 이번 필수임을 재명시하고, server reply pagination만 후속으로 유지
  2. 댓글 수는 답글 포함 전체 참여 수라는 의미를 QA에 명시
- 구현 게이트: 사용자 exact manifest 승인 전 Flutter source/test 수정 금지
