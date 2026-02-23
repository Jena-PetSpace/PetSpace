import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/post.dart';
import '../../../emotion/presentation/widgets/emotion_chart.dart';
import '../../../../core/utils/hashtag_utils.dart';

class PostCard extends StatelessWidget {
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
          CircleAvatar(
            radius: 20.r,
            backgroundImage: post.authorProfileImage != null
                ? CachedNetworkImageProvider(post.authorProfileImage!)
                : null,
            child: post.authorProfileImage == null
                ? Text(post.authorName.isNotEmpty ? post.authorName[0] : '?', style: TextStyle(fontSize: 14.sp))
                : null,
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
                    color: AppTheme.secondaryTextColor,
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
          color: Colors.black87,
        ),
        children: segments.map((segment) {
          if (segment['isHashtag'] == true) {
            final hashtag = segment['hashtag'] as String;
            return WidgetSpan(
              child: GestureDetector(
                onTap: () {
                  if (onHashtagTap != null) {
                    onHashtagTap!(hashtag);
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
        if (onHashtagTap != null) {
          onHashtagTap!(tag);
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
    dev.log('Building images, count: ${post.imageUrls.length}', name: 'PostCard');
    if (post.imageUrls.isNotEmpty) {
      dev.log('Image URL: ${post.imageUrls.first}', name: 'PostCard');
    }

    if (post.imageUrls.length == 1) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: CachedNetworkImage(
          imageUrl: post.imageUrls.first,
          width: double.infinity,
          height: 300.h,
          fit: BoxFit.cover,
          placeholder: (context, url) {
            dev.log('Loading image: $url', name: 'PostCard');
            return Container(
              height: 300.h,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorWidget: (context, url, error) {
            dev.log('Error loading image: $url, error: $error', name: 'PostCard');
            return Container(
              height: 300.h,
              color: Colors.grey[200],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 24.w),
                  SizedBox(height: 8.h),
                  Text('이미지 로드 실패', style: TextStyle(color: Colors.grey[600], fontSize: 14.sp)),
                  Text(error.toString(), style: TextStyle(color: Colors.grey[400], fontSize: 10.sp)),
                ],
              ),
            );
          },
        ),
      );
    } else {
      return SizedBox(
        height: 200.h,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          itemCount: post.imageUrls.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrls[index],
                  width: 150.w,
                  height: 200.h,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 150.w,
                    height: 200.h,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 150.w,
                    height: 200.h,
                    color: Colors.grey[200],
                    child: Icon(Icons.error, size: 24.w),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
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
                    color: AppTheme.secondaryTextColor,
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
          InkWell(
            onTap: onLike,
            borderRadius: BorderRadius.circular(20.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    post.isLikedByCurrentUser
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: post.isLikedByCurrentUser ? Colors.red : null,
                    size: 20.w,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    '${post.likesCount}',
                    style: TextStyle(fontSize: 12.sp),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 16.w),
          InkWell(
            onTap: onComment,
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
          SizedBox(width: 16.w),
          InkWell(
            onTap: onShare,
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
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (post.authorId == currentUserId) ...[
            if (onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('수정'),
                onTap: () {
                  Navigator.pop(context);
                  onEdit!();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('삭제', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context);
                },
              ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('신고'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('신고 기능은 준비 중입니다')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('차단'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('차단 기능은 준비 중입니다')),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시물 삭제'),
        content: const Text('정말로 이 게시물을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete!();
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