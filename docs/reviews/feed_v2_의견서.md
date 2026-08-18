# 피드탭 개선기획서 v2.0 — 사전 발견사항 보고 (의견서)

- 작성일: 2026-07-08
- 작성 주체: Claude Code (구현 담당, §8 협업 프로토콜 1단계)
- 실측 기준: 로컬 `win-android-release` HEAD `31e3392` (기획서는 원격 HEAD 기준 — 로컬 미푸시 커밋 포함 상태에서 전량 재실측)
- 태그 규약: **[일치]** 기획서 서술 = 로컬 실측 / **[불일치-실측]** 다름(실측 제시) / **[미확인]** 로컬에서 검증 불가 / **[반대의견]** 기획 자체에 이견

## 총평

기획서 §3.1의 코드 근거는 **10건 중 7건 일치, 3건 부분 불일치**(O-2 영향 과소평가, O-5 죽은 위젯 포함, O-7 전제 사실과 다름). 기획의 큰 방향(2탭 재편, 카테고리 재정의, 채널 비노출)에는 반대하지 않는다. 다만 **카테고리 하드코딩 소스가 기획서가 짚은 2곳이 아니라 4곳**이고, **`tab=following` 딥링크는 재편 이전인 지금도 이미 동작하지 않으며**, **신규 category 값 4종 도입 시 DB에 3세대 값이 공존**하게 되는 문제가 있어 §5(반대의견·대안)에서 다룬다.

---

## 1. (a) §3.1 O-1~O-10 실측 재확인

### O-1. 라우터 딥링크 계약 — [일치] + 추가 발견

- 실측: [app_router.dart:274-286](pjh/lib/core/navigation/app_router.dart#L274-L286)
  ```dart
  path: '/feed',
  ...
  if (tab == 'following') initialTab = 1;
  if (tab == 'community') initialTab = 2;
  return FeedHubPage(initialTab: initialTab, initialCategory: category);
  ```
  기획서의 라인(275~)·계약 서술과 일치.
- **추가 발견(기획서 미기재)**: FeedHubPage의 initState는 `widget.initialTab >= 2`만 처리한다([feed_hub_page.dart:84-96](pjh/lib/features/feed_hub/presentation/pages/feed_hub_page.dart#L84-L96)). `_photoTabController`는 항상 index 0으로 생성되므로 **`tab=following`(initialTab=1)은 지금도 팔로잉 하위탭을 선택하지 못하고 '추천' 탭으로 열린다.** 즉 following 딥링크의 구간 호환 매핑은 "기존 동작 보존"이 아니라 "원래부터 깨져 있던 것의 목적지 재정의"다. 매핑 자체는 유지하되, 회귀 기준을 "추천 탭 진입"으로 잡으면 된다.

### O-2. 홈 category_filter_chips 하드코딩 — [일치] 단, 영향 범위 과소평가

- 실측: [category_filter_chips.dart:18-26](pjh/lib/features/home/presentation/widgets/category_filter_chips.dart#L18-L26) — `'피드 Q&A 항목과 동일한 카테고리 체계'` 주석과 6종(전체/O/X 퀴즈/케어가이드/교육/정책/이벤트) 하드코딩. 기획서 서술 일치.
- **[불일치-실측] 이 칩은 독립 위젯이 아니라 홈의 콘텐츠 스위처다.** 사용처는 홈 탭 [home_page.dart:160](pjh/lib/features/social/presentation/pages/home_page.dart#L160)이고, 선택 인덱스가 [home_page.dart:232-247](pjh/lib/features/social/presentation/pages/home_page.dart#L232-L247)의 switch로 넘어가 `CommunityPreview(category: 'quiz'|'careguide'|'education'|'policy'|'event')` 또는 `MagazineGrid`를 렌더한다. 쿼리를 쏘는 곳은 [community_preview.dart](pjh/lib/features/home/presentation/widgets/community_preview.dart)다. 따라서 O-2의 실제 변경 세트는 **칩 1개 파일이 아니라 3개 파일(chips + home_page switch + CommunityPreview 카테고리 값)**이며, 인덱스 기반 결합이라 칩 목록만 바꾸면 조용히 어긋난다.
- **추가 발견 — 하드코딩 소스는 총 4곳**: ① 위 칩 ② [feed_hub_page.dart:56-63](pjh/lib/features/feed_hub/presentation/pages/feed_hub_page.dart#L56-L63) `_qnaCategories` ③ 작성 화면 [create_community_post_page.dart:27-34](pjh/lib/features/feed_hub/presentation/pages/create_community_post_page.dart#L27-L34) ④ 라벨 매핑 [community_post.dart:63-89](pjh/lib/features/feed_hub/domain/entities/community_post.dart#L63-L89). 기획서 P0-3 "shared 단일 소스화" [동의]하되 대상을 4곳으로 확대해야 한다.
- **추가 발견 — 기존 데이터 불일치 버그**: 작성 화면 기본값은 `'qa'`([create_community_post_page.dart:25](pjh/lib/features/feed_hub/presentation/pages/create_community_post_page.dart#L25))인데 피드 필터 목록에는 `qa`가 없다(②의 값: quiz/careguide/education/policy/event). **기본값으로 저장된 글은 '전체'에서만 보이고 어떤 카테고리 칩으로도 필터되지 않는다.** 재편 시 함께 청산할 것.

### O-3. hot_topic_banner 딥링크 — [일치]

- 실측: [hot_topic_banner.dart:140](pjh/lib/features/home/presentation/widgets/hot_topic_banner.dart#L140) `context.go('/feed?tab=community&category=$tag')`. 태그 네임스페이스는 [hot_topic_banner.dart:22-31](pjh/lib/features/home/presentation/widgets/hot_topic_banner.dart#L22-L31)의 health/training/food/life/magazine/walk/grooming/play — Q&A 카테고리 값과 전혀 다른 축이라 FeedHubPage 매칭 루프([feed_hub_page.dart:87-94](pjh/lib/features/feed_hub/presentation/pages/feed_hub_page.dart#L87-L94))에서 실패하고 '전체'로 폴백한다. 기획서의 "기존 잠재 버그" 진단 [일치].
- 해시태그면 hashtag_page로 보내자는 대안에 [동의]. `/hashtag/:tag` 라우트 실존([app_router.dart:471](pjh/lib/core/navigation/app_router.dart#L471))하고, 매거진 섹션도 이미 같은 패턴을 쓴다([magazine_section.dart:78](pjh/lib/features/feed_hub/presentation/widgets/magazine_section.dart#L78) `/hashtag/magazine`).
- 부가: 배너 상단 '더보기'([hot_topic_banner.dart:83](pjh/lib/features/home/presentation/widgets/hot_topic_banner.dart#L83) → `/feed`)도 같은 파일에 있으니 구간 5에서 함께 처리.

### O-4. social/home_page 진입점 — [일치] / 수정 금지 여부 — [불일치-실측: 현재 금지 아님]

- 실측: [home_page.dart:217](pjh/lib/features/social/presentation/pages/home_page.dart#L217) `context.go('/feed?tab=community&category=magazine')` — 매거진 '더보기'. 일치.
- 수정 금지: "절대 수정 금지 파일" 지정은 **아카이브된 스프린트 플랜 한정**이었다 — [2026-06-11-sprint1 플랜:17](docs/archive/plans/2026-06-11-sprint1-softdelete-tokens-cleanup.md#L17), [2026-06-13-sprint2 플랜:17](docs/archive/plans/2026-06-13-sprint2-previousanalysis-widget-split.md#L17). 그 이후 커밋 `66b888f`(홈 디자인 개선), `07aa5ba`(출시 준비) 등에서 이 파일은 이미 수차례 수정됐다(git log 실측). **현행 금지 문서 없음 → 수정 가능.** 단, 이 파일은 파일명과 달리 social이 아니라 **홈 탭 본체**(라우터 `/home`이 사용, [app_router.dart:267](pjh/lib/core/navigation/app_router.dart#L267))이므로 진입점 1줄 변경으로 국한할 것.
- **추가 발견**: `category=magazine`은 위 O-3과 같은 이유로 지금도 매칭 실패 → '전체' 폴백으로만 동작 중. 그리고 매거진 데이터는 category 컬럼이 아니라 **hashtag 'magazine' 기반**이다([magazine_section.dart:35-36](pjh/lib/features/feed_hub/presentation/widgets/magazine_section.dart#L35-L36) `searchPostsByHashtag(hashtag: 'magazine')`, 커뮤니티 쿼리에서는 명시 제외 — [social_remote_data_source_impl_post.dart:170-171](pjh/lib/features/social/data/datasources/social_remote_data_source_impl_post.dart#L170-L171)). P0-4는 위젯 이동 + 목적지 `?tab=lounge` 변경으로 충분하며 데이터 경로는 손댈 필요 없다.

### O-5. 알림·퀘스트·MY 라우팅 — [부분 불일치-실측]

| 지점 | 실측 | 판정 |
|---|---|---|
| [notifications_page.dart:65](pjh/lib/features/social/presentation/pages/notifications_page.dart#L65) | `onAction: () => context.go('/feed')`, 문구 '피드 탐색' | [일치] — 발견 탭 기본 진입으로 유효, 무변경 |
| [home_quest_card.dart:59,67](pjh/lib/features/home/presentation/widgets/home_quest_card.dart#L59) | route '/feed' 존재하나 **HomeQuestCard는 홈에서 렌더되지 않음** — import·사용처 주석 처리([home_page.dart:20-24](pjh/lib/features/social/presentation/pages/home_page.dart#L20-L24), [home_page.dart:262](pjh/lib/features/social/presentation/pages/home_page.dart#L262)), 다른 사용처 grep 0건 | **[불일치-실측] 죽은 위젯. P0 조치 대상에서 제외** (부활 시 재검토) |
| [my_posts_page.dart:379](pjh/lib/features/my/presentation/pages/my_posts_page.dart#L379) | '커뮤니티 가기' 버튼 → `/feed` | [일치] — 문구가 커뮤니티 지향이므로 `?tab=lounge`로 조정 대상 |
| [my_page.dart:317](pjh/lib/features/my/presentation/pages/my_page.dart#L317) | 저장글 빈 상태 '피드 탐색' → `/feed` | [일치] — 발견 기본 진입 유효, 무변경 |

### O-6. 하단 탭 하이라이트 — [일치]

- 실측: [main_navigation.dart:412](pjh/lib/main_navigation.dart#L412) `location.startsWith('/feed')`, 탭 정의 [main_navigation.dart:80](pjh/lib/main_navigation.dart#L80). 쿼리 파라미터와 무관한 path 매칭이라 무영향. 실기기 체크리스트 유지 [동의].

### O-7. MY 글·저장 글 카테고리 라벨 — [불일치-실측: 전제 자체가 사실과 다름]

- `categoryLabel` 사용처는 전 코드에서 2곳뿐: [feed_hub_page.dart:393](pjh/lib/features/feed_hub/presentation/pages/feed_hub_page.dart#L393)과 정의부 [community_post.dart:63](pjh/lib/features/feed_hub/domain/entities/community_post.dart#L63).
- MY 글 페이지의 커뮤니티 탭은 **데이터 조회 없이 무조건 빈 상태를 반환하는 스텁**이다([my_posts_page.dart:373-381](pjh/lib/features/my/presentation/pages/my_posts_page.dart#L373-L381)). my_saved_posts_page에는 카테고리 표기가 아예 없다(두 파일 `category` grep 0건).
- 결론: "MY에서 라벨이 동일 표기되는지" 리스크는 현재 존재하지 않는다. 라벨 shared 단일 소스화는 O-2에서 이미 필요하므로 수행하되, **O-7을 별도 P0 항목으로 유지할 필요는 없음.** 오히려 'MY 커뮤니티 글 탭 미구현'이 별도 부채로 기록될 사안이다.

### O-8. 검색 — [일치, 검증 완료]

- 피드 앱바 검색 → `context.push('/search')`([feed_hub_page.dart:194](pjh/lib/features/feed_hub/presentation/pages/feed_hub_page.dart#L194)). search_page는 해시태그·사용자 검색 전용으로 category 필터·표기가 전무하다([search_page.dart](pjh/lib/features/social/presentation/pages/search_page.dart) 내 category grep 0건, 전부 `SearchPostsByHashtagRequested`). **재편 무영향 — P0-V에서 스모크 확인만.**

### O-9. ChannelSubscriptionPage 진입점 전수 — [불일치-실측: 기획서는 "미검출"이라 했으나 2곳 실존]

전 코드 grep(`ChannelSubscription`, `'/channels'`) 결과, 진입점은 정확히 2곳:

1. **피드 앱바 tune 아이콘** → showModalBottomSheet로 직접 임베드 — [feed_hub_page.dart:168-186](pjh/lib/features/feed_hub/presentation/pages/feed_hub_page.dart#L168-L186) (tooltip '채널 구독')
2. **`/channels` 라우트** — [app_router.dart:139](pjh/lib/core/navigation/app_router.dart#L139). 단 이 라우트로 navigate하는 코드는 **0건**(데드 라우트).

P0-1은 ①의 IconButton 제거만으로 완결되며, ②와 [channel_subscription_page.dart](pjh/lib/features/social/presentation/pages/channel_subscription_page.dart)는 무변경 보존(기획 의도대로 P2 재도입 대비).

### O-10. quiz 진입점 — [일치]

- 홈 퀵액션 [home_quick_actions.dart:56](pjh/lib/features/home/presentation/widgets/home_quick_actions.dart#L56) `/quiz/play`, 라우트 [app_router.dart:535,541](pjh/lib/core/navigation/app_router.dart#L535). 홈 칩 index 1도 `CommunityPreview(category: 'quiz')`로 연결([home_page.dart:237](pjh/lib/features/social/presentation/pages/home_page.dart#L237)).
- 유의: **O/X 퀴즈 기능 자체는 로컬 콘텐츠 기반**(quiz_content_data_source, 커뮤니티 posts와 무관)이고, `category='quiz'`인 커뮤니티 글과는 별개 축이다. 라운지에서 quiz 카테고리를 없애도 `/quiz/play` 기능은 독립적으로 살아 있다 — 발견 C카드로 흡수한다는 방침 [동의].

---

## 2. (b) manual_sql/history/posts_category.sql 실체 — [일치 + 문서 스테일]

- **CHECK 제약 없음 [일치]**: [posts_category.sql:31](../../supabase/manual_sql/history/posts_category.sql#L31) `ALTER TABLE posts ADD COLUMN IF NOT EXISTS category TEXT` — nullable, default 없음, 제약 없음. 신 값 도입에 DDL 변경 불필요라는 기획서 결론 [일치].
- **백필 로직**: hashtags 배열 `@>` 매칭으로 구 5종(health/training/food/life/qa)만 조건부 UPDATE([:40-49](../../supabase/manual_sql/history/posts_category.sql#L40)), `WHERE category IS NULL` 멱등, magazine 명시 제외, 부분 인덱스 `idx_posts_category`.
- **[미확인]** 기획서의 "2918행": 로컬에서 라이브 DB 조회 불가. 파일 주석의 2026-06-15 실측은 "alive 글 6건"([:14](../../supabase/manual_sql/history/posts_category.sql#L14))이므로 2918은 그 이후 데이터이거나 deleted 포함 수치로 추정 — 웹 검토 시 근거 재확인 요망.
- **문서 스테일 (I-E 필요성 실증)**: SQL COMMENT([:33-35](../../supabase/manual_sql/history/posts_category.sql#L33-L35))와 entity 주석([community_post.dart:19](../../pjh/lib/features/feed_hub/domain/entities/community_post.dart#L19))은 구 5종만 기술하는데, `categoryLabel`은 이미 신 6종(qa/quiz/careguide/education/policy/event) + 구 4종 호환의 **2세대 체계**를 처리 중이다. 여기에 기획서의 chat/brag/question/info를 더하면 **3세대 값이 무제약 TEXT에 공존**한다 → §5-1 반대의견 참조.

## 3. (c) social/home_page.dart 수정 금지 현행 — §1 O-4에 통합 기술. 결론: **현재 금지 아님, 근거는 git log**

## 4. (d) ChannelSubscriptionPage 전수 목록 — §1 O-9에 통합 기술. 결론: **앱바 아이콘 1곳 + 데드 라우트 1곳**

---

## 5. [반대의견] 및 대안

### 5-1. 신규 category 값 4종 — 'question'과 기존 'qa'의 의미 중복

기획서 §2.3은 `chat/brag/question/info`를 신설하지만, DB에는 이미 '질문' 의미의 `qa`가 있고(작성 화면 기본값이라 실데이터에 가장 많을 값 — [create_community_post_page.dart:25](pjh/lib/features/feed_hub/presentation/pages/create_community_post_page.dart#L25)), categoryLabel에도 살아 있다. `question`을 신설하면 같은 의미의 값이 2개가 되고, 라운지 '궁금해요' 필터는 `qa` 글을 놓친다.

**대안(택1, 웹 검토 요청)**:
- (권장) 신 값은 `chat/brag/info` 3종만 신설하고 '궁금해요'는 **기존 `qa`를 재사용**. 값 증식 최소, 백필 불필요.
- 또는 `question` 신설 + 대시보드에서 `UPDATE posts SET category='question' WHERE category='qa'` 백필 1줄을 I-E 마이그레이션에 포함(구값 5종 → 매거진 흡수 쿼리와 함께).

어느 쪽이든 **구 6종(quiz/careguide/education/policy/event + health/training/food/life)의 라운지 '전체' 폴백 처리**는 클라이언트 필터가 아닌 "카테고리 미매칭 = 전체에만 노출"로 자연 처리 가능(쿼리는 `eq('category', ...)` 필터라 신 값 외는 자동 제외 — [social_remote_data_source_impl_post.dart:173](pjh/lib/features/social/data/datasources/social_remote_data_source_impl_post.dart#L173)).

### 5-2. §4.4 pill 그림자 제거 — 피드 단독 적용 반대

pill 토글은 "AI 분석 페이지와 동일한 pill-style"로 공유된 패턴이다([feed_hub_page.dart:208](pjh/lib/features/feed_hub/presentation/pages/feed_hub_page.dart#L208) 주석). 피드는 2탭 TabBar로 pill 자체가 사라지니 무관하지만, **pill 스타일 규칙(§4.4)을 피드 범위에서 선반영하면 AI 분석 페이지와 시각 불일치**가 생긴다. §9.5대로 AppTheme v2 전역 결정과 묶어서만 적용할 것.

### 5-3. §4.3 이모지 제거 — 파급 범위 결정 필요

`EmptyStateWidget`의 emoji/badgeEmoji는 shared 파라미터로 피드 밖에서도 쓰인다: [my_page.dart:309](pjh/lib/features/my/presentation/pages/my_page.dart#L309) '📸'/'🔖', [notifications_page.dart:61](pjh/lib/features/social/presentation/pages/notifications_page.dart#L61) '🔔' 등. 피드 사용처([feed_hub_page.dart:414-417](pjh/lib/features/feed_hub/presentation/pages/feed_hub_page.dart#L414-L417))만 제거할지 전역 제거할지 지시 필요. 참고로 건강관리는 이미 "이모지 전면 제거" 커밋(`ce862ea`)이 있어 **전역 제거가 기존 작업 방향과 일치**한다 — 단 전역은 피드 재편 스코프 밖이므로 별도 구간 권장.

### 5-4. O-5 홈 퀘스트 카드 — P0 목록에서 제거 제안

§1 O-5 실측대로 죽은 위젯이다. 작업지시서에서 빼고, 대신 "HomeQuestCard 부활 시 라우팅 재검토"를 인계 메모로만 남기는 것을 제안.

---

## 6. (e) 발견 탭 클라이언트 병합 — 페이지네이션 설계안

### 현황 실측

- FeedBloc는 **전역 싱글턴**([main.dart:286-287](pjh/lib/main.dart#L286-L287)) — 추천 피드는 **offset 커서**(`getRecommendedPosts(offset, limit)`, [feed_bloc.dart:390-421](pjh/lib/features/social/presentation/bloc/feed_bloc.dart#L390-L421), `FeedRecommendedLoaded`), 일반/팔로잉 피드는 **keyset 커서**(lastPostId+lastCreatedAt, [feed_bloc.dart:122-153](pjh/lib/features/social/presentation/bloc/feed_bloc.dart#L122-L153), `FeedLoaded`).
- 운영 콘텐츠(C카드 후보)는 현재 커서 없는 단발 조회: 매거진 5건 고정([magazine_section.dart:35-36](pjh/lib/features/feed_hub/presentation/widgets/magazine_section.dart#L35-L36)).
- **기존 구조 긴장**: 추천/팔로잉 두 FeedPage가 같은 FeedBloc 상태 슬롯을 공유해 탭 전환 시 `FeedRecommendedLoaded` ↔ `FeedLoaded`가 서로 덮어쓴다. 발견 단일 피드화(팔로잉 하위탭 제거)는 이 긴장을 **완화**하는 방향이라 재편과 시너지가 있다.

### 설계안 (P0-5)

1. **두 커서 독립 유지, 병합은 프레젠테이션 계층에서.** FeedBloc(추천 offset 커서)은 무변경. C카드는 신규 경량 `OperationalCardsCubit`(CommunityCubit 패턴 복제)이 keyset(`beforeCreatedAt`)으로 관리 — 소스는 `searchPostsByHashtag('magazine')` + 구 카테고리(careguide 등) 글.
2. **인터리브는 build 시 인덱스 계산으로만.** `itemBuilder`에서 `index % 5 == 4`(유저 4 : 운영 1)일 때 C카드 큐에서 꺼내 렌더. **FeedBloc의 posts 리스트에 C카드를 삽입하지 않는 것이 핵심** — 좋아요 낙관적 업데이트([feed_bloc.dart:187-245](pjh/lib/features/social/presentation/bloc/feed_bloc.dart#L187-L245))가 post.id 매칭으로 동작하므로 리스트 오염 시 회귀 위험.
3. **선로딩 규칙**: 유저 포스트 1페이지(20건)당 C카드 5건 필요 → C커서는 유저 피드 loadMore 트리거 시 잔여 큐가 5건 미만이면 함께 loadMore. 운영 콘텐츠 고갈 시 "있는 만큼만 끼워넣기"로 비율 자동 하향(§2.2 요구 충족).
4. **비율 상수**: P0는 위젯 상수(`static const int kOperationalInterval = 5`) — 기획서 I-F(P0 로컬 상수) [일치]. P1에서 app_settings 이관(테이블은 현재 **없음** — 전 레포 grep 0건, 신설 필요 [일치]).

## 7. (f) 딥링크 구값 호환 매핑 — 구현 위치: **라우터** 권장

[app_router.dart:277-285](pjh/lib/core/navigation/app_router.dart#L277-L285)의 `/feed` builder에서 문자열→탭 인덱스 정규화를 완결하는 안을 권장한다.

- 근거 ①: 매핑은 순수 문자열 변환으로 위젯 상태와 무관 — 현재도 변환은 라우터에 있다(관례 유지).
- 근거 ②: FeedHubPage는 이번에 크게 재작성되므로, 페이지 안에 흡수하면 리라이트마다 호환 로직이 흔들린다. 라우터에 두면 페이지는 "0=발견, 1=라운지"만 알면 된다.
- 근거 ③: **외부 표면이 실존한다** — AndroidManifest에 app links `https://petspace.app` + 커스텀 스킴 `com.petspace.app`([AndroidManifest.xml:54-67](pjh/android/app/src/main/AndroidManifest.xml#L54-L67)). 외부에서 어떤 구 URL이 오든 라우터 한 곳에서 정규화하는 편이 안전. (§9.3 관련: FCM 라우팅은 `/feed?tab`을 쓰지 않음 — [fcm_service.dart:41-57](pjh/lib/core/services/fcm_service.dart#L41-L57). 앱 내 구 파라미터 발신처는 home_page:217, hot_topic_banner:140 정확히 2곳이고 이번에 함께 갱신되므로, 매핑은 순수 하위호환 안전망이다.)

매핑 표:

| 입력 | 결과 |
|---|---|
| `tab=lounge` 또는 `tab=community` | 라운지(1) |
| `tab=following`, 그 외, 없음 | 발견(0) |
| `category=` 신 값 | 라운지 해당 칩 |
| `category=` 구 값(quiz/careguide/…/magazine/핫토픽 태그) | 라운지 '전체' 폴백 |

## 8. (g) P0 변경 파일·구간 분할(Option A)·커밋 계획

전 구간 공통: 커밋 전 `flutter analyze` 0 + `flutter test`(베이스라인 대비 신규 실패 0). push 없음(사용자 직접).

| 구간 | P0 | 변경 파일 | 커밋 메시지(안) |
|---|---|---|---|
| 1 | P0-1, O-1 매핑 | feed_hub_page.dart(tune 아이콘 제거), app_router.dart(/feed builder 정규화) | `feat(feed): 채널 진입점 비노출 + /feed 딥링크 신구 호환 매핑` |
| 2 | P0-2·P0-3·P0-6 | feed_hub_page.dart(2탭 재편·pill 제거·followingOnly 정리), **신규** shared 카테고리 단일 소스(값+라벨+칩 스타일), community_post.dart(categoryLabel 위임), community_cubit.dart, create_community_post_page.dart(신 카테고리) | `feat(feed): 발견/라운지 2탭 재편 + 카테고리 단일 소스화` |
| 3 | P0-4 | magazine_section.dart(라운지 '전체' 상단 배치·§4 스타일), home_page.dart:217(목적지 `?tab=lounge`) | `feat(feed): 매거진 섹션 라운지 이동 + 홈 진입점 갱신` |
| 4 | P0-5 | **신규** operational_cards_cubit.dart + 발견 탭 인터리브 위젯, feed_page.dart 또는 발견 전용 래퍼 | `feat(feed): 발견 탭 운영 콘텐츠 인터리브(4:1, 로컬 상수)` |
| 5 | P0-7 | category_filter_chips.dart + home_page.dart switch + community_preview.dart(신 카테고리 동기), hot_topic_banner.dart:83·140(목적지), my_posts_page.dart:379(`?tab=lounge`) | `feat(home): 홈 위젯 피드 재편 동기화` |
| 6 | I-E | supabase/migrations **신규 파일**(posts_category_v2.sql — 기존 파일은 이력 보존) + 코멘트·docs 갱신 | `docs(db): posts.category 신 카테고리 문서화 + 백필` |

- P0-8(I-G, 새 글 알림)은 supabase Edge Function/웹훅 영역 — `send-notification`·`send-push-notification` 함수 실존 확인(supabase/functions/), 재사용 가능 [일치]. 앱 코드와 독립이라 별도 구간(7)로 분리, 웹 검토에서 스펙 확정 후 진행.
- P0-9·P0-10은 운영/COO 항목으로 구현 범위 외.
- 구간 2가 최대 리스크(페이지 재작성) — 구간 1 커밋 후 착수, 구간 3~5는 2에 의존, 6은 독립.

## 9. (h) 기획과 충돌·기타 발견 전부

1. **`tab=following` 딥링크는 이미 부분 불능** — §1 O-1. 회귀 기준 재정의 필요.
2. **HomeQuestCard 죽은 위젯** — §1 O-5. P0 제외 제안.
3. **MY 커뮤니티 글 탭은 스텁** — §1 O-7. O-7 항목 자체가 무근거, 대신 미구현 부채로 기록.
4. **매거진은 hashtag 기반, category 아님** — §1 O-4. P0-4는 위젯 이동으로 충분.
5. **category 값 3세대 공존 위험 + qa/question 중복** — §5-1. 웹 검토 결정 필요(이번 의견서의 최우선 질의).
6. **작성 화면 기본값 'qa'가 어떤 필터에도 안 잡히는 기존 버그** — §1 O-2. 구간 2에서 청산.
7. **pill 스타일은 AI 분석 페이지와 공유** — §5-2. §4.4는 AppTheme v2와 묶을 것.
8. **EmptyStateWidget 이모지는 shared 파라미터** — §5-3. 제거 범위(피드만 vs 전역) 지시 필요.
9. **FeedBloc 전역 싱글턴의 추천/팔로잉 상태 덮어쓰기** — §6. 재편이 오히려 완화하는 방향.
10. **카테고리 하드코딩 4곳** — §1 O-2. P0-3 대상 확대.
11. [미확인] 라이브 DB: posts 행수(2918 주장), category 값 분포, app_settings 부재 여부(코드상 부재는 확인). 라이브 실측은 대시보드 접근 가능한 쪽에서 수행 요망.
12. [미확인] iOS 쪽 딥링크 표면(mac 브랜치 영역) — 윈도우 로컬에는 ios/ 실측 대상 없음, mac 세션에서 확인 요망.

---

*본 의견서는 §8 프로토콜 1단계 산출물이다. 웹 Claude 검토·승인된 작업지시서 수령 전까지 구현에 착수하지 않는다.*
