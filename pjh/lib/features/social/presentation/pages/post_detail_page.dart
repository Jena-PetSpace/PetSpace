import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/injection_container.dart' as di;
import '../bloc/comment_bloc.dart';
import '../bloc/comment_event.dart';
import '../bloc/comment_state.dart';
import '../widgets/comment_list_item.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({
    super.key,
    required this.postId,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<CommentBloc>().add(LoadMoreComments(postId: widget.postId));
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  void _submitComment() {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    context.read<CommentBloc>().add(
          CreateCommentRequested(
            postId: widget.postId,
            content: content,
          ),
        );

    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CommentBloc(
        getComments: di.sl(),
        createComment: di.sl(),
        deleteComment: di.sl(),
        updateComment: di.sl(),
        currentUserId: Supabase.instance.client.auth.currentUser!.id,
      )..add(LoadComments(postId: widget.postId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('댓글'),
          centerTitle: true,
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
                },
                builder: (context, state) {
                  if (state is CommentLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is CommentError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            state.message,
                            style: TextStyle(color: Colors.red, fontSize: 14.sp),
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
                  } else if (state is CommentLoaded) {
                    if (state.comments.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.w),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64.w,
                                color: Colors.grey[300],
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                '첫 번째 댓글을 작성해보세요!',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: state.comments.length +
                          (state.isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= state.comments.length) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.w),
                              child: const CircularProgressIndicator(),
                            ),
                          );
                        }

                        final comment = state.comments[index];
                        final currentUserId =
                            Supabase.instance.client.auth.currentUser!.id;

                        return CommentListItem(
                          comment: comment,
                          currentUserId: currentUserId,
                          onDelete: comment.authorId == currentUserId
                              ? () {
                                  context.read<CommentBloc>().add(
                                        DeleteCommentRequested(
                                          commentId: comment.id,
                                        ),
                                      );
                                }
                              : null,
                        );
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
            _buildCommentInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4.r,
            offset: Offset(0, -2.h),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 8.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8.h,
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                style: TextStyle(fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: '댓글을 입력하세요...',
                  hintStyle: TextStyle(fontSize: 14.sp),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.r),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitComment(),
              ),
            ),
            SizedBox(width: 8.w),
            IconButton(
              onPressed: _submitComment,
              icon: Icon(Icons.send, size: 24.w),
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}