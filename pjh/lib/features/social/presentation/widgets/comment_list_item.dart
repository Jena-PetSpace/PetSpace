import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/comment.dart';
import '../bloc/comment_bloc.dart';
import '../bloc/comment_event.dart';

class CommentListItem extends StatelessWidget {
  final Comment comment;
  final String currentUserId;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;

  const CommentListItem({
    super.key,
    required this.comment,
    required this.currentUserId,
    this.onDelete,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentRow(context, comment, isReply: false),
        if (comment.replies.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: 44.w),
            child: Column(
              children: comment.replies
                  .map((reply) =>
                      _buildCommentRow(context, reply, isReply: true))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentRow(BuildContext context, Comment c,
      {required bool isReply}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: isReply ? 6.h : 8.h,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 12.r : 16.r,
            backgroundImage: c.authorProfileImage != null
                ? CachedNetworkImageProvider(c.authorProfileImage!)
                : null,
            child: c.authorProfileImage == null
                ? Text(
                    c.authorName.isNotEmpty ? c.authorName[0] : '?',
                    style: TextStyle(fontSize: isReply ? 10.sp : 12.sp),
                  )
                : null,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      c.authorName,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13.sp),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      _formatDateTime(c.createdAt),
                      style:
                          TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                    ),
                    const Spacer(),
                    if (c.authorId == currentUserId)
                      GestureDetector(
                        onTap: () => isReply
                            ? _showDeleteReplyConfirmation(context, c.id)
                            : _showDeleteConfirmation(context),
                        child: Icon(Icons.delete_outline,
                            size: 16.w, color: Colors.grey[400]),
                      ),
                  ],
                ),
                SizedBox(height: 3.h),
                Text(c.content,
                    style: TextStyle(fontSize: 14.sp, height: 1.4)),
                if (c.updatedAt != null) ...[
                  SizedBox(height: 2.h),
                  Text('(수정됨)',
                      style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic)),
                ],
                SizedBox(height: 6.h),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.read<CommentBloc>().add(
                            LikeCommentRequested(
                              commentId: c.id,
                              isCurrentlyLiked: c.isLikedByCurrentUser,
                            ),
                          ),
                      child: Row(
                        children: [
                          Icon(
                            c.isLikedByCurrentUser
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 14.w,
                            color: c.isLikedByCurrentUser
                                ? AppTheme.highlightColor
                                : Colors.grey[400],
                          ),
                          if (c.likesCount > 0) ...[
                            SizedBox(width: 3.w),
                            Text('${c.likesCount}',
                                style: TextStyle(
                                    fontSize: 11.sp, color: Colors.grey[500])),
                          ],
                        ],
                      ),
                    ),
                    if (!isReply) ...[
                      SizedBox(width: 14.w),
                      GestureDetector(
                        onTap: onReply,
                        child: Text(
                          '답글',
                          style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (comment.replies.isNotEmpty) ...[
                        SizedBox(width: 4.w),
                        Text('${comment.replies.length}',
                            style: TextStyle(
                                fontSize: 11.sp,
                                color: AppTheme.primaryColor)),
                      ],
                    ],
                  ],
                ),
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
      builder: (ctx) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete!();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showDeleteReplyConfirmation(BuildContext context, String replyId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('답글 삭제'),
        content: const Text('이 답글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<CommentBloc>()
                  .add(DeleteCommentRequested(commentId: replyId));
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
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dateTime.month}/${dateTime.day}';
  }
}
