import 'dart:developer' as dev;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/lazy_load_list.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../social/domain/repositories/social_repository.dart';
import '../utils/saved_posts_pagination.dart';
import '../widgets/my_pet_summary_section.dart';
import '../widgets/my_profile_header.dart';
import '../widgets/user_badges_section.dart';
import '../../../mbti/presentation/widgets/my_mbti_badge_section.dart';

/// MY탭 stats 갱신 신호를 보내는 싱글톤 notifier
class MyPageStatsNotifier extends ChangeNotifier {
  static final MyPageStatsNotifier instance = MyPageStatsNotifier._();
  MyPageStatsNotifier._();

  void refresh() => notifyListeners();
}

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _statsRefreshKey = 0;
  // 내 게시글 커서 (커서 기반 페이지네이션)
  String? _myPostsCursor;
  bool _myPostsHasMore = true;
  // 저장 게시글 커서 (saved_posts.created_at 기준 — 내 글과 동일 구조)
  String? _savedCursor;
  bool _savedHasMore = true;
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    MyPageStatsNotifier.instance.addListener(_onStatsRefresh);
  }

  @override
  void dispose() {
    MyPageStatsNotifier.instance.removeListener(_onStatsRefresh);
    _tabController.dispose();
    super.dispose();
  }

  void _onStatsRefresh() {
    if (mounted) setState(() => _statsRefreshKey++);
  }

  Future<List<Map<String, dynamic>>> _loadMyPostsInitial() async {
    _myPostsCursor = null;
    _myPostsHasMore = true;
    return _fetchMyPostsPage();
  }

  Future<List<Map<String, dynamic>>> _loadMyPostsMore() async {
    if (!_myPostsHasMore) return [];
    return _fetchMyPostsPage();
  }

  Future<List<Map<String, dynamic>>> _fetchMyPostsPage() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    final repo = sl<SocialRepository>();
    final result = await repo.getUserPostsFiltered(
      authorId: userId,
      limit: _pageSize,
      beforeCreatedAt: _myPostsCursor,
    );
    return result.fold((failure) {
      dev.log('내 게시글 로드 실패: ${failure.message}', name: 'MyPage');
      return [];
    }, (list) {
      if (list.isNotEmpty) {
        _myPostsCursor = list.last['created_at'] as String?;
      }
      if (list.length < _pageSize) _myPostsHasMore = false;
      return list;
    });
  }

  Future<List<Map<String, dynamic>>> _loadSavedPostsInitial() async {
    _savedCursor = null;
    _savedHasMore = true;
    return _fetchSavedPostsPage();
  }

  Future<List<Map<String, dynamic>>> _loadSavedPostsMore() async {
    if (!_savedHasMore) return [];
    return _fetchSavedPostsPage();
  }

  Future<List<Map<String, dynamic>>> _fetchSavedPostsPage() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    final repo = sl<SocialRepository>();
    final result = await repo.getSavedPostsRaw(
      userId,
      limit: _pageSize,
      beforeSavedAt: _savedCursor,
    );
    return result.fold((failure) {
      dev.log('저장 게시글 로드 실패: ${failure.message}', name: 'MyPage');
      return [];
    }, (list) {
      final page = SavedPostsPage.fromFetched(list, pageSize: _pageSize);
      _savedCursor = page.nextCursor ?? _savedCursor;
      _savedHasMore = page.hasMore;
      return page.posts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final user = state.user;
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: SafeArea(
            bottom: false,
            child: Column(
            children: [
              // 헤더 + 뱃지 (스크롤 안 됨 - 고정)
              MyProfileHeader(
                user: user,
                onPostsTapped: () => _tabController.animateTo(0),
                statsRefreshKey: _statsRefreshKey,
              ),
              UserBadgesSection(userId: user.uid),
              // MBTI 성격 유형 뱃지 (결과 있는 pet 만, 없으면 자동 숨김)
              const MyMbtiBadgeSection(),
              // 탭 바 (고정)
              Container(
                color: AppTheme.surfaceColor,
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on_rounded)),
                    Tab(icon: Icon(Icons.bookmark_outline_rounded)),
                  ],
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 2,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.lightTextColor,
                  dividerColor: AppTheme.dividerColor,
                ),
              ),
              // 그리드 (스크롤 영역)
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLazyGrid(
                      onLoadInitial: _loadMyPostsInitial,
                      onLoadMore: _loadMyPostsMore,
                      isMyPosts: true,
                      // 펫 요약은 '내 글' 탭 그리드 상단 헤더로(함께 스크롤).
                      header: MyPetSummarySection(userId: user.uid),
                    ),
                    _buildLazyGrid(
                      onLoadInitial: _loadSavedPostsInitial,
                      onLoadMore: _loadSavedPostsMore,
                      isMyPosts: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildLazyGrid({
    required Future<List<Map<String, dynamic>>> Function() onLoadInitial,
    required Future<List<Map<String, dynamic>>> Function() onLoadMore,
    required bool isMyPosts,
    Widget? header,
  }) {
    return LazyGridView<Map<String, dynamic>>(
      onLoadInitial: onLoadInitial,
      onLoadMore: onLoadMore,
      crossAxisCount: 3,
      mainAxisSpacing: 1.5,
      crossAxisSpacing: 1.5,
      childAspectRatio: 1.0,
      padding: EdgeInsets.zero,
      header: header,
      emptyWidget: _buildEmptyState(isMyPosts),
      itemBuilder: (context, post, i) {
        final postId = post['id'] as String;
        final caption = post['caption'] as String? ?? '';
        final postType = post['post_type'] as String? ?? '';
        final isEmotion = postType == 'emotion';
        final isMulti = postType == 'photo';

        final rawUrls = post['image_urls'];
        String? thumbUrl;
        int imageCount = 0;
        if (rawUrls != null && (rawUrls as List).isNotEmpty) {
          thumbUrl = rawUrls.first as String?;
          imageCount = rawUrls.length;
        } else {
          thumbUrl = post['image_url'] as String?;
          imageCount = thumbUrl != null ? 1 : 0;
        }

        return GestureDetector(
          onTap: () => context.push('/post/$postId'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              thumbUrl != null && thumbUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: thumbUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _buildColorBlock(postId, caption),
                    )
                  : _buildColorBlock(postId, caption),
              if (isEmotion)
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      '감정분석',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (isMulti && imageCount > 1)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Icon(Icons.copy, size: 14.w, color: Colors.white),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorBlock(String postId, String caption) {
    final colors = [
      AppTheme.primaryColor,
      AppTheme.accentColor,
      AppTheme.highlightColor,
      AppTheme.secondaryColor,
      AppTheme.successColor,
    ];
    final color = colors[postId.hashCode.abs() % colors.length];
    return Container(
      color: color.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          caption.isNotEmpty ? caption[0] : '✍',
          style: TextStyle(fontSize: 24.sp, color: color),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isMyPosts) {
    return EmptyStateWidget(
      icon: isMyPosts ? Icons.grid_on_outlined : Icons.bookmark_outline_rounded,
      emoji: isMyPosts ? '📸' : '🔖',
      title: isMyPosts ? '아직 게시글이 없어요' : '저장한 게시글이 없어요',
      subtitle: isMyPosts
          ? '반려동물의 일상을 첫 번째로\n커뮤니티에 공유해보세요!'
          : '마음에 드는 게시글을\n저장해두면 여기서 볼 수 있어요.',
      actionLabel: isMyPosts ? '첫 게시글 작성' : '피드 탐색',
      onAction: isMyPosts
          ? () => context.push('/create-post')
          : () => context.go('/feed'),
    );
  }
}

