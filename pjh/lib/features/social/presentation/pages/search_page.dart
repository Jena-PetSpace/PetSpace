import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/social_user.dart';
import '../bloc/search_bloc.dart';
import '../widgets/post_card.dart';
import '../../../../config/injection_container.dart' as di;

class SearchPage extends StatefulWidget {
  final String? initialHashtag;
  final String? initialQuery;

  const SearchPage({
    super.key,
    this.initialHashtag,
    this.initialQuery,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  late SearchBloc _searchBloc;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchBloc = di.sl<SearchBloc>();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // initialHashtag이 있으면 해시태그로 검색
    if (widget.initialHashtag != null) {
      _searchController.text = '#${widget.initialHashtag}';
      _searchBloc.add(SearchPostsByHashtagRequested(hashtag: widget.initialHashtag!));
    }
    // initialQuery가 있으면 해당 쿼리로 검색
    else if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
    // 아무것도 없으면 트렌딩 해시태그 로드
    else {
      _searchBloc.add(const GetTrendingHashtagsRequested());
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchBloc.close();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;

    final currentTab = _tabController.index;

    if (currentTab == 0) {
      // 게시물 탭
      if (query.startsWith('#')) {
        final hashtag = query.substring(1);
        _searchBloc.add(SearchPostsByHashtagRequested(hashtag: hashtag));
      } else {
        _searchBloc.add(SearchPostsRequested(query: query));
      }
    } else if (currentTab == 1) {
      // 해시태그 탭
      _searchBloc.add(const GetPopularHashtagsRequested(limit: 50));
    } else {
      // 사용자 탭
      _searchBloc.add(SearchUsersRequested(query: query));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _searchBloc,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: TextField(
            controller: _searchController,
            style: TextStyle(fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: '게시물, 해시태그, 사용자 검색',
              hintStyle: TextStyle(fontSize: 14.sp),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchBloc.add(const ClearSearchRequested());
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24.r),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 12.h,
              ),
            ),
            onChanged: (value) => setState(() {}),
            onSubmitted: _performSearch,
          ),
        ),
        body: Column(
          children: [
            // 탭 바
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.primaryColor,
                tabs: const [
                  Tab(text: '게시물'),
                  Tab(text: '해시태그'),
                  Tab(text: '사용자'),
                ],
                onTap: (index) {
                  if (_searchController.text.isNotEmpty) {
                    _performSearch(_searchController.text);
                  }
                },
              ),
            ),

            // 탭 뷰
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPostsTab(),
                  _buildHashtagsTab(),
                  _buildUsersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsTab() {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        if (state is SearchLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is SearchError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60.w, color: Colors.grey[400]),
                SizedBox(height: 16.h),
                Text(
                  state.message,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (state is PostSearchSuccess) {
          if (state.posts.isEmpty) {
            return _buildEmptyState('검색 결과가 없습니다');
          }

          return ListView.builder(
            itemCount: state.posts.length,
            itemBuilder: (context, index) {
              return PostCard(
                post: state.posts[index],
                currentUserId: _currentUserId ?? '',
                onLike: () {},
                onComment: () {},
                onShare: () {},
                onHashtagTap: (hashtag) {
                  // 게시물 탭으로 이동하고 해시태그로 검색
                  _tabController.animateTo(0);
                  _searchController.text = '#$hashtag';
                  _searchBloc.add(SearchPostsByHashtagRequested(hashtag: hashtag));
                },
              );
            },
          );
        }

        if (state is SearchSuccess && state.posts.isNotEmpty) {
          return ListView.builder(
            itemCount: state.posts.length,
            itemBuilder: (context, index) {
              return PostCard(
                post: state.posts[index],
                currentUserId: _currentUserId ?? '',
                onLike: () {},
                onComment: () {},
                onShare: () {},
                onHashtagTap: (hashtag) {
                  // 게시물 탭으로 이동하고 해시태그로 검색
                  _tabController.animateTo(0);
                  _searchController.text = '#$hashtag';
                  _searchBloc.add(SearchPostsByHashtagRequested(hashtag: hashtag));
                },
              );
            },
          );
        }

        return _buildEmptyState('검색어를 입력해주세요');
      },
    );
  }

  Widget _buildHashtagsTab() {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        if (state is SearchLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is SearchError) {
          return Center(
            child: Text(
              state.message,
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        List<String> hashtags = [];
        bool isTrending = false;

        if (state is HashtagsLoaded) {
          hashtags = state.hashtags;
          isTrending = state.isTrending;
        } else if (state is SearchSuccess) {
          hashtags = state.hashtags;
        }

        if (hashtags.isEmpty) {
          return _buildEmptyState('해시태그가 없습니다');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                isTrending ? '🔥 트렌딩 해시태그' : '💫 인기 해시태그',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                ),
                itemCount: hashtags.length,
                itemBuilder: (context, index) {
                  final hashtag = hashtags[index];
                  return _buildHashtagCard(hashtag, index + 1);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHashtagCard(String hashtag, int rank) {
    return InkWell(
      onTap: () {
        // 해시태그 클릭 시 해당 해시태그로 게시물 검색
        _tabController.animateTo(0); // 게시물 탭으로 이동
        _searchController.text = '#$hashtag';
        _searchBloc.add(SearchPostsByHashtagRequested(hashtag: hashtag));
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: rank <= 3 ? AppTheme.primaryColor : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: rank <= 3 ? Colors.white : Colors.grey[700],
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                '#$hashtag',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        if (state is SearchLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is SearchError) {
          return Center(
            child: Text(
              state.message,
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        List<SocialUser> users = [];

        if (state is UserSearchSuccess) {
          users = state.users;
        } else if (state is SearchSuccess) {
          users = state.users;
        }

        if (users.isEmpty) {
          return _buildEmptyState('검색어를 입력해주세요');
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildUserCard(user);
          },
        );
      },
    );
  }

  Widget _buildUserCard(SocialUser user) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20.r,
        backgroundImage: user.profileImageUrl != null
            ? NetworkImage(user.profileImageUrl!)
            : null,
        child: user.profileImageUrl == null
            ? Text(user.displayName[0].toUpperCase(), style: TextStyle(fontSize: 16.sp))
            : null,
      ),
      title: Text(
        user.displayName,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
      ),
      subtitle: user.bio != null ? Text(user.bio!, style: TextStyle(fontSize: 12.sp)) : null,
      trailing: Icon(Icons.chevron_right, size: 20.w),
      onTap: () {
        // 사용자 프로필로 이동
        context.push('/user-profile/${user.id}');
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80.w, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
