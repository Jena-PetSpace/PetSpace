# feed_page.dart

**LOC:** 321 | 라우트: (tab 내부) | BLoC: FeedBloc, AuthBloc

## 🎯 상호작용 (2 + PostCard 위임)
- Pull-to-refresh, 무한 스크롤, PostCard (_buildPostCard 공통 헬퍼)

## 🐛 이슈
- ✅ Pre-audit에서 좋아요 userId 빈값 → _effectiveUserId로 수정 완료
- 🟡 Medium: trending_hashtags_section 동반 렌더링 (추천 탭에만) — 일관성 체크
- 🟢 Low: BouncingScrollPhysics

**평가:** 정상 | 버그 2 (M1/L1) + 이미 수정 1건
