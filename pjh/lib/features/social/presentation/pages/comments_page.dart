import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/comment.dart';
import '../bloc/comment_bloc.dart';
import '../bloc/comment_event.dart';
import '../bloc/comment_state.dart';
import '../widgets/comment_card.dart';

class CommentsPage extends StatefulWidget {
  final String postId;
  final String currentUserId;

  const CommentsPage({
    super.key,
    required this.postId,
    required this.currentUserId,
  });

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<CommentBloc>().add(LoadComments(postId: widget.postId));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      context.read<CommentBloc>().add(LoadMoreComments(postId: widget.postId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('댓글'),
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<CommentBloc, CommentState>(
              listener: (context, state) {
                if (state is CommentError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                // Reset submitting state when comments are loaded
                if (state is CommentLoaded && _isSubmitting) {
                  setState(() {
                    _isSubmitting = false;
                  });
                }
              },
              builder: (context, state) {
                if (state is CommentLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is CommentLoaded) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<CommentBloc>().add(
                        LoadComments(postId: widget.postId),
                      );
                    },
                    child: _buildCommentsList(state),
                  );
                } else if (state is CommentError) {
                  return _buildErrorState(state.message);
                }

                return const SizedBox.shrink();
              },
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentsList(CommentLoaded state) {
    if (state.comments.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: state.comments.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.comments.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final comment = state.comments[index];
        return CommentCard(
          comment: comment,
          currentUserId: widget.currentUserId,
          onReply: () => _replyToComment(comment),
          onLike: () => _likeComment(comment),
          onDelete: comment.authorId == widget.currentUserId
              ? () => _deleteComment(comment)
              : null,
          onEdit: comment.authorId == widget.currentUserId
              ? () => _editComment(comment)
              : null,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.comment_outlined,
            size: 64.w,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16.h),
          Text(
            '아직 댓글이 없습니다',
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '첫 번째 댓글을 작성해보세요!',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.w,
            color: Colors.red,
          ),
          SizedBox(height: 16.h),
          Text(
            '오류가 발생했습니다',
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              context.read<CommentBloc>().add(
                LoadComments(postId: widget.postId),
              );
            },
            child: Text('다시 시도', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            CircleAvatar(
              radius: 16.r,
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                widget.currentUserId.isNotEmpty ? widget.currentUserId[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _focusNode,
                maxLines: null,
                style: TextStyle(fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: '댓글을 입력하세요...',
                  hintStyle: TextStyle(fontSize: 14.sp),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20.r),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            IconButton(
              onPressed: _isSubmitting ? null : _submitComment,
              icon: _isSubmitting
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.send, size: 24.w),
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  void _submitComment() {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    context.read<CommentBloc>().add(CreateCommentRequested(
      postId: widget.postId,
      content: content,
    ));
    _commentController.clear();
    _focusNode.unfocus();
  }

  void _replyToComment(Comment comment) {
    _commentController.text = '@${comment.authorName} ';
    _focusNode.requestFocus();
  }

  void _likeComment(Comment comment) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('댓글 좋아요 기능이 곧 추가됩니다!')),
    );
  }

  void _deleteComment(Comment comment) {
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
              context.read<CommentBloc>().add(
                DeleteCommentRequested(commentId: comment.id),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _editComment(Comment comment) {
    final editController = TextEditingController(text: comment.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 수정'),
        content: TextField(
          controller: editController,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: '댓글 내용을 입력하세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final newContent = editController.text.trim();
              if (newContent.isNotEmpty && newContent != comment.content) {
                Navigator.pop(context);
                context.read<CommentBloc>().add(
                  UpdateCommentRequested(
                    commentId: comment.id,
                    content: newContent,
                  ),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
