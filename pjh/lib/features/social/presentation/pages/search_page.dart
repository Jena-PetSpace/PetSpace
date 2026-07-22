import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/social_user.dart';
import '../../domain/repositories/social_repository.dart';
import '../bloc/search_bloc.dart';
import '../widgets/post_card_connector.dart';

class SearchPage extends StatefulWidget {
  final String? initialHashtag;
  final String? initialQuery;
  final CurrentUserIdProvider? currentUserIdProvider;
  final SocialRepository? repository;

  const SearchPage({
    super.key,
    this.initialHashtag,
    this.initialQuery,
    this.currentUserIdProvider,
    this.repository,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _searchController;
  final ScrollController _postsScroll = ScrollController();
  final ScrollController _usersScroll = ScrollController();
  final Set<String> _followPending = <String>{};
  Timer? _debounce;

  SearchBloc get _bloc => context.read<SearchBloc>();
  SocialRepository get _repository =>
      widget.repository ?? di.sl<SocialRepository>();
  CurrentUserIdProvider get _currentUserIdProvider =>
      widget.currentUserIdProvider ?? di.sl<CurrentUserIdProvider>();
  String get _currentUserId => _currentUserIdProvider() ?? '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    final initialHashtag = widget.initialHashtag?.trim();
    final initialQuery = widget.initialQuery?.trim();
    final text = initialHashtag != null && initialHashtag.isNotEmpty
        ? '#$initialHashtag'
        : (initialQuery ?? '');
    _searchController = TextEditingController(text: text);
    _postsScroll.addListener(_onPostsScroll);
    _usersScroll.addListener(_onUsersScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (initialHashtag != null && initialHashtag.isNotEmpty) {
        _tabs.index = 1;
        _bloc.add(SearchPostsByHashtagRequested(hashtag: initialHashtag));
      } else if (initialQuery != null && initialQuery.isNotEmpty) {
        _bloc.add(SearchAllRequested(query: initialQuery));
      } else {
        _bloc.add(const LoadDiscoveryRequested());
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    _searchController.dispose();
    _postsScroll.dispose();
    _usersScroll.dispose();
    super.dispose();
  }

  void _onPostsScroll() {
    if (!_postsScroll.hasClients || _postsScroll.position.extentAfter > 500) {
      return;
    }
    final state = _bloc.state;
    if (state.query.startsWith('#')) {
      _bloc.add(
        SearchPostsByHashtagRequested(
          hashtag: state.query.substring(1),
          loadMore: true,
        ),
      );
    } else {
      _bloc.add(SearchPostsRequested(query: state.query, loadMore: true));
    }
  }

  void _onUsersScroll() {
    if (!_usersScroll.hasClients || _usersScroll.position.extentAfter > 500) {
      return;
    }
    _bloc.add(SearchUsersRequested(query: _bloc.state.query, loadMore: true));
  }

  void _scheduleSearch(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _dispatchSearch(value);
    });
  }

  void _dispatchSearch(String value) {
    if (!mounted) return;
    final query = value.trim();
    if (query.isEmpty) {
      _bloc
        ..add(const ClearSearchRequested())
        ..add(const LoadDiscoveryRequested());
    } else if (query.startsWith('#')) {
      _tabs.animateTo(1);
      _bloc.add(SearchPostsByHashtagRequested(hashtag: query.substring(1)));
    } else {
      _bloc.add(SearchAllRequested(query: query));
    }
  }

  void _selectHashtag(String hashtag) {
    _searchController.text = '#$hashtag';
    _searchController.selection = TextSelection.collapsed(
      offset: _searchController.text.length,
    );
    _tabs.animateTo(1);
    _bloc.add(SearchPostsByHashtagRequested(hashtag: hashtag));
    setState(() {});
  }

  Future<void> _toggleFollow(SocialUser user, bool isFollowing) async {
    final currentUserId = _currentUserId;
    if (currentUserId.isEmpty || !_followPending.add(user.id)) return;
    setState(() {});
    final result = isFollowing
        ? await _repository.unfollowUser(currentUserId, user.id)
        : await _repository.followUser(currentUserId, user.id);
    if (!mounted) return;
    _followPending.remove(user.id);
    result.fold(
      (_) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('팔로우 상태를 변경하지 못했어요.'))),
      (_) => _bloc.add(
        SearchFollowingChanged(userId: user.id, isFollowing: !isFollowing),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.subtleBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: TextField(
          key: const Key('search_query_field'),
          controller: _searchController,
          onChanged: _scheduleSearch,
          onSubmitted: (value) {
            _debounce?.cancel();
            _dispatchSearch(value);
          },
          decoration: InputDecoration(
            hintText: '게시물, 사용자, 해시태그 검색',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '검색어 지우기',
                    onPressed: () {
                      _searchController.clear();
                      _scheduleSearch('');
                    },
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: AppTheme.subtleBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      body: BlocBuilder<SearchBloc, SearchState>(
        builder: (context, state) {
          if (state.query.isEmpty) return _buildDiscovery(state);
          return Column(
            children: [
              Material(
                color: Colors.white,
                child: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppTheme.brandDeep,
                  unselectedLabelColor: AppTheme.secondaryTextColor,
                  indicatorColor: AppTheme.actionBase,
                  tabs: const [
                    Tab(text: '전체'),
                    Tab(text: '게시물'),
                    Tab(text: '사용자'),
                    Tab(text: '해시태그'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _buildAll(state),
                    _buildPosts(state),
                    _buildUsers(state),
                    _buildHashtags(state),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiscovery(SearchState state) {
    if (state.isLoading(SearchSection.discovery) &&
        state.discoveryPosts.isEmpty &&
        state.discoveryHashtags.isEmpty) {
      return const SearchShimmerLoading();
    }
    if (state.errorFor(SearchSection.discovery) != null &&
        state.discoveryPosts.isEmpty &&
        state.discoveryHashtags.isEmpty) {
      return _errorState(
        state.errorFor(SearchSection.discovery)!,
        () => _bloc.add(const LoadDiscoveryRequested()),
      );
    }
    return ListView(
      key: const Key('search_discovery'),
      padding: EdgeInsets.symmetric(vertical: 16.h),
      children: [
        if (state.discoveryHashtags.isNotEmpty) ...[
          _sectionTitle('지금 많이 보는 주제'),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: state.discoveryHashtags
                  .map(
                    (tag) => ActionChip(
                      label: Text('#$tag'),
                      onPressed: () => _selectHashtag(tag),
                    ),
                  )
                  .toList(),
            ),
          ),
          SizedBox(height: 20.h),
        ],
        if (state.discoveryPosts.isNotEmpty) ...[
          _sectionTitle('추천 게시물'),
          ...state.discoveryPosts.map(_postConnector),
        ],
        if (state.discoveryPosts.isEmpty && state.discoveryHashtags.isEmpty)
          const EmptyStateWidget(
            icon: Icons.explore_outlined,
            title: '추천 항목을 준비하고 있어요',
            subtitle: '검색어를 입력해 다른 반려동물 이야기를 찾아보세요.',
          ),
      ],
    );
  }

  Widget _buildAll(SearchState state) {
    if (state.isLoading(SearchSection.all)) {
      return const SearchShimmerLoading();
    }
    if (state.errorFor(SearchSection.all) != null) {
      return _errorState(
        state.errorFor(SearchSection.all)!,
        () => _bloc.add(SearchAllRequested(query: state.query)),
      );
    }
    final hasSectionError = [
      SearchSection.posts,
      SearchSection.users,
      SearchSection.hashtags,
    ].any((section) => state.errorFor(section) != null);
    if (state.posts.isEmpty &&
        state.users.isEmpty &&
        state.hashtags.isEmpty &&
        !hasSectionError) {
      return _emptySearch();
    }
    return ListView(
      key: const Key('search_all_results'),
      padding: EdgeInsets.symmetric(vertical: 12.h),
      children: [
        if (state.errorFor(SearchSection.users) != null)
          _inlineSectionError(
            key: const Key('search_all_users_error'),
            label: '사용자',
            message: state.errorFor(SearchSection.users)!,
            onRetry: () => _bloc.add(SearchAllRequested(query: state.query)),
          ),
        if (state.users.isNotEmpty) ...[
          _sectionTitle('사용자'),
          ...state.users
              .take(3)
              .map(
                (user) => _userTile(user, state.followingIds.contains(user.id)),
              ),
        ],
        if (state.errorFor(SearchSection.hashtags) != null)
          _inlineSectionError(
            key: const Key('search_all_hashtags_error'),
            label: '해시태그',
            message: state.errorFor(SearchSection.hashtags)!,
            onRetry: () => _bloc.add(SearchAllRequested(query: state.query)),
          ),
        if (state.hashtags.isNotEmpty) ...[
          _sectionTitle('해시태그'),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Wrap(
              spacing: 8.w,
              children: state.hashtags
                  .take(8)
                  .map(
                    (tag) => ActionChip(
                      label: Text('#$tag'),
                      onPressed: () => _selectHashtag(tag),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        if (state.errorFor(SearchSection.posts) != null)
          _inlineSectionError(
            key: const Key('search_all_posts_error'),
            label: '게시물',
            message: state.errorFor(SearchSection.posts)!,
            onRetry: () => _bloc.add(SearchAllRequested(query: state.query)),
          ),
        if (state.posts.isNotEmpty) ...[
          _sectionTitle('게시물'),
          ...state.posts.take(5).map(_postConnector),
        ],
      ],
    );
  }

  Widget _inlineSectionError({
    required Key key,
    required String label,
    required String message,
    required VoidCallback onRetry,
  }) {
    return Padding(
      key: key,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label · $message',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }

  Widget _buildPosts(SearchState state) {
    if (state.isLoading(SearchSection.posts) && state.posts.isEmpty) {
      return const SearchShimmerLoading();
    }
    if (state.errorFor(SearchSection.posts) != null && state.posts.isEmpty) {
      return _errorState(
        state.errorFor(SearchSection.posts)!,
        () => state.query.startsWith('#')
            ? _bloc.add(
                SearchPostsByHashtagRequested(
                  hashtag: state.query.substring(1),
                ),
              )
            : _bloc.add(SearchAllRequested(query: state.query)),
      );
    }
    if (state.posts.isEmpty) return _emptySearch();
    return ListView.builder(
      key: const Key('search_post_results'),
      controller: _postsScroll,
      itemCount: state.posts.length + 1,
      itemBuilder: (context, index) {
        if (index < state.posts.length) {
          return _postConnector(state.posts[index]);
        }
        return _loadMoreFooter(state, SearchSection.posts, _onPostsScroll);
      },
    );
  }

  Widget _buildUsers(SearchState state) {
    if (state.isLoading(SearchSection.users) && state.users.isEmpty) {
      return const SearchShimmerLoading();
    }
    if (state.errorFor(SearchSection.users) != null && state.users.isEmpty) {
      return _errorState(
        state.errorFor(SearchSection.users)!,
        () => _bloc.add(SearchAllRequested(query: state.query)),
      );
    }
    if (state.users.isEmpty) return _emptySearch();
    return ListView.builder(
      key: const Key('search_user_results'),
      controller: _usersScroll,
      itemCount: state.users.length + 1,
      itemBuilder: (context, index) {
        if (index < state.users.length) {
          final user = state.users[index];
          return _userTile(user, state.followingIds.contains(user.id));
        }
        return _loadMoreFooter(state, SearchSection.users, _onUsersScroll);
      },
    );
  }

  Widget _buildHashtags(SearchState state) {
    if (state.isLoading(SearchSection.hashtags) && state.hashtags.isEmpty) {
      return const SearchShimmerLoading();
    }
    if (state.errorFor(SearchSection.hashtags) != null &&
        state.hashtags.isEmpty) {
      return _errorState(
        state.errorFor(SearchSection.hashtags)!,
        () => _bloc.add(SearchAllRequested(query: state.query)),
      );
    }
    if (state.hashtags.isEmpty) return _emptySearch();
    return ListView.separated(
      key: const Key('search_hashtag_results'),
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: state.hashtags.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final hashtag = state.hashtags[index];
        return ListTile(
          minTileHeight: 56,
          leading: const Icon(Icons.tag),
          title: Text('#$hashtag'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _selectHashtag(hashtag),
        );
      },
    );
  }

  Widget _postConnector(Post post) {
    return PostCardConnector(
      key: ValueKey('search-post-${post.id}'),
      post: post,
      currentUserId: _currentUserId,
      repository: _repository,
      onPostChanged: (updated) => _bloc.add(SearchPostChanged(updated)),
      onPostRemoved: (postId) => _bloc.add(SearchPostRemoved(postId)),
      onHashtagTap: _selectHashtag,
    );
  }

  Widget _userTile(SocialUser user, bool isFollowing) {
    final pending = _followPending.contains(user.id);
    final initial = user.displayName.trim().isEmpty
        ? '?'
        : user.displayName.trim().characters.first.toUpperCase();
    return ListTile(
      minTileHeight: 64,
      leading: CircleAvatar(
        backgroundImage: user.profileImageUrl == null
            ? null
            : NetworkImage(user.profileImageUrl!),
        child: user.profileImageUrl == null ? Text(initial) : null,
      ),
      title: Text(
        user.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: user.bio == null
          ? null
          : Text(user.bio!, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => context.push(
        '/user-profile/${user.id}?currentUserId=$_currentUserId',
      ),
      trailing: _currentUserId.isEmpty
          ? const Icon(Icons.chevron_right)
          : SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: pending
                    ? null
                    : () => _toggleFollow(user, isFollowing),
                child: pending
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isFollowing ? '팔로잉' : '팔로우'),
              ),
            ),
    );
  }

  Widget _loadMoreFooter(
    SearchState state,
    SearchSection section,
    VoidCallback retry,
  ) {
    if (state.isLoadingMore(section)) {
      return Padding(
        padding: EdgeInsets.all(20.h),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final error = state.loadMoreErrorFor(section);
    if (error != null) {
      return Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Text(error, textAlign: TextAlign.center),
            TextButton(onPressed: retry, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    return const SizedBox(height: 24);
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 17.sp,
          fontWeight: FontWeight.w700,
          color: AppTheme.brandDeep,
        ),
      ),
    );
  }

  Widget _emptySearch() {
    return const EmptyStateWidget(
      icon: Icons.search_off,
      title: '검색 결과가 없어요',
      subtitle: '다른 이름이나 키워드로 다시 검색해보세요.',
    );
  }

  Widget _errorState(String message, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48.w, color: AppTheme.errorColor),
            SizedBox(height: 12.h),
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: 12.h),
            FilledButton(onPressed: retry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
