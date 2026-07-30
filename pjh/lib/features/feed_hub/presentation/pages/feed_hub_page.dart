import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../config/injection_container.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../shared/constants/community_categories.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/category_chip.dart';
import '../../../../shared/widgets/petspace_uiux_v3.dart';
import '../../../social/domain/repositories/social_repository.dart';
import '../../../social/presentation/cubit/operational_cards_cubit.dart';
import '../../../social/presentation/pages/feed_page.dart';
import '../../../social/presentation/widgets/social_content_report_sheet.dart';
import '../../../social/presentation/widgets/social_user_actions_sheet.dart';
import '../../domain/entities/community_post.dart';
import '../cubit/community_cubit.dart';
import '../widgets/community_post_card.dart';
import 'create_community_post_page.dart';

/// 피드 허브 — 피드(사진 중심 근황) | 커뮤니티(주제 중심 대화) 2탭.
///
/// 스토리형 원형 행 없이 게시물부터 시작하고 두 탭의 언어를 분리한다.
class FeedHubPage extends StatelessWidget {
  /// 0=피드, 1=커뮤니티 (라우터가 구 딥링크도 이 체계로 정규화).
  final int initialTab;
  final String? initialCategory;
  final CommunityCubit? communityCubit;
  final String? currentUserId;

  /// 테스트·시각 검토에서 서버/전역 BLoC 없이 피드 표면만 주입하는 seam.
  /// 제품 경로에서는 null이며 기존 [FeedPage]와 운영 카드를 그대로 사용한다.
  final Widget? feedContent;

  const FeedHubPage({
    super.key,
    this.initialTab = 0,
    this.initialCategory,
    this.communityCubit,
    this.feedContent,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final view = _FeedHubView(
      initialTab: initialTab,
      initialCategory: initialCategory,
      feedContent: feedContent,
      currentUserId: currentUserId,
    );
    final withCommunity = communityCubit == null
        ? BlocProvider<CommunityCubit>(
            create: (_) => CommunityCubit(repository: sl<SocialRepository>()),
            child: view,
          )
        : BlocProvider<CommunityCubit>.value(
            value: communityCubit!,
            child: view,
          );

    if (feedContent != null) return withCommunity;
    return BlocProvider<OperationalCardsCubit>(
      // 피드 탭 운영 카드 — 탭 전환에도 커서·큐 보존을 위해 페이지 위에 산다.
      create: (_) =>
          OperationalCardsCubit(repository: sl<SocialRepository>())..load(),
      child: withCommunity,
    );
  }
}

class _FeedHubView extends StatefulWidget {
  final int initialTab;
  final String? initialCategory;
  final Widget? feedContent;
  final String? currentUserId;
  const _FeedHubView({
    required this.initialTab,
    this.initialCategory,
    this.feedContent,
    this.currentUserId,
  });

  @override
  State<_FeedHubView> createState() => _FeedHubViewState();
}

class _FeedHubViewState extends State<_FeedHubView>
    with SingleTickerProviderStateMixin {
  static const List<CommunityCategory> _communityTabs = [
    CommunityCategory(value: 'qa', label: '질문'),
    CommunityCategory(value: 'info', label: '정보'),
    CommunityCategory(value: 'brag', label: '자랑'),
    CommunityCategory(value: 'chat', label: '일상'),
  ];

  late TabController _tabController;
  final ScrollController _loungeScrollController = ScrollController();

  /// 커뮤니티 필터 선택: 0=전체, 1..=CommunityCategories.lounge[i-1].
  int _selectedLoungeCategory = 0;
  final Set<String> _locallyBlockedAuthorIds = <String>{};

  CommunityCubit get _cubit => context.read<CommunityCubit>();

  String? get _selectedCategoryValue => _selectedLoungeCategory == 0
      ? null
      : _communityTabs[_selectedLoungeCategory - 1].value;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    // 커뮤니티 최초 진입 로드.
    _tabController.addListener(_onTabChanged);

    if (widget.initialTab >= 1) {
      // 딥링크 category: 신 값만 매칭, 미매칭(구 카테고리·해시태그)은 '전체' 폴백.
      final idx =
          _communityTabs.indexWhere((c) => c.value == widget.initialCategory);
      if (idx >= 0) _selectedLoungeCategory = idx + 1;
      _cubit.loadCategory(_selectedCategoryValue);
    }

    _loungeScrollController.addListener(_onLoungeScroll);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _loungeScrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1 &&
        _cubit.state.status == CommunityStatus.initial) {
      _cubit.loadCategory(_selectedCategoryValue);
    }
  }

  void _onLoungeScroll() {
    if (_loungeScrollController.position.pixels >=
        _loungeScrollController.position.maxScrollExtent * 0.8) {
      _cubit.loadMore();
    }
  }

  void _onLoungeCategorySelected(int index) {
    if (_selectedLoungeCategory == index) return;
    setState(() => _selectedLoungeCategory = index);
    _cubit.loadCategory(_selectedCategoryValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                widget.feedContent ??
                    const FeedPage(
                      recommended: true,
                      interleaveOperational: true,
                    ),
                _buildLoungeBody(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 48.h,
      title: Text(
        'PetSpace',
        style: TextStyle(
          fontSize: 20.sp,
          fontWeight: FontWeight.w800,
          color: isDark ? theme.colorScheme.onSurface : AppTheme.brandDeep,
        ),
      ),
      centerTitle: false,
      titleSpacing: 20.w,
      actions: [
        // 현재 탭 문법에 맞는 작성 화면으로 이동한다.
        IconButton(
          icon: Icon(Icons.edit_outlined,
              size: 22.w, color: theme.colorScheme.onSurface),
          onPressed: _onWritePressed,
          tooltip: '글쓰기',
        ),
        IconButton(
          icon: SvgPicture.asset(
            'assets/svg/icon_search.svg',
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(
              theme.colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
          onPressed: () => context.push('/search'),
          tooltip: '검색',
        ),
        SizedBox(width: 4.w),
      ],
    );
  }

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: theme.brightness == Brightness.dark
            ? theme.colorScheme.primary
            : AppTheme.brandDeep,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500),
        indicatorColor: AppTheme.actionBase,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: theme.dividerColor,
        dividerHeight: 1,
        tabs: const [
          Tab(text: '피드', height: 40),
          Tab(text: '커뮤니티', height: 40),
        ],
      ),
    );
  }

  // ── 커뮤니티 ────────────────────────────────────────────────────

  Widget _buildLoungeBody() {
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildLoungeCategoryBar(),
        Divider(height: 1, thickness: 1, color: theme.dividerColor),
        Expanded(child: _buildLoungeList()),
      ],
    );
  }

  Widget _buildLoungeCategoryBar() {
    final theme = Theme.of(context);
    final labels = ['전체', ..._communityTabs.map((c) => c.label)];
    return Container(
      color: theme.colorScheme.surface,
      height: 48.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        itemCount: labels.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) => CategoryChip(
          label: labels[index],
          selected: _selectedLoungeCategory == index,
          onTap: () => _onLoungeCategorySelected(index),
        ),
      ),
    );
  }

  Widget _buildLoungeList() {
    return BlocBuilder<CommunityCubit, CommunityState>(
      builder: (context, state) {
        if (state.status == CommunityStatus.loading ||
            state.status == CommunityStatus.initial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == CommunityStatus.error && state.posts.isEmpty) {
          final isNetworkError =
              state.errorMessage?.startsWith('네트워크') ?? false;
          return PetSpaceV3StateView(
            key: const Key('community_initial_error'),
            kind: isNetworkError
                ? PetSpaceV3StateKind.network
                : PetSpaceV3StateKind.server,
            title: isNetworkError ? '인터넷 연결을 확인해주세요' : '커뮤니티 글을 불러오지 못했어요',
            message:
                isNetworkError ? '연결이 복구되면 다시 시도할 수 있어요.' : '잠시 후 다시 시도해주세요.',
            primaryActionLabel: '다시 시도',
            onPrimaryAction: () => _cubit.loadCategory(_selectedCategoryValue),
          );
        }

        if (state.posts.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => _cubit.refresh(),
            child: ListView(
              controller: _loungeScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 60.h),
                _buildEmpty(),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _cubit.refresh(),
          child: ListView.builder(
            controller: _loungeScrollController,
            padding: EdgeInsets.only(top: 12.h, bottom: 12.h),
            itemCount: state.posts.length +
                (state.isLoadingMore || state.errorMessage != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= state.posts.length) {
                if (state.errorMessage != null) {
                  return Padding(
                    key: const Key('community_load_more_error'),
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: _cubit.loadMore,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('글을 더 불러오지 못했어요 · 다시 시도'),
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              final CommunityPost post = state.posts[index];
              return CommunityPostCard(
                authorName: post.authorName,
                authorPhotoUrl: post.authorPhotoUrl,
                category: _communityCategoryLabel(post.category),
                title: post.title,
                content: post.body,
                likes: post.likes,
                comments: post.comments,
                timeAgo: _timeAgo(post.createdAt),
                isAdmin: post.isAdmin,
                onTap: () => _openCommunityPost(post),
                onReportPost: post.authorId == _currentUserId
                    ? null
                    : () => _reportCommunityPost(post),
                onUserActions: post.authorId == _currentUserId
                    ? null
                    : () => _showCommunityUserActions(post),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    if (_locallyBlockedAuthorIds.isNotEmpty) {
      return const PetSpaceV3StateView(
        key: Key('community_blocked_hidden'),
        kind: PetSpaceV3StateKind.blockedHidden,
        title: '차단한 사용자의 글을 숨겼어요',
        message: '새 글이 등록되거나 새로고침하면 최신 커뮤니티를 확인할 수 있어요.',
      );
    }
    final isAll = _selectedLoungeCategory == 0;
    final label =
        isAll ? '전체' : _communityTabs[_selectedLoungeCategory - 1].label;
    return PetSpaceV3StateView(
      kind: PetSpaceV3StateKind.empty,
      title: isAll ? '아직 글이 없어요' : '$label 글이 아직 없어요',
      message:
          isAll ? '궁금한 점을 물어보거나 반려 생활 이야기를 나눠보세요.' : '$label 카테고리의 첫 글을 남겨보세요.',
      primaryActionLabel: '첫 글 쓰기',
      onPrimaryAction: _openCreateCommunityPost,
    );
  }

  // ── 글쓰기 (앱바 진입) ──────────────────────────────────────────

  Future<void> _onWritePressed() async {
    if (_tabController.index == 0) {
      context.push('/create-post');
    } else {
      await _openCreateCommunityPost();
    }
  }

  /// 커뮤니티 글쓰기 화면 진입 — 작성 성공 시 현재 카테고리 새로고침.
  Future<void> _openCreateCommunityPost() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateCommunityPostPage()),
    );
    if (created == true && mounted) {
      _cubit.refresh();
    }
  }

  String get _currentUserId {
    if (widget.currentUserId?.isNotEmpty == true) {
      return widget.currentUserId!;
    }
    try {
      return Supabase.instance.client.auth.currentUser?.id ?? '';
    } on AssertionError {
      return '';
    }
  }

  String _communityCategoryLabel(String? category) {
    for (final item in _communityTabs) {
      if (item.value == category) return item.label;
    }
    return CommunityCategories.label(category);
  }

  Future<void> _openCommunityPost(CommunityPost post) async {
    final removed = await context.push<bool>('/post/${post.id}');
    if (removed != true || !mounted) return;
    if (post.authorId == _currentUserId) {
      await _cubit.refresh();
    } else {
      _locallyBlockedAuthorIds.add(post.authorId);
      _cubit.hideAuthor(post.authorId);
    }
  }

  Future<void> _reportCommunityPost(CommunityPost post) async {
    final userId = _currentUserId;
    if (userId.isEmpty) return;
    final accepted = await SocialContentReportSheet.show(
      context,
      target: SocialReportTarget.post,
      targetId: post.id,
      currentUserId: userId,
      repository: sl<SocialRepository>(),
    );
    if (accepted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시물 신고가 접수되었습니다.')),
      );
    }
  }

  Future<void> _showCommunityUserActions(CommunityPost post) async {
    final userId = _currentUserId;
    if (userId.isEmpty) return;
    await SocialUserActionsSheet.show(
      context,
      targetUserId: post.authorId,
      targetUserName: post.authorName,
      currentUserId: userId,
      repository: sl<SocialRepository>(),
      onBlocked: () {
        _locallyBlockedAuthorIds.add(post.authorId);
        _cubit.hideAuthor(post.authorId);
      },
    );
  }

  String _timeAgo(DateTime dt) => formatRelativeTime(dt);
}
