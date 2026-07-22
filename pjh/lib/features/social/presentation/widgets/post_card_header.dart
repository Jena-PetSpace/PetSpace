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
                              post.authorName.isNotEmpty
                                  ? post.authorName[0]
                                  : '?',
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
                          _buildTypeBadge(),
                        ]),
                        Text(
                          [
                            if (post.location?.trim().isNotEmpty == true &&
                                (post.locationLat == null ||
                                    post.locationLng == null))
                              post.location!.trim(),
                            _formatDateTime(post.createdAt),
                          ].join(' · '),
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

  Widget _buildTypeBadge() {
    switch (post.type) {
      case PostType.emotionAnalysis:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text('AI 분석 공유',
              style: TextStyle(
                  fontSize: 10.sp,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600)),
        );
      case PostType.text:
        // 커뮤니티는 별도 탭·카드 문법으로 구분한다. 피드에 남아 있는 구형
        // text post에는 중복 배지를 붙이지 않아 탭 역할과 색 의미를 흐리지 않는다.
        return const SizedBox.shrink();
      case PostType.image:
      case PostType.video:
        return const SizedBox.shrink();
    }
  }
}
