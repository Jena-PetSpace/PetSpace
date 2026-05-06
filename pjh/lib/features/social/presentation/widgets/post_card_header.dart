part of 'post_card.dart';

extension _PostCardHeader on _PostCardState {
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.push('/user-profile/${post.authorId}'),
              borderRadius: BorderRadius.circular(8.r),
              child: Row(
                children: [
                  Semantics(
                    label: '${post.authorName} 프로필 사진',
                    image: true,
                    child: CircleAvatar(
                      radius: 20.r,
                      backgroundImage: post.authorProfileImage != null
                          ? CachedNetworkImageProvider(post.authorProfileImage!)
                          : null,
                      child: post.authorProfileImage == null
                          ? Text(
                              post.authorName.isNotEmpty ? post.authorName[0] : '?',
                              style: TextStyle(fontSize: 14.sp))
                          : null,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(
                              post.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          _buildStreakBadge(post.authorId),
                          SizedBox(width: 4.w),
                          _buildTypeBadge(),
                        ]),
                        Text(
                          _formatDateTime(post.createdAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert, size: 24.w),
            tooltip: '게시물 옵션',
            onPressed: () => _showPostOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBadge(String authorId) {
    return FutureBuilder<int>(
      future: _fetchStreak(authorId),
      builder: (ctx, snap) {
        final streak = snap.data ?? 0;
        if (streak < 3) return const SizedBox.shrink();

        final String emoji;
        final Color color;
        if (streak >= 30) {
          emoji = '⭐';
          color = Colors.amber;
        } else if (streak >= 7) {
          emoji = '🔥';
          color = Colors.orange;
        } else {
          emoji = '🔥';
          color = Colors.deepOrange;
        }

        return Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: TextStyle(fontSize: 11.sp)),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ]);
      },
    );
  }

  Future<int> _fetchStreak(String authorId) async {
    if (_streakCache.containsKey(authorId)) return _streakCache[authorId]!;
    final result = await sl<SocialRepository>().getUserStreak(authorId);
    final streak = result.fold((_) => 0, (v) => v);
    _streakCache[authorId] = streak;
    return streak;
  }

  Widget _buildTypeBadge() {
    switch (post.type) {
      case PostType.emotionAnalysis:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text('감정분석',
              style: TextStyle(
                  fontSize: 10.sp,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600)),
        );
      case PostType.text:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text('커뮤니티',
              style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w600)),
        );
      case PostType.image:
      case PostType.video:
        return const SizedBox.shrink();
    }
  }
}
