import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/post_likes_page.dart';
import '../../domain/repositories/social_repository.dart';

class LikesBottomSheet extends StatefulWidget {
  final String postId;
  final String? currentUserId;
  final int? likeCount;
  final SocialRepository? repository;

  const LikesBottomSheet({
    super.key,
    required this.postId,
    this.currentUserId,
    this.likeCount,
    this.repository,
  });

  static void show(
    BuildContext context, {
    required String postId,
    String? currentUserId,
    int? likeCount,
    SocialRepository? repository,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LikesBottomSheet(
        postId: postId,
        currentUserId: currentUserId,
        likeCount: likeCount,
        repository: repository,
      ),
    );
  }

  @override
  State<LikesBottomSheet> createState() => _LikesBottomSheetState();
}

class _LikesBottomSheetState extends State<LikesBottomSheet> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _pendingUserIds = <String>{};
  final List<PostLikeUser> _items = <PostLikeUser>[];

  late final SocialRepository _repository;
  Timer? _searchDebounce;
  PostLikesCursor? _nextCursor;
  bool _hasMore = false;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _initialError;
  String? _loadMoreError;
  int _requestGeneration = 0;

  String get _currentUserId => widget.currentUserId ?? '';
  String get _query =>
      _searchController.text.trim().replaceFirst(RegExp(r'^@+'), '');

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? di.sl<SocialRepository>();
    _searchController.addListener(_onSearchChanged);
    _loadPage(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    if (mounted) setState(() {});
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadPage(reset: true),
    );
  }

  Future<void> _loadPage({required bool reset}) async {
    if (!reset && (!_hasMore || _isLoadingMore)) return;
    final generation = reset ? ++_requestGeneration : _requestGeneration;
    final requestedQuery = _query;

    setState(() {
      if (reset) {
        _isInitialLoading = true;
        _initialError = null;
        _loadMoreError = null;
      } else {
        _isLoadingMore = true;
        _loadMoreError = null;
      }
    });

    final result = await _repository.getPostLikesPage(
      postId: widget.postId,
      currentUserId: _currentUserId,
      cursor: reset ? null : _nextCursor,
      query: requestedQuery,
      limit: _pageSize,
    );
    if (!mounted ||
        generation != _requestGeneration ||
        requestedQuery != _query) {
      return;
    }

    result.fold(
      (_) => setState(() {
        _isInitialLoading = false;
        _isLoadingMore = false;
        if (reset) {
          _initialError = '좋아요 목록을 불러오지 못했어요.';
        } else {
          _loadMoreError = '목록을 더 불러오지 못했어요.';
        }
      }),
      (page) => setState(() {
        if (reset) _items.clear();
        final knownLikeIds = _items.map((item) => item.likeId).toSet();
        _items.addAll(
          page.items.where((item) => knownLikeIds.add(item.likeId)),
        );
        _hasMore = page.hasMore;
        _nextCursor = page.nextCursor;
        _isInitialLoading = false;
        _isLoadingMore = false;
        _initialError = null;
        _loadMoreError = null;
      }),
    );
  }

  Future<void> _toggleFollow(PostLikeUser user) async {
    if (user.relation == PostLikeRelation.self ||
        _currentUserId.isEmpty ||
        _pendingUserIds.contains(user.userId)) {
      return;
    }
    final previous = user.relation;
    final next = previous == PostLikeRelation.following
        ? PostLikeRelation.notFollowing
        : PostLikeRelation.following;
    setState(() {
      _pendingUserIds.add(user.userId);
      _replaceRelation(user.userId, next);
    });

    final result = previous == PostLikeRelation.following
        ? await _repository.unfollowUser(_currentUserId, user.userId)
        : await _repository.followUser(_currentUserId, user.userId);
    if (!mounted) return;
    setState(() {
      _pendingUserIds.remove(user.userId);
      if (result.isLeft()) _replaceRelation(user.userId, previous);
    });
    if (result.isLeft()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('팔로우 상태를 변경하지 못했어요. 잠시 후 다시 시도해주세요.'),
          ),
        );
    }
  }

  void _replaceRelation(String userId, PostLikeRelation relation) {
    final index = _items.indexWhere((item) => item.userId == userId);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(relation: relation);
    }
  }

  void _openProfile(PostLikeUser user) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push('/user-profile/${user.userId}?currentUserId=$_currentUserId');
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.64,
      maxChildSize: 0.92,
      minChildSize: 0.42,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 10.h, bottom: 8.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppTheme.hintColor,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    const SizedBox(width: 52, height: 52),
                    Expanded(
                      child: Text(
                        widget.likeCount == null
                            ? '좋아요'
                            : '좋아요 ${widget.likeCount}',
                        key: const Key('likes_sheet_title'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: IconButton(
                        key: const Key('likes_sheet_close'),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: '좋아요 목록 닫기',
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 12.h),
                child: TextField(
                  key: const Key('likes_search_field'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '이름 또는 사용자 이름 검색',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            key: const Key('likes_search_clear'),
                            tooltip: '검색어 지우기',
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: AppTheme.subtleBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
              const Divider(height: 1, color: AppTheme.dividerColor),
              Expanded(child: _buildContent(scrollController)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_isInitialLoading) {
      return const Center(
        key: Key('likes_initial_loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_initialError != null) {
      return _StatusView(
        key: const Key('likes_initial_error'),
        icon: Icons.cloud_off_outlined,
        message: _initialError!,
        actionLabel: '다시 시도',
        onAction: () => _loadPage(reset: true),
      );
    }
    if (_items.isEmpty) {
      return _StatusView(
        key: Key(_query.isEmpty ? 'likes_empty' : 'likes_search_empty'),
        icon: _query.isEmpty ? Icons.favorite_border : Icons.search_off,
        message: _query.isEmpty ? '아직 좋아요를 누른 사용자가 없어요.' : '검색 결과가 없어요.',
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 160.h) {
          _loadPage(reset: false);
        }
        return false;
      },
      child: ListView.builder(
        key: const Key('likes_list'),
        controller: scrollController,
        padding: EdgeInsets.symmetric(vertical: 6.h),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == _items.length) return _buildListFooter();
          return _buildUserRow(_items[index]);
        },
      ),
    );
  }

  Widget _buildUserRow(PostLikeUser user) {
    final isPending = _pendingUserIds.contains(user.userId);
    return ListTile(
      key: Key('likes_user_${user.userId}'),
      minVerticalPadding: 10.h,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
      leading: CircleAvatar(
        radius: 22.r,
        backgroundColor: AppTheme.tilePastelBlue,
        backgroundImage: user.photoUrl?.isNotEmpty == true
            ? CachedNetworkImageProvider(user.photoUrl!)
            : null,
        child: user.photoUrl?.isNotEmpty == true
            ? null
            : Icon(Icons.pets, color: AppTheme.primaryColor, size: 20.w),
      ),
      title: Text(
        user.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
      ),
      subtitle: user.username?.isNotEmpty == true
          ? Text(
              '@${user.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.secondaryTextColor,
              ),
            )
          : null,
      trailing: _buildRelationButton(user, isPending),
      onTap: () => _openProfile(user),
    );
  }

  Widget _buildRelationButton(PostLikeUser user, bool isPending) {
    if (user.relation == PostLikeRelation.self) {
      return SizedBox(
        width: 72.w,
        height: 44,
        child: const Center(
          child: Text(
            '나',
            style: TextStyle(
              color: AppTheme.secondaryTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    final following = user.relation == PostLikeRelation.following;
    return SizedBox(
      width: 88.w,
      height: 44,
      child: OutlinedButton(
        key: Key('likes_follow_${user.userId}'),
        onPressed: isPending ? null : () => _toggleFollow(user),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: following
              ? AppTheme.primaryColor
              : AppTheme.surfaceColor,
          backgroundColor: following
              ? AppTheme.surfaceColor
              : AppTheme.primaryColor,
          side: const BorderSide(color: AppTheme.primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        child: isPending
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                following ? '팔로잉' : '팔로우',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _buildListFooter() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(
          key: Key('likes_loading_more'),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_loadMoreError != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Center(
          child: TextButton(
            key: const Key('likes_load_more_retry'),
            onPressed: () => _loadPage(reset: false),
            child: const Text('더 불러오기 다시 시도'),
          ),
        ),
      );
    }
    return SizedBox(height: 12.h);
  }
}

class _StatusView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusView({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppTheme.hintColor),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.secondaryTextColor),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
