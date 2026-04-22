import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../social/presentation/pages/channel_subscription_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:go_router/go_router.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../social/presentation/pages/feed_page.dart';
import '../widgets/community_post_card.dart';
import 'create_community_post_page.dart';

enum _FeedMode { photo, qna }

class FeedHubPage extends StatefulWidget {
  final int initialTab;
  final String? initialCategory;
  const FeedHubPage({super.key, this.initialTab = 0, this.initialCategory});

  @override
  State<FeedHubPage> createState() => _FeedHubPageState();
}

class _FeedHubPageState extends State<FeedHubPage>
    with TickerProviderStateMixin {
  late TabController _photoTabController;
  late TabController _qnaTabController;
  final _supabase = Supabase.instance.client;

  _FeedMode _mode = _FeedMode.photo;

  // Q&A 탭 상태
  int _selectedQnaCategory = 0;
  List<Map<String, dynamic>> _communityPosts = [];
  bool _communityLoading = true;

  static const List<Map<String, String?>> _qnaCategories = [
    {'label': '전체', 'value': null},
    {'label': '건강', 'value': 'health'},
    {'label': '훈련', 'value': 'training'},
    {'label': '먹거리', 'value': 'food'},
    {'label': '생활', 'value': 'life'},
  ];

  @override
  void initState() {
    super.initState();
    _photoTabController = TabController(length: 2, vsync: this);
    _qnaTabController = TabController(length: 5, vsync: this);

    // initialTab: 0,1 → 사진모드 / 2+ → Q&A모드
    if (widget.initialTab >= 2) {
      _mode = _FeedMode.qna;
      // initialCategory 매핑
      if (widget.initialCategory != null) {
        for (int i = 0; i < _qnaCategories.length; i++) {
          if (_qnaCategories[i]['value'] == widget.initialCategory) {
            _selectedQnaCategory = i;
            _qnaTabController.index = i;
            break;
          }
        }
      }
      _loadCommunityPosts(
          category: _qnaCategories[_selectedQnaCategory]['value']);
    }

    _qnaTabController.addListener(() {
      if (!_qnaTabController.indexIsChanging) {
        setState(() => _selectedQnaCategory = _qnaTabController.index);
        _loadCommunityPosts(
            category: _qnaCategories[_qnaTabController.index]['value']);
      }
    });
  }

  @override
  void dispose() {
    _photoTabController.dispose();
    _qnaTabController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunityPosts({String? category}) async {
    setState(() => _communityLoading = true);
    try {
      var query = _supabase
          .from('posts')
          .select(
              'id, author_id, caption, hashtags, likes_count, comments_count, created_at, users!posts_author_id_fkey(display_name, photo_url)')
          .isFilter('deleted_at', null)
          .not('hashtags', 'cs', '{"magazine"}');

      if (category != null) {
        query = query.contains('hashtags', [category]);
      }

      final response =
          await query.order('created_at', ascending: false).limit(30);
      setState(() {
        _communityPosts = List<Map<String, dynamic>>.from(response);
        _communityLoading = false;
      });
    } catch (e) {
      dev.log('커뮤니티 포스트 로드 실패: $e', name: 'FeedHubPage');
      setState(() => _communityLoading = false);
    }
  }

  void _switchMode(_FeedMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (mode == _FeedMode.qna && _communityPosts.isEmpty) {
      _loadCommunityPosts(
          category: _qnaCategories[_selectedQnaCategory]['value']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => DraggableScrollableSheet(
                initialChildSize: 0.7,
                builder: (ctx, ctrl) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
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
              width: 24,
              height: 24,
              colorFilter:
                  const ColorFilter.mode(Colors.black87, BlendMode.srcIn),
            ),
            onPressed: () => context.push('/search'),
            tooltip: '검색',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_mode == _FeedMode.photo ? 100.h : 116.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단 세그먼트: 📷 사진 | 💬 Q&A
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.subtleBackground,
                    borderRadius: BorderRadius.circular(30.r),
                  ),
                  padding: EdgeInsets.all(3.w),
                  child: Row(
                    children: [
                      _buildSegmentButton(
                        label: '📷  사진',
                        active: _mode == _FeedMode.photo,
                        onTap: () => _switchMode(_FeedMode.photo),
                      ),
                      _buildSegmentButton(
                        label: '💬  Q&A',
                        active: _mode == _FeedMode.qna,
                        onTap: () => _switchMode(_FeedMode.qna),
                      ),
                    ],
                  ),
                ),
              ),
              // 모드별 탭바
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                child: _mode == _FeedMode.photo
                    ? _buildPhotoTabBar()
                    : _buildQnaTabBar(),
              ),
            ],
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: _mode == _FeedMode.photo
            ? _buildPhotoBody()
            : _buildQnaBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onFabPressed(context),
        backgroundColor: _mode == _FeedMode.photo
            ? AppTheme.primaryColor
            : Colors.amber[700],
        child: Icon(
          _mode == _FeedMode.photo ? Icons.camera_alt_rounded : Icons.edit_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 9.h),
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
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
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
      key: const ValueKey('photo-tabbar'),
      height: 44.h,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: TabBar(
          controller: _photoTabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.secondaryTextColor,
          labelStyle:
              TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w400),
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 2.5,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: '추천'),
            Tab(text: '팔로잉'),
          ],
        ),
      ),
    );
  }

  Widget _buildQnaTabBar() {
    return SizedBox(
      key: const ValueKey('qna-tabbar'),
      height: 44.h,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: TabBar(
          controller: _qnaTabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.secondaryTextColor,
          labelStyle:
              TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w400),
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 2.5,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: '전체'),
            Tab(text: '건강'),
            Tab(text: '훈련'),
            Tab(text: '먹거리'),
            Tab(text: '생활'),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoBody() {
    return TabBarView(
      key: const ValueKey('photo-body'),
      controller: _photoTabController,
      children: const [
        FeedPage(),
        FeedPage(followingOnly: true),
      ],
    );
  }

  Widget _buildQnaBody() {
    return KeyedSubtree(
      key: const ValueKey('qna-body'),
      child: Column(
        children: [
          // 게시글 리스트
          Expanded(
            child: _communityLoading
                ? const Center(child: CircularProgressIndicator())
                : _communityPosts.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: () async {
                          final cat = _qnaCategories[_selectedQnaCategory]['value'];
                          await _loadCommunityPosts(category: cat);
                        },
                        child: ListView.builder(
                          padding: EdgeInsets.all(16.w),
                          itemCount: _communityPosts.length,
                          itemBuilder: (context, index) {
                            final post = _communityPosts[index];
                            final user =
                                post['users'] as Map<String, dynamic>?;
                            final hashtags =
                                List<String>.from(post['hashtags'] ?? []);
                            final displayName =
                                user?['display_name'] as String? ?? '익명';
                            return GestureDetector(
                              onTap: () =>
                                  context.push('/post/${post['id']}'),
                              child: CommunityPostCard(
                                authorName: displayName,
                                category: _categoryFromHashtags(hashtags),
                                title: '',
                                content: post['caption'] as String? ?? '',
                                likes: post['likes_count'] as int? ?? 0,
                                comments:
                                    post['comments_count'] as int? ?? 0,
                                timeAgo: _timeAgo(
                                    post['created_at'] as String? ?? ''),
                                isAdmin: displayName == '관리자',
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 64.w, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text('게시글이 없습니다',
              style: TextStyle(fontSize: 16.sp, color: Colors.grey[500])),
          SizedBox(height: 8.h),
          Text('첫 번째 글을 작성해보세요',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[400])),
        ],
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
        final cat = _qnaCategories[_selectedQnaCategory]['value'];
        _loadCommunityPosts(category: cat);
      }
    }
  }

  String _categoryFromHashtags(List<String> hashtags) {
    for (final tag in hashtags) {
      if (tag == 'qa') return 'Q&A';
      if (tag == 'health') return '건강';
      if (tag == 'training') return '훈련';
      if (tag == 'food') return '먹거리';
      if (tag == 'life') return '생활';
      if (tag == 'magazine') return '매거진';
    }
    return '';
  }

  String _timeAgo(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }
}
