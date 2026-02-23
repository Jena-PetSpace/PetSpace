import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/comment.dart';

class CommentCard extends StatelessWidget {
  final Comment comment;
  final String currentUserId;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const CommentCard({
    super.key,
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onLike,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
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
                _buildCommentHeader(),
                SizedBox(height: 4.h),
                _buildCommentContent(),
                SizedBox(height: 8.h),
                _buildCommentActions(),
                if (comment.replies.isNotEmpty) _buildReplies(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentHeader() {
    return Row(
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
            color: AppTheme.secondaryTextColor,
            fontSize: 11.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildCommentContent() {
    return Text(
      comment.content,
      style: TextStyle(
        fontSize: 13.sp,
        height: 1.3,
      ),
    );
  }

  Widget _buildCommentActions() {
    return Row(
      children: [
        InkWell(
          onTap: onLike,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  comment.isLikedByCurrentUser
                      ? Icons.favorite
                      : Icons.favorite_border,
                  size: 14.w,
                  color: comment.isLikedByCurrentUser ? Colors.red : Colors.grey,
                ),
                if (comment.likesCount > 0) ...[
                  SizedBox(width: 4.w),
                  Text(
                    '${comment.likesCount}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(width: 16.w),
        InkWell(
          onTap: onReply,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            child: Text(
              '답글',
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const Spacer(),
        if (comment.authorId == currentUserId)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz,
              size: 16.w,
              color: Colors.grey,
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16.w),
                    SizedBox(width: 8.w),
                    Text('수정', style: TextStyle(fontSize: 14.sp)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16.w, color: Colors.red),
                    SizedBox(width: 8.w),
                    Text('삭제', style: TextStyle(color: Colors.red, fontSize: 14.sp)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit?.call();
                  break;
                case 'delete':
                  onDelete?.call();
                  break;
              }
            },
          ),
      ],
    );
  }

  Widget _buildReplies() {
    return Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.only(left: 16.w),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey, width: 1),
        ),
      ),
      child: Column(
        children: comment.replies.map((reply) {
          return CommentCard(
            comment: reply,
            currentUserId: currentUserId,
            onReply: onReply,
            onLike: onLike,
          );
        }).toList(),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }
}