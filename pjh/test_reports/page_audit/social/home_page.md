# home_page.dart (social)

**LOC:** 185 | 라우트: `/home` (홈 탭 메인) | BLoC: FeedBloc, AuthBloc

## 🎯 상호작용 (0 직접)
- 하위 위젯(HomeDashboardHeader/QuickActions/QuestCard/CommunityPreview/MagazineGrid/HotTopicBanner)에서 처리

## 🐛 이슈
- 🟡 Medium: 위젯별 Supabase 직접 호출 존재 (community_preview, magazine_grid) — 사전 감사에서 확인
- 🟢 Low: Pull-to-refresh 동작 확인 필요

**평가:** 정상 | 버그 2 (M1/L1)
