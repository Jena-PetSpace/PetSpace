import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/comment.dart';

class CommentListItem extends StatelessWidget {
  final Comment comment;
  final String currentUserId;
  final VoidCallback? onDelete;

  const CommentListItem({
    super.key,
    required this.comment,
    required this.currentUserId,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16.r,
            backgroundImage: comment.authorProfileImage != null
                ? CachedNetworkImageProvider(comment.authorProfileImage!)
                : null,
            child: comment.authorProfileImage == null
                ? Text(
                    comment.authorName.isNotEmpty ? comment.authorName[0] : '?',
                    style: TextStyle(fontSize: 12.sp),
                  )
                : null,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      _formatDateTime(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    if (onDelete != null)
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 18.w),
                        color: Colors.grey[600],
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          _showDeleteConfirmation(context);
                        },
                      ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  comment.content,
                  style: TextStyle(fontSize: 14.sp, height: 1.4),
                ),
                if (comment.updatedAt != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    '(수정됨)',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제하시겠습니까?'),
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
}
