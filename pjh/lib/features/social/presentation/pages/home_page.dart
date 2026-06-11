import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../chat/presentation/bloc/chat_badge/chat_badge_bloc.dart';
import '../../presentation/bloc/notification_badge/notification_badge_bloc.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_event.dart';
import '../../../emotion/presentation/bloc/emotion_analysis_bloc.dart';
import '../../../home/presentation/widgets/home_dashboard_header.dart';
import '../../../home/presentation/widgets/home_quick_actions.dart';
import '../../../home/presentation/widgets/home_ad_banner.dart';
import '../../../home/presentation/widgets/home_news_section.dart';
import '../../../home/presentation/widgets/home_quest_card.dart';
import '../../../mbti/presentation/widgets/home_mbti_card.dart';
import '../../../fortune/presentation/widgets/home_fortune_card.dart';
import '../../../quiz/presentation/widgets/home_quiz_card.dart';
import '../../../news/presentation/widgets/home_news_card.dart';
import '../../../home/presentation/widgets/category_filter_chips.dart';
import '../../../home/presentation/widgets/hot_issue_card.dart';
import '../../../home/presentation/widgets/magazine_grid.dart';
import '../../../home/presentation/widgets/community_preview.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _badgeTimer;
  int _selectedCategory = 0;
  final ValueNotifier<int> _questCheckNotifier = ValueNotifier(0);
  String _lastLocation = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshAll();
        _badgeTimer = Timer.periodic(const Duration(seconds: 60), (_) {
          if (mounted) _refreshBadges();
        });
        // GoRouter 변화 감지: 다른 페이지에서 /home으로 돌아올 때 퀘스트 재검증
        GoRouter.of(context).routerDelegate.addListener(_onRouteChanged);
      }
    });
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final location = GoRouterState.of(context).uri.path;
    if (_lastLocation != '/home' && location == '/home') {
      _questCheckNotifier.value++;
    }
    _lastLocation = location;
  }

  void _refreshAll() {
    _refreshBadges();
    _loadEmotionHistory();
    context.read<PetBloc>().add(LoadUserPets());
  }

  void _refreshBadges() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<ChatBadgeBloc>().add(
            ChatBadgeLoadRequested(userId: authState.user.id),
          );
      context.read<NotificationBadgeBloc>().add(
            NotificationBadgeLoadRequested(userId: authState.user.uid),
          );
    }
  }

  void _loadEmotionHistory() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<EmotionAnalysisBloc>().add(
            LoadAnalysisHistory(userId: authState.user.uid, limit: 60),
          );
    }
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    GoRouter.of(context).routerDelegate.removeListener(_onRouteChanged);
    _questCheckNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      // AppBar 완전 제거 → 커스텀 헤더
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshAll();
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── 커스텀 헤더 (딥블루 + 로고 + 대시보드) ──
            const SliverToBoxAdapter(
              child: HomeDashboardHeader(),
            ),

            // ── 퀵 액션 (원형 버튼 5개) ──────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 16.h),
                child: const HomeQuickActions(),
              ),
            ),

            // ── 배너형 광고 / 공지 슬롯 (자리만) ──────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 20.h),
                child: const HomeAdBanner(),
              ),
            ),

            // ── 핫이슈 (썸네일 + 헤드라인 카드) ───────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 24.h),
                child: const HotIssueCard(),
              ),
            ),

            // ── 매거진: 카테고리 칩 ──────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 24.h),
                child: _buildMagazineHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 12.h),
                child: CategoryFilterChips(
                  onSelected: (index) {
                    setState(() => _selectedCategory = index);
                  },
                ),
              ),
            ),

            // ── 매거진: 카테고리별 콘텐츠 ─────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 12.h),
                child: _buildCategoryContent(),
              ),
            ),

            // ── 뉴스 (외부 기사 스크랩 — 추후 구현, 자리만) ─
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 28.h),
                child: const HomeNewsSection(),
              ),
            ),

            // ── (임시 배치) 기존 홈 카드들 — 스크롤 하단 ──
            //   MBTI·운세·퀴즈·퀘스트. 시안엔 없던 영역이라
            //   실제 화면에서 위치를 확인한 뒤 최종 자리를 정한다.
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 28.h),
                child: _buildLegacyCardsSection(),
              ),
            ),
          ],
        ),
      ),
    ), // Scaffold
    ); // AnnotatedRegion
  }

  // 매거진 섹션 헤더 ("매거진" + 더보기)
  Widget _buildMagazineHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Text(
            '매거진',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryTextColor,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.go('/feed?tab=community&category=magazine'),
            child: Text(
              '더보기',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryContent() {
    // 0: 전체, 1: 건강, 2: 훈련, 3: 먹거리, 4: 생활 (피드 Q&A와 동일 체계)
    switch (_selectedCategory) {
      case 1:
        return const CommunityPreview(category: 'health');
      case 2:
        return const CommunityPreview(category: 'training');
      case 3:
        return const CommunityPreview(category: 'food');
      case 4:
        return const CommunityPreview(category: 'life');
      default:
        return const MagazineGrid();
    }
  }

  // 시안엔 없던 기존 홈 카드들 — 위치 확인용으로 스크롤 하단에 임시 배치.
  Widget _buildLegacyCardsSection() {
    return Column(
      children: [
        const HomeMbtiCard(),
        SizedBox(height: 16.h),
        const HomeFortuneCard(),
        SizedBox(height: 16.h),
        const HomeQuizCard(),
        SizedBox(height: 16.h),
        const HomeNewsCard(),
        SizedBox(height: 16.h),
        HomeQuestCard(checkNotifier: _questCheckNotifier),
        SizedBox(height: 32.h),
      ],
    );
  }
}
