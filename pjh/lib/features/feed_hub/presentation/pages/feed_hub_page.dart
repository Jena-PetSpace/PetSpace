import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:go_router/go_router.dart';
import '../../../../config/injection_container.dart';
import '../../../../shared/constants/community_categories.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/category_chip.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../social/domain/repositories/social_repository.dart';
import '../../../social/presentation/cubit/operational_cards_cubit.dart';
import '../../../social/presentation/pages/feed_page.dart';
import '../../domain/entities/community_post.dart';
import '../cubit/community_cubit.dart';
import '../widgets/community_post_card.dart';
import '../widgets/magazine_section.dart';
import 'create_community_post_page.dart';

/// 피드 허브 — 발견(사진 피드) | 라운지(커뮤니티) 2탭.
///
/// 2026-07 재편: pill 토글(사진/Q&A)·팔로잉 하위탭을 제거하고
/// 발견 = 추천 사진 피드, 라운지 = 답변 의무 없는 가벼운 커뮤니티로 단순화.
class FeedHubPage extends StatelessWidget {
  /// 0=발견, 1=라운지 (라우터가 신구 딥링크를 이 체계로 정규화).
  final int initialTab;
  final String? initialCategory;
  const FeedHubPage({super.key, this.initialTab = 0, this.initialCategory});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CommunityCubit>(
          create: (_) => CommunityCubit(repository: sl<SocialRepository>()),
        ),
        // 발견 탭 운영 카드 — 탭 전환에도 커서·큐 보존을 위해 페이지 위에 산다.
        BlocProvider<OperationalCardsCubit>(
          create: (_) =>
              OperationalCardsCubit(repository: sl<SocialRepository>())..load(),
        ),
      ],
      child: _FeedHubView(
        initialTab: initialTab,
        initialCategory: initialCategory,
      ),
    );
  }
}

class _FeedHubView extends StatefulWidget {
  final int initialTab;
  final String? initialCategory;
  const _FeedHubView({required this.initialTab, this.initialCategory});

  @override
  State<_FeedHubView> createState() => _FeedHubViewState();
}

class _FeedHubViewState extends State<_FeedHubView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _loungeScrollController = ScrollController();

  /// 라운지 필터 선택: 0=전체, 1..=CommunityCategories.lounge[i-1].
  int _selectedLoungeCategory = 0;

  CommunityCubit get _cubit => context.read<CommunityCubit>();

  String? get _selectedCategoryValue => _selectedLoungeCategory == 0
      ? null
      : CommunityCategories.lounge[_selectedLoungeCategory - 1].value;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    // FAB 아이콘 갱신 + 라운지 최초 진입 로드.
    _tabController.addListener(_onTabChanged);

    if (widget.initialTab >= 1) {
      // 딥링크 category: 신 값만 매칭, 미매칭(구 카테고리·해시태그)은 '전체' 폴백.
      final idx = CommunityCategories.lounge
          .indexWhere((c) => c.value == widget.initialCategory);
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
    setState(() {}); // FAB 아이콘 동기화
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
    return Scaffold(
      backgroundColor: AppTheme.subtleBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          const Divider(height: 1, thickness: 1, color: AppTheme.dividerColor),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const FeedPage(recommended: true, interleaveOperational: true),
                _buildLoungeBody(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.surfaceColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Text(
        '피드',
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryTextColor,
        ),
      ),
      centerTitle: true,
      actions: [
        // 채널 구독 진입점 비노출 (P0-1) — ChannelSubscriptionPage·/channels
        // 라우트는 보존, P2 구독 재도입 시 재연결.
        IconButton(
          icon: SvgPicture.asset(
            'assets/svg/icon_search.svg',
            width: 22,
            height: 22,
            colorFilter: const ColorFilter.mode(AppTheme.primaryTextColor, BlendMode.srcIn),
          ),
          onPressed: () => context.push('/search'),
          tooltip: '검색',
        ),
        SizedBox(width: 4.w),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.surfaceColor,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.secondaryTextColor,
        labelStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500),
        indicatorColor: AppTheme.primaryColor,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        tabs: const [Tab(text: '발견'), Tab(text: '라운지')],
      ),
    );
  }

  // ── 라운지 ──────────────────────────────────────────────────────

  Widget _buildLoungeBody() {
    return Column(
      children: [
        _buildLoungeCategoryBar(),
        const Divider(height: 1, thickness: 1, color: AppTheme.dividerColor),
        Expanded(child: _buildLoungeList()),
      ],
    );
  }

  Widget _buildLoungeCategoryBar() {
    final labels = ['전체', ...CommunityCategories.lounge.map((c) => c.label)];
    return Container(
      color: AppTheme.surfaceColor,
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
        // 매거진 섹션은 '전체'에서만 상단 노출.
        final showMagazine = _selectedLoungeCategory == 0;

        if (state.posts.isEmpty) {
          // 빈 상태에서도 매거진은 보여준다.
          return RefreshIndicator(
            onRefresh: () => _cubit.refresh(),
            child: ListView(
              controller: _loungeScrollController,
              children: [
                if (showMagazine) const MagazineSection(),
                SizedBox(height: 60.h),
                _buildEmpty(),
              ],
            ),
          );
        }

        final headerCount = showMagazine ? 1 : 0;
        return RefreshIndicator(
          onRefresh: () => _cubit.refresh(),
          child: ListView.builder(
            controller: _loungeScrollController,
            padding: EdgeInsets.only(bottom: 8.h),
            itemCount: headerCount +
                state.posts.length +
                (state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (showMagazine && index == 0) {
                return const MagazineSection();
              }
              final postIndex = index - headerCount;
              if (postIndex >= state.posts.length) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              final CommunityPost post = state.posts[postIndex];
              return Padding(
                padding: EdgeInsets.only(top: postIndex == 0 ? 8.h : 0),
                child: GestureDetector(
                  onTap: () => context.push('/post/${post.id}'),
                  child: CommunityPostCard(
                    authorName: post.authorName,
                    category: post.categoryLabel,
                    title: '',
                    content: post.content,
                    likes: post.likes,
                    comments: post.comments,
                    timeAgo: _timeAgo(post.createdAt),
                    isAdmin: post.isAdmin,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    final isAll = _selectedLoungeCategory == 0;
    final label = isAll
        ? '전체'
        : CommunityCategories.lounge[_selectedLoungeCategory - 1].label;
    return EmptyStateWidget(
      icon: Icons.forum_outlined,
      title: isAll ? '아직 글이 없어요' : '$label 글이 아직 없어요',
      subtitle: isAll
          ? '궁금한 점을 물어보거나\n반려 생활 이야기를 나눠보세요!'
          : '$label 카테고리의 첫 글을\n남겨보세요!',
      actionLabel: '첫 글 쓰기',
      onAction: _openCreateCommunityPost,
    );
  }

  // ── FAB ─────────────────────────────────────────────────────────

  Widget _buildFab() {
    final isDiscover = _tabController.index == 0;
    return FloatingActionButton(
      onPressed: _onFabPressed,
      backgroundColor: AppTheme.primaryColor,
      elevation: 3,
      child: Icon(
        isDiscover ? Icons.camera_alt_rounded : Icons.edit_rounded,
        color: Colors.white,
        size: 24.w,
      ),
    );
  }

  Future<void> _onFabPressed() async {
    if (_tabController.index == 0) {
      context.push('/create-post');
    } else {
      await _openCreateCommunityPost();
    }
  }

  /// 라운지 글쓰기 화면 진입 — 작성 성공 시 현재 카테고리 새로고침.
  Future<void> _openCreateCommunityPost() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateCommunityPostPage()),
    );
    if (created == true && mounted) {
      _cubit.refresh();
    }
  }

  String _timeAgo(DateTime dt) {
    final local = dt.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${local.month}/${local.day}';
  }
}
