import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:go_router/go_router.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../social/presentation/pages/feed_page.dart';
import '../widgets/community_post_card.dart';
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
    {'label': '매거진', 'value': 'magazine'},
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
          .isFilter('deleted_at', null);

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
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
            tooltip: '검색',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.secondaryTextColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: '추천'),
            Tab(text: '팔로잉'),
            Tab(text: '커뮤니티'),
          ],
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
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          if (_tabController.index != 2) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                    builder: (_) => const CreateCommunityPostPage()),
              );
              if (created == true) {
                final cat = _categories[_selectedCategory]['value'];
                _loadCommunityPosts(category: cat);
              }
            },
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.edit, color: Colors.white),
          );
        },
      ),
    );
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
                          return GestureDetector(
                            onTap: () => context.push('/post/${post['id']}'),
                            child: CommunityPostCard(
                              authorName:
                                  user?['display_name'] as String? ?? '익명',
                              category: _categoryFromHashtags(hashtags),
                              title: '',
                              content: post['caption'] as String? ?? '',
                              likes: post['likes_count'] as int? ?? 0,
                              comments: post['comments_count'] as int? ?? 0,
                              timeAgo:
                                  _timeAgo(post['created_at'] as String? ?? ''),
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
