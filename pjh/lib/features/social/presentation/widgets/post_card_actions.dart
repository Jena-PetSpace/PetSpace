part of 'post_card.dart';

extension _PostCardActions on _PostCardState {
  Future<void> _handleBookmarkTap() async {
    if (widget.currentUserId.isEmpty || _isSavePending) return;
    if (_isSaved) {
      await _showSavedMenu();
    } else {
      await _savePost();
    }
  }

  Future<void> _savePost() async {
    if (_isSavePending) return;
    final postId = post.id;
    final userId = widget.currentUserId;
    final notifier = savedPostsNotifier;
    setState(() => _isSavePending = true);
    final result = await socialRepository.savePost(postId, userId);
    if (result.isLeft()) {
      if (!mounted || post.id != postId) return;
      setState(() {
        _isSavePending = false;
        _isSaved = false;
      });
      _showSaveFailure('게시물을 저장하지 못했어요. 잠시 후 다시 시도해주세요.');
      return;
    }

    notifier.publish(
      type: SavedPostsChangeType.saved,
      postId: postId,
      wasSaved: false,
      isSaved: true,
      newCollectionId: null,
    );
    if (!mounted || post.id != postId) return;
    setState(() {
      _isSavePending = false;
      _isSaved = true;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('게시물을 저장했어요'),
          action: SnackBarAction(
            label: '컬렉션 선택',
            onPressed: _openCollectionPicker,
          ),
        ),
      );
  }

  Future<void> _unsavePost() async {
    if (_isSavePending) return;
    final postId = post.id;
    final userId = widget.currentUserId;
    final notifier = savedPostsNotifier;
    setState(() => _isSavePending = true);
    final locationResult = await socialRepository.getSavedPostLocation(
      postId: postId,
      userId: userId,
    );
    if (locationResult.isLeft()) {
      if (!mounted || post.id != postId) return;
      setState(() => _isSavePending = false);
      _showSaveFailure('저장 위치를 확인하지 못했어요. 잠시 후 다시 시도해주세요.');
      return;
    }
    final location = locationResult.fold<SavedPostLocation?>(
      (_) => null,
      (value) => value,
    );
    if (location == null) {
      if (!mounted || post.id != postId) return;
      setState(() {
        _isSavePending = false;
        _isSaved = false;
      });
      return;
    }

    final result = await socialRepository.unsavePost(postId, userId);
    if (result.isLeft()) {
      if (!mounted || post.id != postId) return;
      setState(() {
        _isSavePending = false;
        _isSaved = true;
      });
      _showSaveFailure('저장 취소를 반영하지 못했어요. 잠시 후 다시 시도해주세요.');
      return;
    }

    notifier.publish(
      type: SavedPostsChangeType.unsaved,
      postId: postId,
      wasSaved: true,
      isSaved: false,
      oldCollectionId: location.collectionId,
    );
    if (!mounted || post.id != postId) return;
    setState(() {
      _isSavePending = false;
      _isSaved = false;
    });
  }

  Future<void> _showSavedMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('post_card_change_collection'),
              minVerticalPadding: 10,
              leading: const Icon(Icons.folder_outlined),
              title: const Text('컬렉션 변경'),
              onTap: () => Navigator.pop(sheetContext, 'collection'),
            ),
            ListTile(
              key: const Key('post_card_unsave'),
              minVerticalPadding: 10,
              leading: const Icon(Icons.bookmark_remove_outlined),
              title: const Text('저장 취소'),
              onTap: () => Navigator.pop(sheetContext, 'unsave'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'collection') {
      await _openCollectionPicker();
    } else if (action == 'unsave') {
      await _unsavePost();
    }
  }

  Future<void> _openCollectionPicker() async {
    if (!_isSaved || _isSavePending || !mounted) return;
    await CollectionPickerSheet.show(
      context,
      postId: post.id,
      userId: widget.currentUserId,
      repository: socialRepository,
      changeNotifier: savedPostsNotifier,
    );
  }

  void _showSaveFailure(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  Widget _buildActions() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: post.isLikedByCurrentUser ? '좋아요 취소' : '좋아요',
                    button: true,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: InkWell(
                        key: const Key('post_card_like_button'),
                        onTap: () {
                          _likeDebounce?.cancel();
                          _likeDebounce = Timer(
                            const Duration(milliseconds: 300),
                            () {
                              if (mounted) widget.onLike();
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(22.r),
                        child: Center(
                          child: Icon(
                            post.isLikedByCurrentUser
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: post.isLikedByCurrentUser
                                ? AppTheme.errorColor
                                : null,
                            size: 20.w,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    label: '좋아요 ${post.likesCount}명 보기',
                    button: true,
                    child: SizedBox(
                      height: 44,
                      child: InkWell(
                        key: const Key('post_card_likes_count'),
                        onTap: () => LikesBottomSheet.show(
                          context,
                          postId: post.id,
                          currentUserId: currentUserId,
                          likeCount: post.likesCount,
                          repository: socialRepository,
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          child: Center(
                            child: Text(
                              '${post.likesCount}',
                              style: TextStyle(fontSize: 12.sp),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 8.w),
              Semantics(
                label: '댓글 ${post.commentsCount}개 보기',
                button: true,
                child: SizedBox(
                  height: 44,
                  child: InkWell(
                    key: const Key('post_card_comment_button'),
                    onTap: widget.onComment,
                    borderRadius: BorderRadius.circular(22.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.comment_outlined, size: 20.w),
                          SizedBox(width: 4.w),
                          Text(
                            '${post.commentsCount}',
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              Semantics(
                label: '게시글 공유',
                button: true,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: InkWell(
                    key: const Key('post_card_share_button'),
                    onTap: widget.onShare,
                    borderRadius: BorderRadius.circular(22.r),
                    child: Center(
                      child: Icon(Icons.share_outlined, size: 20.w),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Semantics(
                label: _isSaved ? '저장 옵션' : '게시글 저장',
                button: true,
                enabled: !_isSavePending,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: InkWell(
                    key: const Key('post_card_bookmark_button'),
                    onTap: _handleBookmarkTap,
                    borderRadius: BorderRadius.circular(22.r),
                    child: Center(
                      child: _isSavePending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _isSaved
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_outlined,
                              size: 22.w,
                              color: _isSaved
                                  ? AppTheme.primaryColor
                                  : AppTheme.secondaryTextColor,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // 좌표가 있을 때만 위치 탐색 액션을 제공한다. 좌표가 없는 장소명은
          // 헤더 메타데이터에 이미 표시되므로 동일 문구를 두 번 노출하지 않는다.
          if (post.location?.trim().isNotEmpty == true &&
              post.locationLat != null &&
              post.locationLng != null) ...[
            SizedBox(height: 4.h),
            Semantics(
              label: '위치 ${post.location} 게시물 보기',
              button: true,
              child: SizedBox(
                height: 44,
                child: InkWell(
                  key: const Key('post_card_location_button'),
                  onTap: () => context.push(
                    '/location',
                    extra: {
                      'lat': post.locationLat,
                      'lng': post.locationLng,
                      'locationName': post.location,
                    },
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18.w,
                        color: AppTheme.primaryColor,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          post.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
