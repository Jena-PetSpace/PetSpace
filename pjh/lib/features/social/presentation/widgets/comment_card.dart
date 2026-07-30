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
  final ValueChanged<Comment>? onReport;
  final ValueChanged<Comment>? onUserActions;
  final Set<String> hiddenAuthorIds;

  const CommentCard({
    super.key,
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.onLike,
    this.onDelete,
    this.onEdit,
    this.onReport,
    this.onUserActions,
    this.hiddenAuthorIds = const <String>{},
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
    return Wrap(
      spacing: 8.w,
      runSpacing: 2.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          comment.authorName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.sp,
          ),
        ),
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
        Expanded(
          child: Wrap(
            spacing: 8.w,
            runSpacing: 4.h,
            crossAxisAlignment: WrapCrossAlignment.center,
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
                        color: comment.isLikedByCurrentUser
                            ? AppTheme.errorColor
                            : AppTheme.neutral500,
                      ),
                      if (comment.likesCount > 0) ...[
                        SizedBox(width: 4.w),
                        Text(
                          '${comment.likesCount}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppTheme.neutral500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: onReply,
                borderRadius: BorderRadius.circular(16.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  child: Text(
                    '답글',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppTheme.neutral500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (comment.authorId == currentUserId)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz,
              size: 16.w,
              color: AppTheme.neutral500,
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
                    Icon(Icons.delete, size: 16.w, color: AppTheme.errorColor),
                    SizedBox(width: 8.w),
                    Text('삭제',
                        style: TextStyle(
                            color: AppTheme.errorColor, fontSize: 14.sp)),
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
          )
        else if (onReport != null || onUserActions != null)
          PopupMenuButton<String>(
            key: Key('comment_options_${comment.id}'),
            tooltip: '댓글 더보기',
            icon: Icon(
              Icons.more_horiz,
              size: 18.w,
              color: AppTheme.neutral500,
            ),
            itemBuilder: (context) => [
              if (onReport != null)
                const PopupMenuItem(
                  value: 'report_comment',
                  child: Text('댓글 신고'),
                ),
              if (onUserActions != null)
                const PopupMenuItem(
                  value: 'user_actions',
                  child: Text('사용자 신고 · 차단'),
                ),
            ],
            onSelected: (value) {
              if (value == 'report_comment') {
                onReport?.call(comment);
              } else if (value == 'user_actions') {
                onUserActions?.call(comment);
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
          left: BorderSide(color: AppTheme.neutral500, width: 1),
        ),
      ),
      child: Column(
        children: comment.replies
            .where((reply) => !hiddenAuthorIds.contains(reply.authorId))
            .map((reply) {
          return CommentCard(
            comment: reply,
            currentUserId: currentUserId,
            onReply: onReply,
            onLike: onLike,
            onReport: onReport,
            onUserActions: onUserActions,
            hiddenAuthorIds: hiddenAuthorIds,
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
