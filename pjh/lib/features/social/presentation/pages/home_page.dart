import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../chat/presentation/bloc/chat_badge/chat_badge_bloc.dart';
import '../../presentation/bloc/notification_badge/notification_badge_bloc.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_event.dart';
import '../../../emotion/presentation/bloc/emotion_analysis_bloc.dart';
import '../../../emotion/presentation/bloc/emotion_analysis_event.dart';
import '../../../home/presentation/widgets/home_dashboard_header.dart';
import '../../../home/presentation/widgets/home_quick_actions.dart';
import '../../../home/presentation/widgets/home_quest_card.dart';
import '../../../home/presentation/widgets/category_filter_chips.dart';
import '../../../home/presentation/widgets/hot_topic_banner.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshAll();
        _badgeTimer = Timer.periodic(const Duration(seconds: 60), (_) {
          if (mounted) _refreshBadges();
        });
      }
    });
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            SliverToBoxAdapter(
              child: const HomeDashboardHeader(),
            ),

            // ── 퀵 액션 그리드 ──────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 16.h),
                child: const HomeQuickActions(),
              ),
            ),

            // ── 일일 퀘스트 카드 ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 16.h),
                child: const HomeQuestCard(),
              ),
            ),

            // ── 카테고리 필터 칩 ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 16.h),
                child: CategoryFilterChips(
                  onSelected: (index) {
                    setState(() => _selectedCategory = index);
                  },
                ),
              ),
            ),

            // ── 카테고리별 콘텐츠 ────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 16.h, bottom: 32.h),
                child: _buildCategoryContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryContent() {
    // 0: 인기(전체), 1: 커뮤니티, 2: 건강, 3: 훈련, 4: 매거진
    switch (_selectedCategory) {
      case 1:
        return const CommunityPreview();
      case 2:
        return const CommunityPreview(category: 'health');
      case 3:
        return const CommunityPreview(category: 'training');
      case 4:
        return const MagazineGrid();
      default:
        return Column(
          children: [
            const HotTopicBanner(),
            SizedBox(height: 20.h),
            const MagazineGrid(),
            SizedBox(height: 20.h),
            const CommunityPreview(),
          ],
        );
    }
  }
}
