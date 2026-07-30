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
import '../../../../shared/widgets/petspace_state_view.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../social/domain/repositories/social_repository.dart';
import '../../../social/domain/entities/saved_posts_page.dart';
import '../widgets/my_pet_summary_section.dart';
import '../widgets/my_profile_header.dart';
import '../widgets/saved_posts_grid.dart';
import '../../../mbti/presentation/widgets/my_mbti_badge_section.dart';

/// MY탭 stats 갱신 신호를 보내는 싱글톤 notifier
class MyPageStatsNotifier extends ChangeNotifier {
  static final MyPageStatsNotifier instance = MyPageStatsNotifier._();
  MyPageStatsNotifier._();

  void refresh() => notifyListeners();
}

/// (세션6 A) MY탭 일부 섹션 임시 숨김 플래그.
/// 위젯·BLoC·데이터는 그대로 두고 화면 노출만 끈다. 되살릴 때 true로 변경.
const bool _kShowMyMbtiSection = false; // 성격유형(MBTI) 뱃지 섹션

class MyPage extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function()? loadMyPostsInitial;
  final Future<List<Map<String, dynamic>>> Function()? loadMyPostsMore;

  const MyPage({super.key, this.loadMyPostsInitial, this.loadMyPostsMore});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _statsRefreshKey = 0;
  int _myGridRefreshKey = 0;
  // 내 게시글 커서 (커서 기반 페이지네이션)
  String? _myPostsCursor;
  bool _myPostsHasMore = true;
  int? _savedCount;
  bool _savedCountError = false;
  int _savedGridRefreshKey = 0;
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
    if (widget.loadMyPostsInitial != null) {
      return widget.loadMyPostsInitial!();
    }
    return _fetchMyPostsPage();
  }

  Future<List<Map<String, dynamic>>> _loadMyPostsMore() async {
    if (widget.loadMyPostsMore != null) return widget.loadMyPostsMore!();
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
    return result.fold(
      (failure) {
        dev.log('내 게시글 로드 실패', name: 'MyPage');
        throw StateError('my-posts-load-failed');
      },
      (list) {
        if (list.isNotEmpty) {
          _myPostsCursor = list.last['created_at'] as String?;
        }
        if (list.length < _pageSize) _myPostsHasMore = false;
        return list;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = state.user;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final selectedColor =
            isDark ? theme.colorScheme.primary : AppTheme.actionBase;
        final headerBackground =
            isDark ? theme.scaffoldBackgroundColor : AppTheme.primaryColor;
        return Scaffold(
          backgroundColor:
              isDark ? theme.scaffoldBackgroundColor : AppTheme.backgroundColor,
          body: SafeArea(
            bottom: false,
            child: NestedScrollView(
              key: const Key('my_nested_scroll_view'),
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  key: const Key('my_top_app_bar'),
                  pinned: true,
                  floating: false,
                  automaticallyImplyLeading: false,
                  toolbarHeight: 48.h,
                  elevation: 0,
                  scrolledUnderElevation: 1,
                  backgroundColor: headerBackground,
                  surfaceTintColor: Colors.transparent,
                  centerTitle: false,
                  titleSpacing: 20.w,
                  title: Text(
                    'MY',
                    style: TextStyle(
                      fontSize: AppTheme.fontTitle.sp,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark ? theme.colorScheme.onSurface : Colors.white,
                    ),
                  ),
                  actions: [
                    IconButton(
                      key: const Key('my_settings_button'),
                      onPressed: () => context.push('/settings/my'),
                      tooltip: '설정',
                      icon: Icon(
                        Icons.settings_outlined,
                        color:
                            isDark ? theme.colorScheme.onSurface : Colors.white,
                        size: 22.w,
                      ),
                    ),
                    SizedBox(width: 8.w),
                  ],
                ),
                SliverToBoxAdapter(
                  child: MyProfileHeader(
                    user: user,
                    showTopBar: false,
                    onPostsTapped: () => _tabController.animateTo(0),
                    statsRefreshKey: _statsRefreshKey,
                    beforeStats: MyPetSummarySection(
                      userId: user.uid,
                      embedded: true,
                    ),
                  ),
                ),
                // 실제 사용자 계약이 확정되지 않은 잠긴 뱃지 목록은 노출하지 않는다.
                // MBTI 성격 유형 뱃지 (결과 있는 pet 만, 없으면 자동 숨김)
                // (세션6 A) 임시 숨김 — 위젯/BLoC/데이터 유지, 노출만 끔.
                if (_kShowMyMbtiSection)
                  const SliverToBoxAdapter(child: MyMbtiBadgeSection()),
                SliverToBoxAdapter(child: SizedBox(height: 8.h)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _MyTabBarHeaderDelegate(
                    backgroundColor: theme.colorScheme.surface,
                    dividerColor: isDark
                        ? theme.colorScheme.outlineVariant
                        : AppTheme.dividerColor,
                    tabBar: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: '내 게시글'),
                        Tab(text: '저장'),
                      ],
                      indicatorColor: selectedColor,
                      indicatorWeight: 2,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelColor: selectedColor,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      dividerColor: Colors.transparent,
                    ),
                  ),
                ),
              ],
              body: ColoredBox(
                color: theme.colorScheme.surface,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLazyGrid(
                      onLoadInitial: _loadMyPostsInitial,
                      onLoadMore: _loadMyPostsMore,
                      isMyPosts: true,
                    ),
                    SavedPostsGrid(
                      key: ValueKey(_savedGridRefreshKey),
                      repository: sl<SocialRepository>(),
                      userId: user.uid,
                      scope: const SavedPostsScope.all(),
                      usePrimaryScrollController: true,
                      onCountChanged: (count) {
                        if (mounted &&
                            (count != _savedCount || _savedCountError)) {
                          setState(() {
                            _savedCount = count;
                            _savedCountError = false;
                          });
                        }
                      },
                      onCountError: () {
                        if (mounted && !_savedCountError) {
                          setState(() => _savedCountError = true);
                        }
                      },
                      header: _SavedTabHeader(
                        count: _savedCount,
                        countError: _savedCountError,
                        onRetry: () => setState(() {
                          _savedGridRefreshKey++;
                          _savedCountError = false;
                        }),
                        onOpenCollections: () => context.push('/my/saved'),
                      ),
                    ),
                  ],
                ),
              ),
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
      key: ValueKey('my-grid-$_myGridRefreshKey-$isMyPosts'),
      onLoadInitial: onLoadInitial,
      onLoadMore: onLoadMore,
      crossAxisCount: 3,
      mainAxisSpacing: 1.5,
      crossAxisSpacing: 1.5,
      childAspectRatio: 1.0,
      padding: EdgeInsets.zero,
      usePrimaryScrollController: true,
      header: header,
      emptyWidget: _buildEmptyState(isMyPosts),
      errorWidget: (retry) => PetSpaceStateView.error(
        key: Key(isMyPosts ? 'my_posts_error' : 'saved_posts_error'),
        icon: Icons.cloud_off_outlined,
        title: isMyPosts ? '내 게시글을 불러오지 못했어요' : '저장한 게시글을 불러오지 못했어요',
        message: '인터넷 연결을 확인하고 다시 시도해주세요.',
        actionLabel: '다시 시도',
        onAction: retry,
      ),
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

        return Semantics(
          button: true,
          label: caption.trim().isEmpty ? '게시물 상세 보기' : '$caption 게시물 상세 보기',
          child: GestureDetector(
            onTap: () async {
              final removed = await context.push<bool>('/post/$postId');
              if (removed == true && mounted) {
                setState(() => _myGridRefreshKey++);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                thumbUrl != null && thumbUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _buildNeutralPreview(postId, caption),
                      )
                    : _buildNeutralPreview(postId, caption),
                if (isEmotion)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        '감정분석',
                        style: TextStyle(
                          fontSize: 12.sp,
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
          ),
        );
      },
    );
  }

  Widget _buildNeutralPreview(String postId, String caption) {
    final text = caption.trim();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      key: Key('my_post_preview_$postId'),
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest
          : AppTheme.subtleBackground,
      padding: EdgeInsets.all(12.w),
      child: Center(
        child: text.isNotEmpty
            ? Text(
                text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  height: 1.4,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : Icon(
                Icons.notes_rounded,
                size: 26.w,
                color: theme.colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }

  Widget _buildEmptyState(bool isMyPosts) {
    return EmptyStateWidget(
      icon: isMyPosts ? Icons.grid_on_outlined : Icons.bookmark_outline_rounded,
      title: isMyPosts ? '아직 게시글이 없어요' : '저장한 게시글이 없어요',
      subtitle: isMyPosts
          ? '반려동물의 첫 일상을\n피드에 공유해보세요.'
          : '마음에 드는 게시글을\n저장해두면 여기서 볼 수 있어요.',
      actionLabel: isMyPosts ? '첫 게시글 작성' : '피드 탐색',
      onAction: isMyPosts
          ? () => context.push('/create-post')
          : () => context.go('/feed'),
    );
  }
}

class _MyTabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;
  final Color dividerColor;

  const _MyTabBarHeaderDelegate({
    required this.tabBar,
    required this.backgroundColor,
    required this.dividerColor,
  });

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      key: const Key('my_content_tabs_surface'),
      color: backgroundColor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: dividerColor)),
        ),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _MyTabBarHeaderDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.dividerColor != dividerColor;
  }
}

class _SavedTabHeader extends StatelessWidget {
  final int? count;
  final bool countError;
  final VoidCallback onRetry;
  final VoidCallback onOpenCollections;

  const _SavedTabHeader({
    required this.count,
    required this.countError,
    required this.onRetry,
    required this.onOpenCollections,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('saved_tab_header'),
      color: theme.colorScheme.surface,
      padding: EdgeInsets.fromLTRB(18.w, 16.h, 14.w, 14.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  countError
                      ? '전체 저장 —'
                      : count == null
                          ? '전체 저장'
                          : '전체 저장 $count개',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  '저장한 글을 한곳에서 확인해요.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (countError)
            IconButton(
              key: const Key('retry_saved_tab_count'),
              tooltip: '저장 개수 다시 불러오기',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
          OutlinedButton.icon(
            key: const Key('open_saved_collections'),
            onPressed: onOpenCollections,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              foregroundColor: AppTheme.actionBase,
              side: BorderSide(
                color: AppTheme.actionBase.withValues(alpha: 0.35),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
              ),
            ),
            icon: Icon(Icons.folder_outlined, size: 18.w),
            label: const Text('컬렉션 보기'),
          ),
        ],
      ),
    );
  }
}
