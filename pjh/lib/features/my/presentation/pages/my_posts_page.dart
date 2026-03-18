import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../emotion/presentation/bloc/emotion_analysis_bloc.dart';
import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../social/presentation/bloc/feed_bloc.dart';
import '../../../social/presentation/widgets/post_card.dart';

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage>
    with SingleTickerProviderStateMixin {
  static const _kNoPet = '__none__'; // "기타" 필터용 (반려동물 없이 분석)
  late TabController _tabController;
  String? _selectedPetFilter; // null = 전체, _kNoPet = 기타, petId = 특정 반려동물

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  void _loadData() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<FeedBloc>().add(
            LoadFeedRequested(userId: authState.user.uid),
          );
      _loadEmotionData();
    }
  }

  void _loadEmotionData() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      // 전체 및 기타는 서버에서 전체 로드 후 클라이언트 필터링
      // 특정 반려동물은 서버에서 petId로 필터링
      final petId =
          (_selectedPetFilter == null || _selectedPetFilter == _kNoPet)
              ? null
              : _selectedPetFilter;
      context.read<EmotionAnalysisBloc>().add(
            LoadAnalysisHistory(
              userId: authState.user.uid,
              petId: petId,
              limit: 50,
            ),
          );
    }
  }

  /// 클라이언트에서 "기타" 필터 적용
  List<EmotionAnalysis> _filterHistory(List<EmotionAnalysis> history) {
    if (_selectedPetFilter == _kNoPet) {
      return history.where((a) => a.petId == null || a.petId!.isEmpty).toList();
    }
    return history;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '내 게시물',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTextColor,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 2,
          labelColor: AppTheme.primaryColor,
          labelStyle: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelColor: AppTheme.lightTextColor,
          unselectedLabelStyle: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
          ),
          tabs: const [
            Tab(text: '게시물'),
            Tab(text: '감정분석'),
            Tab(text: '커뮤니티'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostsTab(),
          _buildEmotionTab(),
          _buildCommunityTab(),
        ],
      ),
    );
  }

  // ─── 게시물 탭 ───
  Widget _buildPostsTab() {
    return BlocBuilder<FeedBloc, FeedState>(
      builder: (context, state) {
        if (state is FeedLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is FeedLoaded) {
          if (state.posts.isEmpty) {
            return _buildEmptyState(
              icon: Icons.article_outlined,
              title: '작성한 게시물이 없습니다',
              subtitle: '반려동물의 일상을 공유해보세요!',
              buttonLabel: '게시물 작성하기',
              onPressed: () => context.push('/create-post'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              _loadData();
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.separated(
              padding: EdgeInsets.all(16.w),
              itemCount: state.posts.length,
              separatorBuilder: (_, __) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final post = state.posts[index];
                final authState = context.read<AuthBloc>().state;
                final userId =
                    authState is AuthAuthenticated ? authState.user.uid : '';
                return PostCard(
                  post: post,
                  currentUserId: userId,
                  onLike: () => context.read<FeedBloc>().add(
                        LikePostRequested(postId: post.id, userId: userId),
                      ),
                  onComment: () => context.push('/post/${post.id}'),
                  onShare: () {},
                );
              },
            ),
          );
        }
        if (state is FeedError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48.w, color: Colors.grey[400]),
                SizedBox(height: 12.h),
                Text(state.message,
                    style: TextStyle(
                        fontSize: 14.sp, color: AppTheme.secondaryTextColor)),
                SizedBox(height: 16.h),
                ElevatedButton(
                    onPressed: _loadData, child: const Text('다시 시도')),
              ],
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  // ─── 감정분석 탭 ───
  Widget _buildEmotionTab() {
    return Column(
      children: [
        // 반려동물 필터 칩
        _buildPetFilterChips(),
        // 감정분석 리스트
        Expanded(
          child: BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
            builder: (context, state) {
              if (state is EmotionAnalysisHistoryLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is EmotionAnalysisHistoryLoaded) {
                final filtered = _filterHistory(state.history);
                if (filtered.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.psychology_outlined,
                    title: '감정분석 기록이 없습니다',
                    subtitle: 'AI분석 탭에서 반려동물의\n감정을 분석해보세요!',
                    buttonLabel: '감정분석 하러가기',
                    onPressed: () => context.go('/emotion'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _loadEmotionData();
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                    itemBuilder: (context, index) {
                      return _buildAnalysisCard(filtered[index]);
                    },
                  ),
                );
              }
              if (state is EmotionAnalysisError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48.w, color: Colors.grey[400]),
                      SizedBox(height: 12.h),
                      Text(state.message,
                          style: TextStyle(
                              fontSize: 14.sp,
                              color: AppTheme.secondaryTextColor)),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                          onPressed: _loadEmotionData,
                          child: const Text('다시 시도')),
                    ],
                  ),
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ],
    );
  }

  // ─── 반려동물 필터 칩 ───
  Widget _buildPetFilterChips() {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, petState) {
        List<Pet> pets = [];
        if (petState is PetLoaded) {
          pets = petState.pets;
        }
        if (pets.isEmpty) return const SizedBox.shrink();

        return Container(
          height: 48.h,
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: pets.length + 2, // +1 전체, +1 기타
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              // 전체
              if (index == 0) {
                final isSelected = _selectedPetFilter == null;
                return FilterChip(
                  label: Text(
                    '전체',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.secondaryTextColor,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.dividerColor),
                  onSelected: (_) {
                    setState(() => _selectedPetFilter = null);
                    _loadEmotionData();
                  },
                );
              }
              // 기타 (반려동물 없이 분석)
              if (index == 1) {
                final isSelected = _selectedPetFilter == _kNoPet;
                return FilterChip(
                  avatar: isSelected
                      ? null
                      : Icon(Icons.help_outline,
                          size: 14.w, color: AppTheme.secondaryTextColor),
                  label: Text(
                    '기타',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.secondaryTextColor,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.dividerColor),
                  onSelected: (_) {
                    setState(() => _selectedPetFilter = _kNoPet);
                    _loadEmotionData();
                  },
                );
              }
              // 개별 반려동물
              final pet = pets[index - 2];
              final isSelected = _selectedPetFilter == pet.id;
              return FilterChip(
                avatar: isSelected
                    ? null
                    : Icon(
                        pet.type == PetType.dog
                            ? Icons.pets
                            : Icons.catching_pokemon,
                        size: 14.w,
                        color: AppTheme.secondaryTextColor,
                      ),
                label: Text(
                  pet.name,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color:
                        isSelected ? Colors.white : AppTheme.secondaryTextColor,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppTheme.primaryColor,
                backgroundColor: Colors.white,
                side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.dividerColor),
                onSelected: (_) {
                  setState(() => _selectedPetFilter = pet.id);
                  _loadEmotionData();
                },
              );
            },
          ),
        );
      },
    );
  }

  // ─── 커뮤니티 탭 ───
  Widget _buildCommunityTab() {
    return _buildEmptyState(
      icon: Icons.forum_outlined,
      title: '작성한 커뮤니티 글이 없습니다',
      subtitle: '커뮤니티에서 다른 반려인들과\n소통해보세요!',
      buttonLabel: '커뮤니티 가기',
      onPressed: () => context.go('/feed'),
    );
  }

  // ─── 공통 빈 상태 ───
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64.w, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppTheme.secondaryTextColor,
              height: 1.5,
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18.w),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  // ─── 감정분석 카드 ───
  Widget _buildAnalysisCard(EmotionAnalysis analysis) {
    final dominant = analysis.emotions.dominantEmotion;
    final dominantKr = _getEmotionKorean(dominant);
    final emoji = _getEmotionEmoji(dominant);
    final date = _formatDate(analysis.analyzedAt);
    final stress = analysis.emotions.stressLevel;

    return GestureDetector(
      onTap: () => context.push('/emotion/result/${analysis.id}'),
      child: Container(
        decoration: AppTheme.cardDecoration,
        padding: EdgeInsets.all(14.w),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: _getEmotionColor(dominant).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
                child: Text(emoji, style: TextStyle(fontSize: 22.sp)),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$emoji $dominantKr',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    '스트레스 ${stress}점 · $date',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildMiniBar(
                    analysis.emotions.happiness, AppTheme.happinessColor),
                SizedBox(height: 2.h),
                _buildMiniBar(analysis.emotions.anxiety, AppTheme.anxietyColor),
                SizedBox(height: 2.h),
                _buildMiniBar(
                    analysis.emotions.curiosity, AppTheme.curiosityColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBar(double value, Color color) {
    return SizedBox(
      width: 50.w,
      height: 4.h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2.r),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${date.month}/${date.day}';
  }

  String _getEmotionKorean(String emotion) {
    switch (emotion) {
      case 'happiness':
        return '기쁨';
      case 'sadness':
        return '슬픔';
      case 'anxiety':
        return '불안';
      case 'sleepiness':
        return '졸림';
      case 'curiosity':
        return '호기심';
      default:
        return emotion;
    }
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion) {
      case 'happiness':
        return '😊';
      case 'sadness':
        return '😢';
      case 'anxiety':
        return '😰';
      case 'sleepiness':
        return '😴';
      case 'curiosity':
        return '🧐';
      default:
        return '🐾';
    }
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion) {
      case 'happiness':
        return AppTheme.happinessColor;
      case 'sadness':
        return AppTheme.sadnessColor;
      case 'anxiety':
        return AppTheme.anxietyColor;
      case 'sleepiness':
        return AppTheme.sleepinessColor;
      case 'curiosity':
        return AppTheme.curiosityColor;
      default:
        return AppTheme.primaryColor;
    }
  }
}
