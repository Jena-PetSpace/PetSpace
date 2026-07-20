import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../social/domain/entities/post.dart';
import '../../../social/domain/entities/saved_posts_page.dart';
import '../../../social/domain/repositories/social_repository.dart';
import '../../../social/presentation/utils/saved_posts_change_notifier.dart';

class SavedPostsGrid extends StatefulWidget {
  final SocialRepository repository;
  final String userId;
  final SavedPostsScope scope;
  final Widget? header;
  final ValueChanged<int>? onCountChanged;
  final VoidCallback? onCountError;
  final SavedPostsChangeNotifier? changeNotifier;

  const SavedPostsGrid({
    super.key,
    required this.repository,
    required this.userId,
    required this.scope,
    this.header,
    this.onCountChanged,
    this.onCountError,
    this.changeNotifier,
  });

  @override
  State<SavedPostsGrid> createState() => _SavedPostsGridState();
}

class _SavedPostsGridState extends State<SavedPostsGrid>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 30;
  final ScrollController _scrollController = ScrollController();
  final List<SavedPostItem> _items = [];
  SavedPostsCursor? _cursor;
  int _generation = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _moreError;
  int? _visibleCount;

  SavedPostsChangeNotifier get _notifier =>
      widget.changeNotifier ?? SavedPostsChangeNotifier.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _notifier.addListener(_onSavedPostsChanged);
    _loadInitial();
  }

  @override
  void didUpdateWidget(covariant SavedPostsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNotifier =
        oldWidget.changeNotifier ?? SavedPostsChangeNotifier.instance;
    if (oldNotifier != _notifier) {
      oldNotifier.removeListener(_onSavedPostsChanged);
      _notifier.addListener(_onSavedPostsChanged);
    }
    if (oldWidget.userId != widget.userId || oldWidget.scope != widget.scope) {
      _loadInitial();
    }
  }

  @override
  void dispose() {
    _notifier.removeListener(_onSavedPostsChanged);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 360) _loadMore();
  }

  Future<void> _onSavedPostsChanged() async {
    final change = _notifier.lastChange;
    if (change == null) return;
    final index = _items.indexWhere((item) => item.post.id == change.postId);
    final wasInScope = _containsCollection(change.oldCollectionId);
    final isInScope =
        change.isSaved && _containsCollection(change.newCollectionId);

    if (index >= 0 && !isInScope) {
      setState(() {
        _items.removeAt(index);
        if (_visibleCount != null) {
          _visibleCount = math.max(0, _visibleCount! - 1);
        }
      });
      if (_visibleCount != null) widget.onCountChanged?.call(_visibleCount!);
      return;
    }
    if (index >= 0 && wasInScope && isInScope) {
      final current = _items[index];
      setState(() {
        _items[index] = SavedPostItem(
          savedPostId: current.savedPostId,
          collectionId: change.newCollectionId,
          savedAt: current.savedAt,
          post: current.post,
        );
      });
      return;
    }
    if (!isInScope) return;

    final offset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    await _refreshVisibleWindow();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(
        math.min(offset, _scrollController.position.maxScrollExtent),
      );
    });
  }

  bool _containsCollection(String? collectionId) {
    switch (widget.scope.type) {
      case SavedPostsScopeType.all:
        return true;
      case SavedPostsScopeType.unassigned:
        return collectionId == null;
      case SavedPostsScopeType.collection:
        return collectionId == widget.scope.collectionId;
    }
  }

  Future<void> _refreshVisibleWindow() async {
    final generation = ++_generation;
    final windowSize = math.max(_pageSize, _items.length);
    final pageFuture = widget.repository.getSavedPostsPage(
      userId: widget.userId,
      scope: widget.scope,
      limit: windowSize,
    );
    final countFuture = widget.repository.countSavedPosts(
      userId: widget.userId,
      scope: widget.scope,
    );
    final pageResult = await pageFuture;
    final countResult = await countFuture;
    if (!mounted || generation != _generation) return;
    pageResult.fold(
      (failure) => setState(() => _moreError = failure.message),
      (page) => setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loading = false;
        _error = null;
        _loadingMore = false;
        _moreError = null;
      }),
    );
    countResult.fold((_) => widget.onCountError?.call(), (count) {
      _visibleCount = count;
      widget.onCountChanged?.call(count);
    });
  }

  Future<void> _loadInitial() async {
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _moreError = null;
        _cursor = null;
        _hasMore = true;
      });
    }
    final pageResult = await widget.repository.getSavedPostsPage(
      userId: widget.userId,
      scope: widget.scope,
      limit: _pageSize,
    );
    final countResult = await widget.repository.countSavedPosts(
      userId: widget.userId,
      scope: widget.scope,
    );
    if (!mounted || generation != _generation) return;
    pageResult.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failure.message;
      }),
      (page) {
        setState(() {
          _items
            ..clear()
            ..addAll(page.items);
          _cursor = page.nextCursor;
          _hasMore = page.hasMore;
          _loading = false;
          _error = null;
        });
        countResult.fold((_) => widget.onCountError?.call(), (count) {
          _visibleCount = count;
          widget.onCountChanged?.call(count);
        });
      },
    );
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    final result = await widget.repository.getSavedPostsPage(
      userId: widget.userId,
      scope: widget.scope,
      cursor: _cursor,
      limit: _pageSize,
    );
    if (!mounted || generation != _generation) return;
    result.fold(
      (failure) => setState(() {
        _loadingMore = false;
        _moreError = failure.message;
      }),
      (page) {
        final seen = _items.map((item) => item.savedPostId).toSet();
        setState(() {
          _items.addAll(page.items.where((item) => seen.add(item.savedPostId)));
          _cursor = page.nextCursor;
          _hasMore = page.hasMore;
          _loadingMore = false;
          _moreError = null;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return _withHeader(const Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return _withHeader(
        _GridMessage(
          key: const Key('saved_posts_error'),
          icon: Icons.cloud_off_outlined,
          title: '저장한 게시글을 불러오지 못했어요',
          actionLabel: '다시 시도',
          onAction: _loadInitial,
        ),
      );
    }
    if (_items.isEmpty) {
      return _withHeader(
        _GridMessage(
          key: const Key('saved_posts_empty'),
          icon: Icons.bookmark_outline_rounded,
          title: '저장한 게시글이 없어요',
          subtitle: '마음에 드는 게시글을 저장해두면 여기서 볼 수 있어요.',
          actionLabel: widget.scope.type == SavedPostsScopeType.all
              ? '피드 탐색'
              : null,
          onAction: widget.scope.type == SavedPostsScopeType.all
              ? () => context.go('/feed')
              : null,
        ),
      );
    }

    return CustomScrollView(
      key: PageStorageKey<String>(
        'saved-posts-${widget.scope.type.name}-${widget.scope.collectionId}',
      ),
      controller: _scrollController,
      slivers: [
        if (widget.header != null) SliverToBoxAdapter(child: widget.header),
        SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _SavedPostTile(item: _items[index]),
            childCount: _items.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 1.5,
            crossAxisSpacing: 1.5,
          ),
        ),
        SliverToBoxAdapter(
          child: _moreError != null
              ? TextButton(
                  key: const Key('saved_posts_more_retry'),
                  onPressed: _loadMore,
                  child: const Text('더 불러오기 다시 시도'),
                )
              : _loadingMore
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox(height: 24),
        ),
      ],
    );
  }

  Widget _withHeader(Widget body) {
    if (widget.header == null) return body;
    return Column(
      children: [
        widget.header!,
        Expanded(child: body),
      ],
    );
  }
}

class _SavedPostTile extends StatelessWidget {
  final SavedPostItem item;
  const _SavedPostTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final post = item.post;
    final imageUrl = post.imageUrls.isEmpty ? null : post.imageUrls.first;
    return Semantics(
      button: true,
      label: '${(post.content ?? '').trim()} 게시물 상세 보기'.trim(),
      child: InkWell(
        key: Key('saved_post_${post.id}'),
        onTap: () => context.push('/post/${post.id}'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _TextPreview(post: post),
              )
            else
              _TextPreview(post: post),
            if (post.type == PostType.emotionAnalysis)
              Positioned(
                left: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 3.h,
                    ),
                    child: Text(
                      '감정분석',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            if (post.imageUrls.length > 1)
              const Positioned(
                right: 6,
                top: 6,
                child: Icon(Icons.copy_rounded, size: 16, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

class _TextPreview extends StatelessWidget {
  final Post post;
  const _TextPreview({required this.post});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: Key('saved_post_preview_${post.id}'),
      color: AppTheme.primaryColor.withValues(alpha: .08),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: (post.content ?? '').trim().isEmpty
              ? const Icon(
                  Icons.notes_rounded,
                  size: 26,
                  color: AppTheme.lightTextColor,
                )
              : Text(
                  post.content!.trim(),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    height: 1.4,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
        ),
      ),
    );
  }
}

class _GridMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _GridMessage({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
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
            Icon(icon, size: 52, color: AppTheme.lightTextColor),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
