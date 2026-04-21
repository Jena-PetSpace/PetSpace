import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../social/presentation/pages/channel_subscription_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:go_router/go_router.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../social/domain/entities/post.dart';
import '../../../social/presentation/pages/feed_page.dart';
import '../widgets/community_post_card.dart';
import '../widgets/post_type_picker_sheet.dart';
import 'create_community_post_page.dart';

class FeedHubPage extends StatefulWidget {
  final int initialTab;
  final String? initialCategory;
  const FeedHubPage({super.key, this.initialTab = 0, this.initialCategory});

  @override
  State<FeedHubPage> createState() => _FeedHubPageState();
}

class _FeedHubPageState extends State<FeedHubPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;

  // 커뮤니티 탭 상태
  int _selectedCategory = 0;
  List<Map<String, dynamic>> _communityPosts = [];
  bool _communityLoading = true;

  static const _categories = [
    {'label': '전체', 'value': null},
    {'label': 'Q&A', 'value': 'qa'},
    {'label': '건강', 'value': 'health'},
    {'label': '훈련', 'value': 'training'},
    {'label': '먹거리', 'value': 'food'},
    {'label': '생활', 'value': 'life'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(() {
      if (_tabController.index == 2 && _communityPosts.isEmpty) {
        _loadCommunityPosts();
      }
    });

    // initialCategory가 있으면 해당 카테고리를 선택
    if (widget.initialCategory != null) {
      for (int i = 0; i < _categories.length; i++) {
        if (_categories[i]['value'] == widget.initialCategory) {
          _selectedCategory = i;
          break;
        }
      }
    }

    if (widget.initialTab == 2) {
      final cat = _categories[_selectedCategory]['value'];
      _loadCommunityPosts(category: cat);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          // 매거진 태그가 있는 글은 커뮤니티 탭에서 항상 제외
          .not('hashtags', 'cs', '{"magazine"}');

      if (category != null) {
        // 특정 카테고리: 해당 태그가 반드시 포함된 글만
        query = query.contains('hashtags', [category]);
      }
      // 전체: 매거진 제외된 모든 글 표시 (community 태그 강제 안함)

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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: const ChannelSubscriptionPage(),
                ),
              ),
            ),
            tooltip: '채널 구독',
          ),
          IconButton(
            icon: SvgPicture.asset('assets/svg/icon_search.svg', width: 24, height: 24, colorFilter: const ColorFilter.mode(Colors.black87, BlendMode.srcIn)),
            onPressed: () => context.push('/search'),
            tooltip: '검색',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(68.h),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.subtleBackground,
                borderRadius: BorderRadius.circular(30.r),
              ),
              padding: EdgeInsets.all(3.w),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.secondaryTextColor,
                labelStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
                unselectedLabelStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500),
                indicator: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(26.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '추천'),
                  Tab(text: '팔로잉'),
                  Tab(text: '커뮤니티'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeedTab(),
          _buildFollowingTab(),
          _buildCommunityTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onFabPressed(context),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Future<void> _onFabPressed(BuildContext context) async {
    final picked = await PostTypePickerSheet.show(context);
    if (picked == null || !mounted) return;
    if (picked == PostType.text) {
      final created = await Navigator.of(this.context).push<bool>(
        MaterialPageRoute(builder: (_) => const CreateCommunityPostPage()),
      );
      if (created == true && mounted) {
        final cat = _categories[_selectedCategory]['value'];
        _loadCommunityPosts(category: cat);
        _tabController.animateTo(2);
      }
    } else {
      if (!mounted) return;
      this.context.push('/create-post');
    }
  }

  Widget _buildFeedTab() {
    return const FeedPage();
  }

  Widget _buildFollowingTab() {
    return const FeedPage(followingOnly: true);
  }

  Widget _buildCommunityTab() {
    return Column(
      children: [
        // 카테고리 버튼
        Container(
          height: 48.h,
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              final isSelected = _selectedCategory == index;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedCategory = index);
                  final cat = _categories[index]['value'];
                  _loadCommunityPosts(category: cat);
                },
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    border: isSelected
                        ? null
                        : Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Text(
                    _categories[index]['label'] as String,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.secondaryTextColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // 게시글 리스트
        Expanded(
          child: _communityLoading
              ? const Center(child: CircularProgressIndicator())
              : _communityPosts.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: () async {
                        final cat = _categories[_selectedCategory]['value'];
                        await _loadCommunityPosts(category: cat);
                      },
                      child: ListView.builder(
                        padding: EdgeInsets.all(16.w),
                        itemCount: _communityPosts.length,
                        itemBuilder: (context, index) {
                          final post = _communityPosts[index];
                          final user = post['users'] as Map<String, dynamic>?;
                          final hashtags =
                              List<String>.from(post['hashtags'] ?? []);
                          final displayName =
                              user?['display_name'] as String? ?? '익명';
                          return GestureDetector(
                            onTap: () => context.push('/post/${post['id']}'),
                            child: CommunityPostCard(
                              authorName: displayName,
                              category: _categoryFromHashtags(hashtags),
                              title: '',
                              content: post['caption'] as String? ?? '',
                              likes: post['likes_count'] as int? ?? 0,
                              comments: post['comments_count'] as int? ?? 0,
                              timeAgo:
                                  _timeAgo(post['created_at'] as String? ?? ''),
                              isAdmin: displayName == '관리자',
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
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
