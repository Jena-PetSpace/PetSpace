# my_page.dart (MY 탭 메인)

**LOC:** 311 | 라우트: `/my` | BLoC: AuthBloc | **Supabase 직접 호출 3건**

## 🎯 상호작용 (2 + TabView 내부)
- TabBar (내 게시글/저장), FAB/설정 (내부 위젯)

## 🐛 이슈
- ✅ **Pre-audit에서 6.1px overflow 수정 완료**
- 🟠 High: Supabase 직접 호출 3건 (아키텍처 위반)
- 🟡 Medium: TabBar 2탭, 게시글 Grid
- 🟢 Low: MyProfileHeader/UserBadgesSection 하위 위젯에 Supabase 추가 호출 가능성

**평가:** 정상 | 버그 3 (H1/M1/L1) + 수정 1건
