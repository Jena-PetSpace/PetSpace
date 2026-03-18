import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/image_viewer_page.dart';
import '../../domain/entities/post.dart';
import '../../../emotion/presentation/widgets/emotion_chart.dart';
import '../../../../core/utils/hashtag_utils.dart';
import 'likes_bottom_sheet.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final String currentUserId;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final void Function(String hashtag)? onHashtagTap;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.onDelete,
    this.onEdit,
    this.onHashtagTap,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int _currentImageIndex = 0;
  bool _isLikeProcessing = false;

  Post get post => widget.post;
  String get currentUserId => widget.currentUserId;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (post.content != null) _buildContent(),
          if (post.imageUrls.isNotEmpty) _buildImages(),
          if (post.emotionAnalysis != null) _buildEmotionAnalysis(),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.w),
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
                  ? Text(post.authorName.isNotEmpty ? post.authorName[0] : '?', style: TextStyle(fontSize: 14.sp))
                  : null,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.authorName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                  ),
                ),
                Text(
                  _formatDateTime(post.createdAt),
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert, size: 24.w),
            onPressed: () => _showPostOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextWithHashtags(post.content!),
          if (post.tags.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 4.h,
              children: post.tags.map((tag) {
                return _buildHashtagChip(tag);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextWithHashtags(String text) {
    final segments = HashtagUtils.parseTextWithHashtags(text);

    if (segments.isEmpty) {
      return Text(
        text,
        style: TextStyle(fontSize: 14.sp, height: 1.4),
      );
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14.sp,
          height: 1.4,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
        children: segments.map((segment) {
          if (segment['isHashtag'] == true) {
            final hashtag = segment['hashtag'] as String;
            return WidgetSpan(
              child: GestureDetector(
                onTap: () {
                  if (widget.onHashtagTap != null) {
                    widget.onHashtagTap!(hashtag);
                  } else {
                    dev.log('Hashtag tapped: #$hashtag', name: 'PostCard');
                  }
                },
                child: Text(
                  segment['text'],
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          } else {
            return TextSpan(text: segment['text']);
          }
        }).toList(),
      ),
    );
  }

  Widget _buildHashtagChip(String tag) {
    return GestureDetector(
      onTap: () {
        if (widget.onHashtagTap != null) {
          widget.onHashtagTap!(tag);
        } else {
          dev.log('Hashtag tapped: #$tag', name: 'PostCard');
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          '#$tag',
          style: TextStyle(
            fontSize: 13.sp,
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildImages() {
    if (post.imageUrls.length == 1) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: GestureDetector(
          onTap: () => _openViewer(context, 0),
          child: CachedNetworkImage(
            imageUrl: post.imageUrls.first,
            width: double.infinity,
            height: 300.h,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 300.h,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              height: 300.h,
              color: Colors.grey[200],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 24.w),
                  SizedBox(height: 8.h),
                  Text('이미지 로드 실패',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 14.sp)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Multi-image: PageView with dots indicator + 탭으로 전체화면 뷰어
    return Column(
      children: [
        SizedBox(
          height: 300.h,
          child: PageView.builder(
            itemCount: post.imageUrls.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openViewer(context, index),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrls[index],
                  width: double.infinity,
                  height: 300.h,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 300.h,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 300.h,
                    color: Colors.grey[200],
                    child: Icon(Icons.error, color: Colors.red, size: 24.w),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(post.imageUrls.length, (index) {
            return Container(
              width: _currentImageIndex == index ? 8.w : 6.w,
              height: _currentImageIndex == index ? 8.w : 6.w,
              margin: EdgeInsets.symmetric(horizontal: 3.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentImageIndex == index
                    ? AppTheme.primaryColor
                    : Colors.grey[300],
              ),
            );
          }),
        ),
        SizedBox(height: 4.h),
      ],
    );
  }

  void _openViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageViewerPage(
          imageUrls: post.imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildEmotionAnalysis() {
    final emotionAnalysis = post.emotionAnalysis!;
    final dominantEmotion = emotionAnalysis.emotions.dominantEmotion;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppTheme.getEmotionColor(dominantEmotion).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppTheme.getEmotionColor(dominantEmotion).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60.w,
            height: 60.w,
            child: EmotionChart(
              emotions: emotionAnalysis.emotions,
              size: 60.w,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getEmotionIcon(dominantEmotion),
                      color: AppTheme.getEmotionColor(dominantEmotion),
                      size: 16.w,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      _getEmotionName(dominantEmotion),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getEmotionColor(dominantEmotion),
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
                Text(
                  '신뢰도 ${(emotionAnalysis.confidence * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                    if (_isLikeProcessing) return;
                    _isLikeProcessing = true;
                    widget.onLike();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) _isLikeProcessing = false;
                    });
                  },
                  borderRadius: BorderRadius.circular(20.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                    child: Icon(
                      post.isLikedByCurrentUser
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: post.isLikedByCurrentUser ? Colors.red : null,
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
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
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
          if (post.location != null)
            Row(
              children: [
                Icon(Icons.location_on, size: 16.w, color: Colors.grey),
                SizedBox(width: 4.w),
                Text(
                  post.location!,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showPostOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (post.authorId == currentUserId) ...[
            if (widget.onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('수정'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onEdit!();
                },
              ),
            if (widget.onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('삭제', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmation(context);
                },
              ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.report, color: Colors.orange),
              title: const Text('신고'),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('차단'),
              onTap: () {
                Navigator.pop(ctx);
                _showBlockDialog(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    String? selectedReason;
    final reasons = [
      '스팸 또는 광고',
      '폭력적이거나 위험한 콘텐츠',
      '허위 정보',
      '혐오 발언 또는 차별',
      '개인정보 침해',
      '기타',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('게시물 신고'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '신고 사유를 선택해주세요',
                style: TextStyle(fontSize: 14.sp, color: Theme.of(context).textTheme.bodySmall?.color),
              ),
              SizedBox(height: 12.h),
              ...reasons.map((reason) => RadioListTile<String>(
                title: Text(reason, style: TextStyle(fontSize: 14.sp)),
                value: reason,
                groupValue: selectedReason,
                onChanged: (value) {
                  setDialogState(() => selectedReason = value);
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: AppTheme.primaryColor,
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: selectedReason != null
                  ? () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('신고가 접수되었습니다. 검토 후 조치하겠습니다.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  : null,
              child: const Text('신고'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사용자 차단'),
        content: Text(
          '${post.authorName}님을 차단하시겠습니까?\n\n차단하면 해당 사용자의 게시물과 댓글이 보이지 않습니다.',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${post.authorName}님을 차단했습니다.'),
                  backgroundColor: Colors.red,
                  action: SnackBarAction(
                    label: '취소',
                    textColor: Colors.white,
                    onPressed: () {
                      // TODO: unblock user
                    },
                  ),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('차단'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게시물 삭제'),
        content: const Text('정말로 이 게시물을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete!();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  String _getEmotionName(String emotion) {
    switch (emotion) {
      case 'happiness': return '기쁨';
      case 'sadness': return '슬픔';
      case 'anxiety': return '불안';
      case 'sleepiness': return '졸림';
      case 'curiosity': return '호기심';
      default: return '알 수 없음';
    }
  }

  IconData _getEmotionIcon(String emotion) {
    switch (emotion) {
      case 'happiness': return Icons.mood;
      case 'sadness': return Icons.mood_bad;
      case 'anxiety': return Icons.warning;
      case 'sleepiness': return Icons.bedtime;
      case 'curiosity': return Icons.psychology;
      default: return Icons.help_outline;
    }
  }
}
