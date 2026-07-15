import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/comment.dart';
import '../bloc/comment_bloc.dart';
import '../bloc/comment_event.dart';

class CommentListItem extends StatefulWidget {
  final Comment comment;
  final String currentUserId;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final Set<String> pendingLikeIds;
  final Set<String> pendingDeleteIds;

  const CommentListItem({
    super.key,
    required this.comment,
    required this.currentUserId,
    this.onDelete,
    this.onReply,
    this.pendingLikeIds = const <String>{},
    this.pendingDeleteIds = const <String>{},
  });

  @override
  State<CommentListItem> createState() => _CommentListItemState();
}

class _CommentListItemState extends State<CommentListItem> {
  bool _showAllReplies = false;

  @override
  void didUpdateWidget(CommentListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.id != widget.comment.id ||
        widget.comment.replies.length <= 2) {
      _showAllReplies = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final replies = widget.comment.replies;
    final visibleReplies = _showAllReplies ? replies : replies.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentRow(context, widget.comment, isReply: false),
        if (visibleReplies.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: 44.w),
            child: Column(
              children: visibleReplies
                  .map(
                    (reply) => _buildCommentRow(context, reply, isReply: true),
                  )
                  .toList(),
            ),
          ),
        if (replies.length > 2)
          Padding(
            padding: EdgeInsets.only(left: 54.w, right: 16.w),
            child: TextButton(
              key: Key('comment_replies_toggle_${widget.comment.id}'),
              onPressed: () {
                setState(() => _showAllReplies = !_showAllReplies);
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.symmetric(horizontal: 8.w),
              ),
              child: Text(
                _showAllReplies ? '답글 접기' : '답글 ${replies.length - 2}개 더 보기',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentRow(
    BuildContext context,
    Comment comment, {
    required bool isReply,
  }) {
    final imageUrl = comment.authorProfileImage?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final isLikePending = widget.pendingLikeIds.contains(comment.id);
    final isDeletePending = widget.pendingDeleteIds.contains(comment.id);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: isReply ? 6.h : 8.h,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: '${comment.authorName} 프로필 사진',
            image: true,
            child: CircleAvatar(
              radius: isReply ? 12.r : 16.r,
              backgroundImage: hasImage
                  ? CachedNetworkImageProvider(imageUrl)
                  : null,
              child: !hasImage
                  ? Text(
                      comment.authorName.trim().isEmpty
                          ? '?'
                          : comment.authorName.trim().substring(0, 1),
                      style: TextStyle(fontSize: isReply ? 10.sp : 12.sp),
                    )
                  : null,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      _formatDateTime(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey[500],
                      ),
                    ),
                    if (comment.authorId == widget.currentUserId &&
                        (isReply || widget.onDelete != null))
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          key: Key('comment_delete_${comment.id}'),
                          tooltip: isReply ? '답글 삭제' : '댓글 삭제',
                          onPressed: isDeletePending
                              ? null
                              : () => isReply
                                    ? _showDeleteReplyConfirmation(
                                        context,
                                        comment.id,
                                      )
                                    : _showDeleteConfirmation(context),
                          icon: isDeletePending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.delete_outline,
                                  size: 18.w,
                                  color: Colors.grey[400],
                                ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 3.h),
                Text(
                  comment.content,
                  style: TextStyle(fontSize: 14.sp, height: 1.4),
                ),
                if (comment.updatedAt != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    '(수정됨)',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                Row(
                  children: [
                    Semantics(
                      button: true,
                      label: comment.isLikedByCurrentUser
                          ? '댓글 좋아요 취소'
                          : '댓글 좋아요',
                      child: SizedBox(
                        height: 44,
                        child: TextButton.icon(
                          key: Key('comment_like_${comment.id}'),
                          onPressed: isLikePending
                              ? null
                              : () => context.read<CommentBloc>().add(
                                  LikeCommentRequested(
                                    commentId: comment.id,
                                    isCurrentlyLiked:
                                        comment.isLikedByCurrentUser,
                                  ),
                                ),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            foregroundColor: comment.isLikedByCurrentUser
                                ? AppTheme.highlightColor
                                : Colors.grey[500],
                          ),
                          icon: isLikePending
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  comment.isLikedByCurrentUser
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 16.w,
                                ),
                          label: Text(
                            comment.likesCount > 0
                                ? comment.likesCount.toString()
                                : '좋아요',
                            style: TextStyle(fontSize: 11.sp),
                          ),
                        ),
                      ),
                    ),
                    if (!isReply)
                      SizedBox(
                        height: 44,
                        child: TextButton(
                          key: Key('comment_reply_${comment.id}'),
                          onPressed: widget.onReply,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            foregroundColor: Colors.grey[600],
                          ),
                          child: Text(
                            repliesLabel(widget.comment.replies.length),
                            style: TextStyle(fontSize: 12.sp),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String repliesLabel(int count) => count == 0 ? '답글' : '답글 $count';

  void _showDeleteConfirmation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글과 답글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onDelete?.call();
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showDeleteReplyConfirmation(BuildContext context, String replyId) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('답글 삭제'),
        content: const Text('이 답글을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<CommentBloc>().add(
                DeleteCommentRequested(commentId: replyId),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dateTime.month}/${dateTime.day}';
  }
}
