import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/follow.dart';
import '../../domain/repositories/social_repository.dart';
import '../widgets/user_list_tile.dart';

class FollowersPage extends StatefulWidget {
  final String userId;
  final String userName;
  final int initialTab;
  final SocialRepository? repository;
  final Duration searchDebounce;

  const FollowersPage({
    super.key,
    required this.userId,
    required this.userName,
    this.initialTab = 0,
    this.repository,
    this.searchDebounce = const Duration(milliseconds: 300),
  });

  @override
  State<FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage>
    with SingleTickerProviderStateMixin {
  static const _pageSize = 20;

  late final TabController _tabController;
  late final SocialRepository _repository;
  final _searchController = TextEditingController();
  final _followers = _FollowTabData();
  final _following = _FollowTabData();
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1).toInt(),
    )..addListener(_handleTabChanged);
    _repository = widget.repository ?? di.sl<SocialRepository>();
    _load(isFollowers: true, reset: true);
    _load(isFollowers: false, reset: true);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  String get _query =>
      _searchController.text.trim().replaceFirst(RegExp(r'^@+'), '');

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    final isFollowers = _tabController.index == 0;
    final data = isFollowers ? _followers : _following;
    if (!data.initialized || data.loadedQuery != _query) {
      _load(isFollowers: isFollowers, reset: true);
    }
  }

  void _handleSearchChanged(String _) {
    setState(() {});
    _searchTimer?.cancel();
    _searchTimer = Timer(widget.searchDebounce, () {
      if (!mounted) return;
      _load(isFollowers: _tabController.index == 0, reset: true);
    });
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) return;
    _searchController.clear();
    _searchTimer?.cancel();
    _load(isFollowers: _tabController.index == 0, reset: true);
  }

  Future<void> _load({required bool isFollowers, required bool reset}) async {
    final data = isFollowers ? _followers : _following;
    final requestedQuery = _query;
    if (!reset && (data.isLoadingMore || !data.hasMore)) return;

    final requestToken = ++data.requestToken;
    if (reset) {
      setState(() {
        data
          ..items = []
          ..isLoadingInitial = true
          ..isLoadingMore = false
          ..hasMore = true
          ..firstLoadError = false
          ..loadMoreError = false
          ..loadedQuery = requestedQuery;
      });
    } else {
      setState(() {
        data
          ..isLoadingMore = true
          ..loadMoreError = false;
      });
    }

    final lastUserId = reset || data.items.isEmpty
        ? null
        : _userId(data.items.last, isFollowers);
    final result = isFollowers
        ? await _repository.getFollowersPage(
            userId: widget.userId,
            limit: _pageSize,
            lastUserId: lastUserId,
            query: requestedQuery,
          )
        : await _repository.getFollowingPage(
            userId: widget.userId,
            limit: _pageSize,
            lastUserId: lastUserId,
            query: requestedQuery,
          );

    if (!mounted || requestToken != data.requestToken) return;
    result.fold(
      (_) {
        setState(() {
          data
            ..isLoadingInitial = false
            ..isLoadingMore = false;
          if (reset) {
            data.firstLoadError = true;
          } else {
            data.loadMoreError = true;
          }
        });
      },
      (page) {
        final nextItems = reset ? <Follow>[] : List<Follow>.from(data.items);
        final seen = nextItems
            .map((follow) => _userId(follow, isFollowers))
            .toSet();
        for (final follow in page) {
          if (seen.add(_userId(follow, isFollowers))) {
            nextItems.add(follow);
          }
        }
        setState(() {
          data
            ..items = nextItems
            ..initialized = true
            ..loadedQuery = requestedQuery
            ..isLoadingInitial = false
            ..isLoadingMore = false
            ..firstLoadError = false
            ..loadMoreError = false
            ..hasMore = page.length == _pageSize;
        });
      },
    );
  }

  String _userId(Follow follow, bool isFollowers) =>
      isFollowers ? follow.followerId : follow.followingId;

  String _userName(Follow follow, bool isFollowers) =>
      isFollowers ? follow.followerName : follow.followingName;

  String? _username(Follow follow, bool isFollowers) =>
      isFollowers ? follow.followerUsername : follow.followingUsername;

  String? _profileImage(Follow follow, bool isFollowers) =>
      isFollowers ? follow.followerProfileImage : follow.followingProfileImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('팔로워 · 팔로잉'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryTextColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 12.h),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.secondaryTextColor,
                  indicatorColor: AppTheme.primaryColor,
                  tabs: const [
                    Tab(text: '팔로워'),
                    Tab(text: '팔로잉'),
                  ],
                ),
                SizedBox(height: 12.h),
                TextField(
                  key: const Key('follow_search_field'),
                  controller: _searchController,
                  onChanged: _handleSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '이름 또는 사용자 아이디 검색',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '검색어 지우기',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: AppTheme.subtleBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(isFollowers: true),
                _buildList(isFollowers: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList({required bool isFollowers}) {
    final data = isFollowers ? _followers : _following;
    if (data.isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data.firstLoadError) {
      return _FollowStateView(
        key: Key(isFollowers ? 'followers_error' : 'following_error'),
        icon: Icons.cloud_off_outlined,
        title: '목록을 불러오지 못했어요',
        description: '연결 상태를 확인하고 다시 시도해주세요.',
        actionLabel: '다시 시도',
        onAction: () => _load(isFollowers: isFollowers, reset: true),
      );
    }
    if (data.items.isEmpty) {
      final hasQuery = data.loadedQuery.isNotEmpty;
      return _FollowStateView(
        key: Key(isFollowers ? 'followers_empty' : 'following_empty'),
        icon: hasQuery ? Icons.search_off : Icons.people_outline,
        title: hasQuery
            ? '검색 결과가 없어요'
            : isFollowers
            ? '아직 팔로워가 없어요'
            : '아직 팔로잉이 없어요',
        description: hasQuery
            ? '다른 이름이나 사용자 아이디로 검색해보세요.'
            : isFollowers
            ? '새로운 팔로워가 생기면 여기에 표시됩니다.'
            : '관심 있는 사용자를 팔로우하면 여기에 표시됩니다.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(isFollowers: isFollowers, reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 240.h) {
            _load(isFollowers: isFollowers, reset: false);
          }
          return false;
        },
        child: ListView.builder(
          key: Key(isFollowers ? 'followers_list' : 'following_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(vertical: 8.h),
          itemCount: data.items.length + 1,
          itemBuilder: (context, index) {
            if (index == data.items.length) {
              return _buildListFooter(data, isFollowers);
            }
            final follow = data.items[index];
            final username = _username(follow, isFollowers)?.trim();
            return UserListTile(
              userId: _userId(follow, isFollowers),
              userName: _userName(follow, isFollowers),
              userProfileImage: _profileImage(follow, isFollowers),
              subtitle: username == null || username.isEmpty
                  ? null
                  : '@$username',
              onTap: () =>
                  context.push('/user-profile/${_userId(follow, isFollowers)}'),
            );
          },
        ),
      ),
    );
  }

  Widget _buildListFooter(_FollowTabData data, bool isFollowers) {
    if (data.isLoadingMore) {
      return Padding(
        padding: EdgeInsets.all(16.h),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (data.loadMoreError) {
      return Center(
        child: TextButton.icon(
          key: Key(
            isFollowers
                ? 'followers_load_more_retry'
                : 'following_load_more_retry',
          ),
          onPressed: () => _load(isFollowers: isFollowers, reset: false),
          icon: const Icon(Icons.refresh),
          label: const Text('더 불러오기'),
        ),
      );
    }
    return SizedBox(height: 16.h);
  }
}

class _FollowTabData {
  List<Follow> items = [];
  bool initialized = false;
  bool isLoadingInitial = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  bool firstLoadError = false;
  bool loadMoreError = false;
  String loadedQuery = '';
  int requestToken = 0;
}

class _FollowStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _FollowStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44.w, color: AppTheme.lightTextColor),
            SizedBox(height: 14.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.45,
                color: AppTheme.secondaryTextColor,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 16.h),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
