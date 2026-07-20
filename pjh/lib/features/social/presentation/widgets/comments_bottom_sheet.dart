import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../core/services/content_filter.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/repositories/social_repository.dart';
import '../bloc/comment_bloc.dart';
import '../bloc/comment_event.dart';
import '../bloc/comment_state.dart';
import '../pages/post_detail_page.dart';
import 'comment_list_item.dart';

typedef CommentBlocFactory = CommentBloc Function();

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String postAuthorId;
  final String currentUserId;
  final SocialRepository repository;
  final ValueNotifier<bool> mutationNotifier;
  final CommentBlocFactory? commentBlocFactory;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.currentUserId,
    required this.repository,
    required this.mutationNotifier,
    this.commentBlocFactory,
  });

  static Future<bool> show({
    required BuildContext context,
    required String postId,
    required String postAuthorId,
    required String currentUserId,
    required SocialRepository repository,
    CommentBlocFactory? commentBlocFactory,
  }) async {
    final mutationNotifier = ValueNotifier<bool>(false);
    try {
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: CommentsBottomSheet(
            postId: postId,
            postAuthorId: postAuthorId,
            currentUserId: currentUserId,
            repository: repository,
            mutationNotifier: mutationNotifier,
            commentBlocFactory: commentBlocFactory,
          ),
        ),
      );
      return result ?? mutationNotifier.value;
    } finally {
      mutationNotifier.dispose();
    }
  }

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final CommentBloc _commentBloc;
  String? _replyToCommentId;
  String? _replyToAuthorName;

  @override
  void initState() {
    super.initState();
    _commentBloc = widget.commentBlocFactory?.call() ??
        CommentBloc(
          getComments: di.sl(),
          createComment: di.sl(),
          deleteComment: di.sl(),
          updateComment: di.sl(),
          currentUserId: widget.currentUserId,
          socialRepository: widget.repository,
        );
    _commentBloc.add(LoadComments(postId: widget.postId));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    _commentBloc.close();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent * 0.9) return;
    _commentBloc.add(LoadMoreComments(postId: widget.postId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CommentBloc>.value(
      value: _commentBloc,
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Material(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildCommentBody()),
              Builder(builder: _buildCommentInput),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 8.h),
        Container(
          width: 40.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: AppTheme.dividerColor,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(
          height: 56,
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: IconButton(
                  key: const Key('comments_sheet_close'),
                  onPressed: () =>
                      Navigator.of(context).pop(widget.mutationNotifier.value),
                  tooltip: '댓글 닫기',
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: BlocBuilder<CommentBloc, CommentState>(
                  builder: (context, state) {
                    final title = state is CommentLoaded
                        ? '댓글 ${state.totalCount}'
                        : '댓글';
                    return Text(
                      title,
                      key: const Key('comments_sheet_title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryTextColor,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: 56,
                height: 56,
                child: IconButton(
                  key: const Key('comments_sheet_open_detail'),
                  onPressed: _openPostDetail,
                  tooltip: '게시글 전체 보기',
                  icon: const Icon(Icons.open_in_full),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildCommentBody() {
    return BlocConsumer<CommentBloc, CommentState>(
      listenWhen: (previous, current) {
        if (current is CommentError && previous != current) return true;
        if (current is! CommentLoaded || current.actionOutcome == null) {
          return false;
        }
        final previousOutcome =
            previous is CommentLoaded ? previous.actionOutcome : null;
        return previousOutcome != current.actionOutcome;
      },
      listener: (context, state) {
        if (state is CommentError) {
          _showMessage(state.message);
          return;
        }
        if (state is! CommentLoaded || state.actionOutcome == null) return;
        final outcome = state.actionOutcome!;
        if (!outcome.succeeded) {
          _showMessage(
            outcome.message ?? '요청을 완료하지 못했어요. 잠시 후 다시 시도해주세요.',
          );
          return;
        }

        if (_changesCommentCount(outcome.kind)) {
          widget.mutationNotifier.value = true;
        }
        if (outcome.kind == CommentActionKind.commentCreated ||
            outcome.kind == CommentActionKind.replyCreated) {
          _commentController.clear();
          setState(() {
            _replyToCommentId = null;
            _replyToAuthorName = null;
          });
          FocusScope.of(context).unfocus();
        }
      },
      builder: (context, state) {
        if (state is CommentInitial || state is CommentLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is CommentError) {
          return _buildLoadError();
        }
        final loaded = state as CommentLoaded;
        if (loaded.comments.isEmpty) {
          return _buildEmptyComments();
        }
        return CustomScrollView(
          key: const Key('comments_sheet_list'),
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(top: 8.h),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final comment = loaded.comments[index];
                    return CommentListItem(
                      comment: comment,
                      currentUserId: widget.currentUserId,
                      onDelete: comment.authorId == widget.currentUserId
                          ? () => _commentBloc.add(
                                DeleteCommentRequested(commentId: comment.id),
                              )
                          : null,
                      onReply: () => _beginReply(
                        comment.id,
                        comment.authorName,
                      ),
                      pendingLikeIds: loaded.pendingLikeIds,
                      pendingDeleteIds: loaded.pendingDeleteIds,
                    );
                  },
                  childCount: loaded.comments.length,
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildFooter(loaded)),
          ],
        );
      },
    );
  }

  Widget _buildFooter(CommentLoaded state) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (state.error != null) {
      return Center(
        child: TextButton.icon(
          key: const Key('comments_sheet_load_more_retry'),
          onPressed: () =>
              _commentBloc.add(LoadMoreComments(postId: widget.postId)),
          icon: const Icon(Icons.refresh),
          label: const Text('댓글 더 불러오기'),
        ),
      );
    }
    return SizedBox(height: 12.h);
  }

  Widget _buildLoadError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 40.w,
            color: AppTheme.lightTextColor,
          ),
          SizedBox(height: 10.h),
          const Text('댓글을 불러오지 못했어요'),
          SizedBox(height: 12.h),
          OutlinedButton(
            key: const Key('comments_sheet_retry'),
            onPressed: () =>
                _commentBloc.add(LoadComments(postId: widget.postId)),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyComments() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mode_comment_outlined,
              size: 40.w,
              color: AppTheme.secondaryTextColor,
            ),
            SizedBox(height: 12.h),
            Text(
              '아직 댓글이 없어요',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryTextColor,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              '첫 댓글을 남겨보세요',
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput(BuildContext context) {
    final state = context.watch<CommentBloc>().state;
    final isSubmitting = state is CommentLoaded && state.isSubmitting;
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 8.w, 8.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyToAuthorName != null) _buildReplyTarget(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('comments_sheet_input'),
                      controller: _commentController,
                      enabled: !isSubmitting,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitComment(context),
                      decoration: InputDecoration(
                        hintText: _replyToAuthorName == null
                            ? '댓글을 입력하세요...'
                            : '답글을 입력하세요...',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                          borderSide: const BorderSide(
                            color: AppTheme.dividerColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                          borderSide: const BorderSide(
                            color: AppTheme.dividerColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      key: const Key('comments_sheet_send'),
                      onPressed:
                          isSubmitting ? null : () => _submitComment(context),
                      tooltip: '댓글 전송',
                      color: AppTheme.primaryColor,
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyTarget() {
    return Container(
      key: const Key('comments_sheet_reply_target'),
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppTheme.subtleBackground,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 16.w, color: AppTheme.primaryColor),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              '${_replyToAuthorName!}에게 답글',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              key: const Key('comments_sheet_reply_cancel'),
              onPressed: _cancelReply,
              tooltip: '답글 취소',
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }

  void _beginReply(String commentId, String authorName) {
    setState(() {
      _replyToCommentId = commentId;
      _replyToAuthorName = authorName;
    });
    _commentController.clear();
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToAuthorName = null;
    });
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  void _submitComment(BuildContext context) {
    final state = _commentBloc.state;
    if (state is CommentLoaded && state.isSubmitting) return;
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    if (ContentFilter.hasBannedKeyword(content)) {
      _showMessage('커뮤니티 가이드라인에 어긋나는 표현이 포함되어 있습니다.');
      return;
    }

    final authState = context.read<AuthBloc>().state;
    final senderName =
        authState is AuthAuthenticated ? authState.user.displayName : '사용자';
    if (_replyToCommentId != null) {
      _commentBloc.add(
        CreateReplyRequested(
          postId: widget.postId,
          parentId: _replyToCommentId!,
          content: content,
          postAuthorId: widget.postAuthorId,
          senderName: senderName,
        ),
      );
      return;
    }
    _commentBloc.add(
      CreateCommentRequested(
        postId: widget.postId,
        content: content,
        postAuthorId: widget.postAuthorId,
        senderName: senderName,
      ),
    );
  }

  Future<void> _openPostDetail() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailPage(
          postId: widget.postId,
          repository: widget.repository,
          commentBloc: _commentBloc,
          currentUserId: widget.currentUserId,
          commentMutationNotifier: widget.mutationNotifier,
        ),
      ),
    );
  }

  bool _changesCommentCount(CommentActionKind kind) {
    return kind == CommentActionKind.commentCreated ||
        kind == CommentActionKind.replyCreated ||
        kind == CommentActionKind.commentDeleted ||
        kind == CommentActionKind.replyDeleted;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }
}
