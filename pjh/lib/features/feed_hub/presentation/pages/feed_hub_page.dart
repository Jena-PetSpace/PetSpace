import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../social/presentation/pages/channel_subscription_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:go_router/go_router.dart';
import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../social/domain/repositories/social_repository.dart';
import '../../../social/presentation/pages/feed_page.dart';
import '../../domain/entities/community_post.dart';
import '../cubit/community_cubit.dart';
import '../widgets/community_post_card.dart';
import 'create_community_post_page.dart';

enum _FeedMode { photo, qna }

class FeedHubPage extends StatelessWidget {
  final int initialTab;
  final String? initialCategory;
  const FeedHubPage({super.key, this.initialTab = 0, this.initialCategory});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CommunityCubit>(
      create: (_) => CommunityCubit(repository: sl<SocialRepository>()),
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
    with TickerProviderStateMixin {
  late TabController _photoTabController;
  late TabController _qnaTabController;
  final ScrollController _qnaScrollController = ScrollController();

  _FeedMode _mode = _FeedMode.photo;
  int _selectedQnaCategory = 0;

  static const List<Map<String, String?>> _qnaCategories = [
    {'label': '전체', 'value': null},
    {'label': '건강', 'value': 'health'},
    {'label': '훈련', 'value': 'training'},
    {'label': '먹거리', 'value': 'food'},
    {'label': '생활', 'value': 'life'},
  ];

  CommunityCubit get _cubit => context.read<CommunityCubit>();

  @override
  void initState() {
    super.initState();
    _photoTabController = TabController(length: 2, vsync: this);
    _qnaTabController = TabController(length: 5, vsync: this);
    _qnaScrollController.addListener(_onQnaScroll);

    if (widget.initialTab >= 2) {
      _mode = _FeedMode.qna;
      if (widget.initialCategory != null) {
        for (int i = 0; i < _qnaCategories.length; i++) {
          if (_qnaCategories[i]['value'] == widget.initialCategory) {
            _selectedQnaCategory = i;
            _qnaTabController.index = i;
            break;
          }
        }
      }
      _cubit.loadCategory(_qnaCategories[_selectedQnaCategory]['value']);
    }

    _qnaTabController.addListener(() {
      if (!_qnaTabController.indexIsChanging) {
        setState(() => _selectedQnaCategory = _qnaTabController.index);
        _cubit.loadCategory(_qnaCategories[_qnaTabController.index]['value']);
      }
    });
  }

  @override
  void dispose() {
    _photoTabController.dispose();
    _qnaTabController.dispose();
    _qnaScrollController.dispose();
    super.dispose();
  }

  void _onQnaScroll() {
    if (_qnaScrollController.position.pixels >=
        _qnaScrollController.position.maxScrollExtent * 0.8) {
      _cubit.loadMore();
    }
  }

  void _switchMode(_FeedMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (mode == _FeedMode.qna && _cubit.state.status == CommunityStatus.initial) {
      _cubit.loadCategory(_qnaCategories[_selectedQnaCategory]['value']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.subtleBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // 세그먼트 + 탭바 헤더
          _buildHeader(),
          // 본문
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _mode == _FeedMode.photo
                  ? _buildPhotoBody()
                  : _buildQnaBody(),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
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
        IconButton(
          icon: const Icon(Icons.tune_rounded, color: AppTheme.primaryTextColor),
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => DraggableScrollableSheet(
              initialChildSize: 0.7,
              builder: (ctx, ctrl) => Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const ChannelSubscriptionPage(),
              ),
            ),
          ),
          tooltip: '채널 구독',
        ),
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

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상위 탭 (사진 / Q&A) — AI 분석 페이지와 동일한 pill-style 토글
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0F4),
                borderRadius: BorderRadius.circular(30.r),
              ),
              padding: EdgeInsets.all(3.w),
              child: Row(
                children: [
                  _modeTab(
                    label: '사진',
                    active: _mode == _FeedMode.photo,
                    onTap: () => _switchMode(_FeedMode.photo),
                  ),
                  _modeTab(
                    label: 'Q&A',
                    active: _mode == _FeedMode.qna,
                    onTap: () => _switchMode(_FeedMode.qna),
                  ),
                ],
              ),
            ),
          ),
          // 하위 탭
          if (_mode == _FeedMode.photo)
            _buildPhotoTabBar()
          else
            _buildQnaTabBar(),
          const Divider(height: 1, thickness: 1, color: AppTheme.dividerColor),
        ],
      ),
    );
  }

  Widget _modeTab({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: 11.h),
          decoration: BoxDecoration(
            color: active ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(26.r),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? Colors.white : AppTheme.secondaryTextColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoTabBar() {
    return SizedBox(
      height: 42.h,
      child: TabBar(
        controller: _photoTabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.secondaryTextColor,
        labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w400),
        indicatorColor: AppTheme.primaryColor,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        tabs: const [Tab(text: '추천'), Tab(text: '팔로잉')],
      ),
    );
  }

  Widget _buildQnaTabBar() {
    return SizedBox(
      height: 42.h,
      child: TabBar(
        controller: _qnaTabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.secondaryTextColor,
        labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w400),
        indicatorColor: AppTheme.primaryColor,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: '전체'),
          Tab(text: '건강'),
          Tab(text: '훈련'),
          Tab(text: '먹거리'),
          Tab(text: '생활'),
        ],
      ),
    );
  }

  Widget _buildPhotoBody() {
    return TabBarView(
      key: const ValueKey('photo'),
      controller: _photoTabController,
      children: const [
        FeedPage(recommended: true),
        FeedPage(followingOnly: true),
      ],
    );
  }

  Widget _buildQnaBody() {
    return KeyedSubtree(
      key: const ValueKey('qna'),
      child: BlocBuilder<CommunityCubit, CommunityState>(
        builder: (context, state) {
          if (state.status == CommunityStatus.loading ||
              state.status == CommunityStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.posts.isEmpty) {
            return _buildEmpty();
          }
          return RefreshIndicator(
            onRefresh: () => _cubit.refresh(),
            child: ListView.builder(
              controller: _qnaScrollController,
              padding: EdgeInsets.symmetric(vertical: 8.h),
              itemCount: state.posts.length + (state.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= state.posts.length) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                final CommunityPost post = state.posts[index];
                return GestureDetector(
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
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 56.w, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text('게시글이 없습니다',
              style: TextStyle(fontSize: 15.sp, color: Colors.grey[500])),
          SizedBox(height: 6.h),
          Text('첫 번째 글을 작성해보세요',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildFab() {
    final isPhoto = _mode == _FeedMode.photo;
    return FloatingActionButton(
      onPressed: () => _onFabPressed(context),
      backgroundColor: isPhoto ? AppTheme.primaryColor : Colors.amber[700],
      elevation: 3,
      child: Icon(
        isPhoto ? Icons.camera_alt_rounded : Icons.edit_rounded,
        color: Colors.white,
        size: 24.w,
      ),
    );
  }

  Future<void> _onFabPressed(BuildContext context) async {
    if (_mode == _FeedMode.photo) {
      context.push('/create-post');
    } else {
      final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const CreateCommunityPostPage()),
      );
      if (created == true && mounted) {
        _cubit.refresh();
      }
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
