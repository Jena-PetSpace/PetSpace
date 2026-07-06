import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../shared/themes/app_theme.dart';
import '../../../social/domain/entities/post.dart';
import '../../../social/domain/repositories/social_repository.dart';

class CommunityPreview extends StatefulWidget {
  final String? category;

  const CommunityPreview({super.key, this.category});

  @override
  State<CommunityPreview> createState() => _CommunityPreviewState();
}

class _CommunityPreviewState extends State<CommunityPreview> {
  List<Post> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void didUpdateWidget(CommunityPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final repo = di.sl<SocialRepository>();
      final result = widget.category != null
          ? await repo.searchPostsByHashtag(hashtag: widget.category!, limit: 5)
          : await repo.getFeed(limit: 5);
      result.fold(
        (failure) {
          dev.log('커뮤니티 프리뷰 로드 실패: ${failure.message}', name: 'CommunityPreview');
          if (mounted) setState(() => _loading = false);
        },
        (posts) {
          if (mounted) setState(() { _posts = posts; _loading = false; });
        },
      );
    } catch (e) {
      dev.log('커뮤니티 프리뷰 오류: $e', name: 'CommunityPreview');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          if (_loading)
            _buildSkeleton()
          else if (_posts.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: Text(
                '아직 게시글이 없습니다',
                style: TextStyle(fontSize: 13.sp, color: AppTheme.secondaryTextColor),
              ),
            )
          else
            Column(
              children: _posts.asMap().entries.map((entry) {
                return Padding(
                  padding: EdgeInsets.only(bottom: entry.key < _posts.length - 1 ? 8.h : 0),
                  child: _buildPostCard(context, entry.value),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, Post post) {
    final hasImage = post.imageUrls.isNotEmpty;
    final thumbUrl = hasImage ? post.imageUrls.first : null;

    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Container(
        decoration: AppTheme.cardDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 왼쪽: 텍스트 영역
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(14.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 작성자 + 시간
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12.r,
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                          backgroundImage: post.authorProfileImage != null && post.authorProfileImage!.isNotEmpty
                              ? CachedNetworkImageProvider(post.authorProfileImage!)
                              : null,
                          child: post.authorProfileImage == null || post.authorProfileImage!.isEmpty
                              ? Icon(Icons.person, size: 14.w, color: AppTheme.primaryColor)
                              : null,
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            post.authorName,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _timeAgo(post.createdAt.toIso8601String()),
                          style: TextStyle(fontSize: 10.sp, color: AppTheme.secondaryTextColor),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    // 본문
                    Text(
                      post.content ?? '',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppTheme.primaryTextColor,
                        height: 1.4,
                      ),
                      maxLines: hasImage ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8.h),
                    // 좋아요 + 댓글
                    Row(
                      children: [
                        Icon(Icons.favorite_border, size: 14.w, color: AppTheme.secondaryTextColor),
                        SizedBox(width: 3.w),
                        Text('${post.likesCount}',
                            style: TextStyle(fontSize: 10.sp, color: AppTheme.secondaryTextColor)),
                        SizedBox(width: 10.w),
                        Icon(Icons.chat_bubble_outline, size: 14.w, color: AppTheme.secondaryTextColor),
                        SizedBox(width: 3.w),
                        Text('${post.commentsCount}',
                            style: TextStyle(fontSize: 10.sp, color: AppTheme.secondaryTextColor)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 오른쪽: 이미지 썸네일 (있을 때만)
            if (thumbUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(12.r),
                  bottomRight: Radius.circular(12.r),
                ),
                child: CachedNetworkImage(
                  imageUrl: thumbUrl,
                  width: 90.w,
                  height: 90.w,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      children: List.generate(3, (i) => Padding(
        padding: EdgeInsets.only(bottom: i < 2 ? 8.h : 0),
        child: Container(
          height: 90.h,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      )),
    );
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
    } catch (_) { return ''; }
  }
}
