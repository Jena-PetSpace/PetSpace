import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../widgets/recent_emotion_card.dart';
import '../widgets/feed_preview_widget.dart';
import '../widgets/quick_actions_widget.dart';
import '../widgets/statistics_summary_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // 홈 데이터 로드
    context.read<HomeBloc>().add(const LoadHomeData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('펫페이스'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              context.push('/notifications');
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              context.push('/profile');
            },
          ),
        ],
      ),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is HomeError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64.w,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16.h),
                  Text(state.message),
                  SizedBox(height: 16.h),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<HomeBloc>().add(const RefreshHomeData());
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          if (state is HomeLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<HomeBloc>().add(const RefreshHomeData());
                // BLoC 이벤트 처리를 위한 짧은 대기
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 환영 메시지
                    _buildWelcomeSection(state),
                    SizedBox(height: 24.h),

                    // 빠른 액션
                    QuickActionsWidget(
                      pets: state.userPets,
                    ),
                    SizedBox(height: 24.h),

                    // 통계 요약
                    if (state.statistics != null)
                      StatisticsSummaryCard(
                        statistics: state.statistics!,
                      ),
                    SizedBox(height: 24.h),

                    // 최근 감정 분석
                    _buildSectionHeader(
                      context,
                      '최근 감정 분석',
                      onViewAll: () => context.push('/emotion-history'),
                    ),
                    SizedBox(height: 12.h),
                    if (state.recentAnalyses.isEmpty)
                      _buildEmptyState(
                        '아직 감정 분석 기록이 없습니다',
                        '반려동물의 사진을 촬영하여 감정을 분석해보세요!',
                        Icons.psychology_outlined,
                      )
                    else
                      ...state.recentAnalyses.map(
                        (analysis) => Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: RecentEmotionCard(analysis: analysis),
                        ),
                      ),
                    SizedBox(height: 24.h),

                    // 피드 미리보기
                    _buildSectionHeader(
                      context,
                      '최근 소식',
                      onViewAll: () => context.push('/feed'),
                    ),
                    SizedBox(height: 12.h),
                    if (state.recentPosts.isEmpty)
                      _buildEmptyState(
                        '아직 피드가 없습니다',
                        '다른 반려인들을 팔로우하고 소식을 확인해보세요!',
                        Icons.article_outlined,
                      )
                    else
                      FeedPreviewWidget(posts: state.recentPosts),
                  ],
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/emotion-analysis');
        },
        backgroundColor: AppTheme.highlightColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt),
        label: const Text('감정 분석'),
      ),
    );
  }

  Widget _buildWelcomeSection(HomeLoaded state) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppTheme.subColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pets,
                color: AppTheme.accentColor,
                size: 32.w,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '안녕하세요!',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    state.userPets.isEmpty
                        ? '반려동물을 등록하고 감정 분석을 시작해보세요'
                        : '${state.userPets.length}마리의 반려동물과 함께하고 있어요',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    VoidCallback? onViewAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: Text('전체보기', style: TextStyle(fontSize: 14.sp)),
          ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 48.w, color: Colors.grey),
              SizedBox(height: 12.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
