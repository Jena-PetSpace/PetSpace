import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../core/services/content_filter.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/comment.dart';
import '../../domain/repositories/social_repository.dart';
import '../bloc/comment_bloc.dart';
import '../bloc/comment_event.dart';
import '../bloc/comment_state.dart';
import '../pages/post_detail_page.dart';
import 'comment_composer.dart';
import 'comment_list_item.dart';
import 'social_content_report_sheet.dart';

typedef CommentBlocFactory = CommentBloc Function();

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String postAuthorId;
  final String currentUserId;
  final SocialRepository repository;
  final ValueNotifier<bool> mutationNotifier;
  final CommentBlocFactory? commentBlocFactory;
  final VoidCallback? onPostRemoved;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.currentUserId,
    required this.repository,
    required this.mutationNotifier,
    this.commentBlocFactory,
    this.onPostRemoved,
  });

  static Future<bool> show({
    required BuildContext context,
    required String postId,
    required String postAuthorId,
    required String currentUserId,
    required SocialRepository repository,
    CommentBlocFactory? commentBlocFactory,
    VoidCallback? onPostRemoved,
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
            onPostRemoved: onPostRemoved,
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
  final FocusNode _commentFocusNode = FocusNode();
  final GlobalKey _composerKey = GlobalKey();
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
    _commentFocusNode.dispose();
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
                      postAuthorId: widget.postAuthorId,
                      onDelete: comment.authorId == widget.currentUserId
                          ? () => _commentBloc.add(
                                DeleteCommentRequested(commentId: comment.id),
                              )
                          : null,
                      onReplyTo: _beginReply,
                      onReport: _reportComment,
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
    return CommentComposer(
      key: _composerKey,
      controller: _commentController,
      focusNode: _commentFocusNode,
      isSubmitting: isSubmitting,
      replyAuthorName: _replyToAuthorName,
      onSend: () => _submitComment(context),
      onCancelReply: _cancelReply,
      inputKey: const Key('comments_sheet_input'),
      sendKey: const Key('comments_sheet_send'),
      replyTargetKey: const Key('comments_sheet_reply_target'),
      replyCancelKey: const Key('comments_sheet_reply_cancel'),
    );
  }

  void _beginReply(String commentId, String authorName) {
    setState(() {
      _replyToCommentId = commentId;
      _replyToAuthorName = authorName;
    });
    _commentController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _commentFocusNode.requestFocus();
      final composerContext = _composerKey.currentContext;
      if (composerContext != null) {
        Scrollable.ensureVisible(
          composerContext,
          duration: const Duration(milliseconds: 180),
          alignment: 1,
        );
      }
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToAuthorName = null;
    });
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _reportComment(Comment comment) async {
    final accepted = await SocialContentReportSheet.show(
      context,
      target: SocialReportTarget.comment,
      targetId: comment.id,
      currentUserId: widget.currentUserId,
      repository: widget.repository,
    );
    if (!accepted || !mounted) return;
    _showMessage('신고가 접수되었습니다.');
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
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PostDetailPage(
          postId: widget.postId,
          repository: widget.repository,
          commentBloc: _commentBloc,
          currentUserId: widget.currentUserId,
          commentMutationNotifier: widget.mutationNotifier,
        ),
      ),
    );
    if (removed == true && mounted) {
      widget.onPostRemoved?.call();
      Navigator.of(context).pop(false);
    }
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
