part of 'post_card.dart';

extension _PostCardActions on _PostCardState {
  Future<void> _toggleSave() async {
    if (widget.currentUserId.isEmpty) return;
    final prev = _isSaved;
    setState(() => _isSaved = !_isSaved);
    final repo = sl<SocialRepository>();
    final result = prev
        ? await repo.unsavePost(post.id, widget.currentUserId)
        : await repo.savePost(post.id, widget.currentUserId);
    result.fold(
      (failure) {
        dev.log('북마크 토글 실패: ${failure.message}', name: 'PostCard');
        if (mounted) setState(() => _isSaved = prev);
      },
      (_) {
        if (!prev && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('저장되었습니다 🔖'),
              backgroundColor: AppTheme.primaryColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: post.isLikedByCurrentUser ? '좋아요 취소' : '좋아요',
                button: true,
                child: InkWell(
                  onTap: () {
                    _likeDebounce?.cancel();
                    _likeDebounce = Timer(const Duration(milliseconds: 300), () {
                      if (mounted) widget.onLike();
                    });
                  },
                  borderRadius: BorderRadius.circular(20.r),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    child: Icon(
                      post.isLikedByCurrentUser
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: post.isLikedByCurrentUser ? AppTheme.highlightColor : null,
                      size: 20.w,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: post.likesCount > 0
                    ? () => LikesBottomSheet.show(
                          context,
                          postId: post.id,
                          currentUserId: currentUserId,
                        )
                    : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                  child: Text(
                    '${post.likesCount}',
                    style: TextStyle(fontSize: 12.sp),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 16.w),
          Semantics(
            label: '댓글 ${post.commentsCount}개 보기',
            button: true,
            child: InkWell(
              onTap: widget.onComment,
              borderRadius: BorderRadius.circular(20.r),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
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
          SizedBox(width: 16.w),
          InkWell(
            onTap: widget.onShare,
            borderRadius: BorderRadius.circular(20.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              child: Icon(Icons.share_outlined, size: 20.w),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 44.w,
            height: 44.w,
            child: GestureDetector(
              onTap: _toggleSave,
              onLongPress: () {
                if (widget.currentUserId.isEmpty) return;
                CollectionPickerSheet.show(
                  context,
                  postId: post.id,
                  userId: widget.currentUserId,
                );
              },
              child: Icon(
                _isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_outlined,
                size: 22.w,
                color: _isSaved ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
              ),
            ),
          ),
          if (post.location != null)
            GestureDetector(
              onTap: (post.locationLat != null && post.locationLng != null)
                  ? () => context.push('/location', extra: {
                        'lat': post.locationLat,
                        'lng': post.locationLng,
                        'locationName': post.location,
                      })
                  : null,
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 16.w,
                      color: (post.locationLat != null && post.locationLng != null)
                          ? AppTheme.primaryColor
                          : AppTheme.neutral500),
                  SizedBox(width: 4.w),
                  Text(
                    post.location!,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: (post.locationLat != null && post.locationLng != null)
                          ? AppTheme.primaryColor
                          : AppTheme.neutral500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
