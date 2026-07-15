import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/services/realtime_service.dart';
import '../../domain/entities/comment.dart';
import '../../domain/repositories/social_repository.dart';
import '../../domain/usecases/create_comment.dart';
import '../../domain/usecases/delete_comment.dart';
import '../../domain/usecases/get_comments.dart';
import '../../domain/usecases/update_comment.dart';
import 'comment_event.dart';
import 'comment_state.dart';

class CommentBloc extends Bloc<CommentEvent, CommentState> {
  static const int _commentsPerPage = 20;
  static const String _loadErrorMessage = '댓글을 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
  static const String _actionErrorMessage = '요청을 완료하지 못했어요. 잠시 후 다시 시도해주세요.';

  final GetComments _getComments;
  final CreateComment _createComment;
  final DeleteComment _deleteComment;
  final UpdateComment _updateComment;
  final String _currentUserId;
  final SocialRepository _socialRepository;
  final PushNotificationService _pushService;
  final RealtimeService _realtimeService;
  final bool _enableRealtime;

  StreamSubscription<Map<String, dynamic>>? _commentSub;
  Timer? _realtimeDebounce;
  String? _lastCommentId;
  bool _submissionInFlight = false;
  final Set<String> _likeInFlight = <String>{};
  final Set<String> _deleteInFlight = <String>{};
  int _outcomeId = 0;

  CommentBloc({
    required GetComments getComments,
    required CreateComment createComment,
    required DeleteComment deleteComment,
    required UpdateComment updateComment,
    required String currentUserId,
    SocialRepository? socialRepository,
    PushNotificationService? pushNotificationService,
    RealtimeService? realtimeService,
    bool enableRealtime = true,
  }) : _getComments = getComments,
       _createComment = createComment,
       _deleteComment = deleteComment,
       _updateComment = updateComment,
       _currentUserId = currentUserId,
       _socialRepository = socialRepository ?? sl<SocialRepository>(),
       _pushService = pushNotificationService ?? PushNotificationService(),
       _realtimeService = realtimeService ?? RealtimeService(),
       _enableRealtime = enableRealtime,
       super(CommentInitial()) {
    on<LoadComments>(_onLoadComments);
    on<LoadMoreComments>(_onLoadMoreComments);
    on<RefreshCommentsFromRealtime>(_onRefreshCommentsFromRealtime);
    on<CreateCommentRequested>(_onCreateCommentRequested);
    on<CreateReplyRequested>(_onCreateReplyRequested);
    on<DeleteCommentRequested>(_onDeleteCommentRequested);
    on<UpdateCommentRequested>(_onUpdateCommentRequested);
    on<LikeCommentRequested>(_onLikeCommentRequested);
  }

  Future<void> _onLoadComments(
    LoadComments event,
    Emitter<CommentState> emit,
  ) async {
    emit(CommentLoading());
    if (_enableRealtime) _subscribeToRealtime(event.postId);
    _lastCommentId = null;

    final result = await _getComments(
      GetCommentsParams(postId: event.postId, limit: _commentsPerPage),
    );
    final comments = result.fold<List<Comment>?>((_) => null, (value) => value);
    if (comments == null) {
      emit(const CommentError(_loadErrorMessage));
      return;
    }

    final totalCount = await _readServerTotal(event.postId);
    if (totalCount == null) {
      emit(const CommentError(_loadErrorMessage));
      return;
    }

    if (comments.isNotEmpty) _lastCommentId = comments.last.id;
    emit(
      CommentLoaded(
        comments: comments,
        totalCount: totalCount,
        hasMore: comments.length == _commentsPerPage,
      ),
    );
  }

  Future<void> _onLoadMoreComments(
    LoadMoreComments event,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    if (current is! CommentLoaded ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    emit(
      current.copyWith(
        isLoadingMore: true,
        clearError: true,
        clearActionOutcome: true,
      ),
    );
    final result = await _getComments(
      GetCommentsParams(
        postId: event.postId,
        limit: _commentsPerPage,
        lastCommentId: _lastCommentId,
      ),
    );
    final page = result.fold<List<Comment>?>((_) => null, (value) => value);
    final latest = state;
    if (latest is! CommentLoaded) return;
    if (page == null) {
      emit(latest.copyWith(isLoadingMore: false, error: '댓글을 더 불러오지 못했어요.'));
      return;
    }

    if (page.isNotEmpty) _lastCommentId = page.last.id;
    final knownIds = latest.comments.map((comment) => comment.id).toSet();
    final merged = <Comment>[
      ...latest.comments,
      ...page.where((comment) => knownIds.add(comment.id)),
    ];
    emit(
      latest.copyWith(
        comments: merged,
        hasMore: page.length == _commentsPerPage,
        isLoadingMore: false,
        clearError: true,
      ),
    );
  }

  Future<void> _onCreateCommentRequested(
    CreateCommentRequested event,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    if (current is! CommentLoaded || _submissionInFlight) return;
    _submissionInFlight = true;
    emit(
      current.copyWith(
        isSubmitting: true,
        clearError: true,
        clearActionOutcome: true,
      ),
    );

    final comment = Comment(
      id: const Uuid().v4(),
      postId: event.postId,
      authorId: _currentUserId,
      authorName: event.senderName ?? '',
      content: event.content,
      createdAt: DateTime.now(),
    );
    final result = await _createComment(CreateCommentParams(comment: comment));
    final created = result.fold<Comment?>((_) => null, (value) => value);
    final latest = state;
    if (latest is! CommentLoaded) {
      _submissionInFlight = false;
      return;
    }
    if (created == null) {
      _submissionInFlight = false;
      emit(const CommentError(_actionErrorMessage));
      emit(
        latest.copyWith(
          isSubmitting: false,
          actionOutcome: _outcome(
            CommentActionKind.commentCreated,
            succeeded: false,
          ),
        ),
      );
      return;
    }

    emit(
      latest.copyWith(
        comments: [created, ...latest.comments],
        totalCount: latest.totalCount + 1,
        actionOutcome: _outcome(
          CommentActionKind.commentCreated,
          succeeded: true,
        ),
      ),
    );
    _sendCommentNotification(
      postId: event.postId,
      postAuthorId: event.postAuthorId,
      senderName: event.senderName,
      content: event.content,
    );
    await _finishSubmissionWithServerCount(event.postId, emit);
  }

  Future<void> _onCreateReplyRequested(
    CreateReplyRequested event,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    if (current is! CommentLoaded || _submissionInFlight) return;
    final parent = _locate(current.comments, event.parentId);
    if (parent == null || parent.parent != null) return;

    _submissionInFlight = true;
    emit(
      current.copyWith(
        isSubmitting: true,
        clearError: true,
        clearActionOutcome: true,
      ),
    );
    final reply = Comment(
      id: const Uuid().v4(),
      postId: event.postId,
      authorId: _currentUserId,
      authorName: event.senderName ?? '',
      content: event.content,
      createdAt: DateTime.now(),
      parentId: event.parentId,
    );
    final result = await _createComment(CreateCommentParams(comment: reply));
    final created = result.fold<Comment?>((_) => null, (value) => value);
    final latest = state;
    if (latest is! CommentLoaded) {
      _submissionInFlight = false;
      return;
    }
    if (created == null) {
      _submissionInFlight = false;
      emit(const CommentError(_actionErrorMessage));
      emit(
        latest.copyWith(
          isSubmitting: false,
          actionOutcome: _outcome(
            CommentActionKind.replyCreated,
            succeeded: false,
          ),
        ),
      );
      return;
    }

    final updated = _updateById(
      latest.comments,
      event.parentId,
      (comment) => comment.copyWith(replies: [...comment.replies, created]),
    );
    emit(
      latest.copyWith(
        comments: updated,
        totalCount: latest.totalCount + 1,
        actionOutcome: _outcome(
          CommentActionKind.replyCreated,
          succeeded: true,
        ),
      ),
    );
    _sendCommentNotification(
      postId: event.postId,
      postAuthorId: event.postAuthorId,
      senderName: event.senderName,
      content: event.content,
    );
    await _finishSubmissionWithServerCount(event.postId, emit);
  }

  Future<void> _onDeleteCommentRequested(
    DeleteCommentRequested event,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    if (current is! CommentLoaded ||
        _deleteInFlight.contains(event.commentId)) {
      return;
    }
    final located = _locate(current.comments, event.commentId);
    if (located == null) return;
    _deleteInFlight.add(event.commentId);
    emit(
      current.copyWith(
        pendingDeleteIds: {...current.pendingDeleteIds, event.commentId},
        clearError: true,
        clearActionOutcome: true,
      ),
    );

    final result = await _deleteComment(
      DeleteCommentParams(commentId: event.commentId),
    );
    final succeeded = result.isRight();
    _deleteInFlight.remove(event.commentId);
    final latest = state;
    if (latest is! CommentLoaded) return;
    final pending = {...latest.pendingDeleteIds}..remove(event.commentId);
    final kind = located.parent == null
        ? CommentActionKind.commentDeleted
        : CommentActionKind.replyDeleted;
    if (!succeeded) {
      emit(const CommentError(_actionErrorMessage));
      emit(
        latest.copyWith(
          pendingDeleteIds: pending,
          actionOutcome: _outcome(kind, succeeded: false),
        ),
      );
      return;
    }

    final removedCount = located.parent == null
        ? 1 + located.comment.replies.length
        : 1;
    final comments = located.parent == null
        ? latest.comments
              .where((comment) => comment.id != event.commentId)
              .toList()
        : _updateById(
            latest.comments,
            located.parent!.id,
            (parent) => parent.copyWith(
              replies: parent.replies
                  .where((reply) => reply.id != event.commentId)
                  .toList(),
            ),
          );
    emit(
      latest.copyWith(
        comments: comments,
        totalCount: max(0, latest.totalCount - removedCount),
        pendingDeleteIds: pending,
        actionOutcome: _outcome(kind, succeeded: true),
      ),
    );
    await _finishMutationWithServerCount(located.comment.postId, emit);
  }

  Future<void> _onUpdateCommentRequested(
    UpdateCommentRequested event,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    if (current is! CommentLoaded) return;
    final located = _locate(current.comments, event.commentId);
    if (located == null) return;
    final updated = located.comment.copyWith(
      content: event.content,
      updatedAt: DateTime.now(),
    );
    final result = await _updateComment(UpdateCommentParams(comment: updated));
    final saved = result.fold<Comment?>((_) => null, (value) => value);
    final latest = state;
    if (latest is! CommentLoaded) return;
    if (saved == null) {
      emit(const CommentError(_actionErrorMessage));
      emit(
        latest.copyWith(
          actionOutcome: _outcome(
            CommentActionKind.commentUpdated,
            succeeded: false,
          ),
        ),
      );
      return;
    }
    emit(
      latest.copyWith(
        comments: _replaceById(latest.comments, saved),
        actionOutcome: _outcome(
          CommentActionKind.commentUpdated,
          succeeded: true,
        ),
      ),
    );
  }

  Future<void> _onLikeCommentRequested(
    LikeCommentRequested event,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    if (current is! CommentLoaded || _likeInFlight.contains(event.commentId)) {
      return;
    }
    final located = _locate(current.comments, event.commentId);
    if (located == null) return;
    final previousLiked = located.comment.isLikedByCurrentUser;
    final previousCount = located.comment.likesCount;
    _likeInFlight.add(event.commentId);
    emit(
      current.copyWith(
        comments: _updateById(
          current.comments,
          event.commentId,
          (comment) => comment.copyWith(
            isLikedByCurrentUser: !previousLiked,
            likesCount: previousLiked
                ? max(0, previousCount - 1)
                : previousCount + 1,
          ),
        ),
        pendingLikeIds: {...current.pendingLikeIds, event.commentId},
        clearActionOutcome: true,
      ),
    );

    final result = previousLiked
        ? await _socialRepository.unlikeComment(event.commentId, _currentUserId)
        : await _socialRepository.likeComment(event.commentId, _currentUserId);
    _likeInFlight.remove(event.commentId);
    final latest = state;
    if (latest is! CommentLoaded) return;
    final pending = {...latest.pendingLikeIds}..remove(event.commentId);
    if (result.isLeft()) {
      emit(const CommentError(_actionErrorMessage));
      emit(
        latest.copyWith(
          comments: _updateById(
            latest.comments,
            event.commentId,
            (comment) => comment.copyWith(
              isLikedByCurrentUser: previousLiked,
              likesCount: previousCount,
            ),
          ),
          pendingLikeIds: pending,
          actionOutcome: _outcome(
            CommentActionKind.likeFailed,
            succeeded: false,
          ),
        ),
      );
      return;
    }
    emit(latest.copyWith(pendingLikeIds: pending));
  }

  Future<void> _onRefreshCommentsFromRealtime(
    RefreshCommentsFromRealtime event,
    Emitter<CommentState> emit,
  ) async {
    final current = state;
    if (current is! CommentLoaded ||
        current.isSubmitting ||
        current.pendingDeleteIds.isNotEmpty ||
        current.pendingLikeIds.isNotEmpty) {
      return;
    }
    final limit = max(_commentsPerPage, current.comments.length);
    final result = await _getComments(
      GetCommentsParams(postId: event.postId, limit: limit),
    );
    final comments = result.fold<List<Comment>?>((_) => null, (value) => value);
    if (comments == null) return;
    final totalCount = await _readServerTotal(event.postId);
    final latest = state;
    if (latest is! CommentLoaded) return;
    if (comments.isNotEmpty) _lastCommentId = comments.last.id;
    emit(
      latest.copyWith(
        comments: comments,
        totalCount: totalCount ?? latest.totalCount,
        hasMore: comments.length == limit ? latest.hasMore : false,
        clearError: true,
        clearActionOutcome: true,
      ),
    );
  }

  Future<int?> _readServerTotal(String postId) async {
    final result = await _socialRepository.getPostDetail(postId);
    return result.fold(
      (_) => null,
      (detail) => (detail?['comments_count'] as num?)?.toInt(),
    );
  }

  Future<void> _finishSubmissionWithServerCount(
    String postId,
    Emitter<CommentState> emit,
  ) async {
    final serverTotal = await _readServerTotal(postId);
    _submissionInFlight = false;
    final latest = state;
    if (latest is! CommentLoaded) return;
    emit(
      latest.copyWith(
        totalCount: serverTotal ?? latest.totalCount,
        isSubmitting: false,
        clearActionOutcome: true,
      ),
    );
  }

  Future<void> _finishMutationWithServerCount(
    String postId,
    Emitter<CommentState> emit,
  ) async {
    final serverTotal = await _readServerTotal(postId);
    final latest = state;
    if (latest is! CommentLoaded) return;
    emit(
      latest.copyWith(
        totalCount: serverTotal ?? latest.totalCount,
        clearActionOutcome: true,
      ),
    );
  }

  CommentActionOutcome _outcome(
    CommentActionKind kind, {
    required bool succeeded,
  }) {
    return CommentActionOutcome(
      id: ++_outcomeId,
      kind: kind,
      succeeded: succeeded,
      message: succeeded ? null : _actionErrorMessage,
    );
  }

  _LocatedComment? _locate(List<Comment> comments, String id) {
    for (final comment in comments) {
      if (comment.id == id) {
        return _LocatedComment(comment: comment);
      }
      for (final reply in comment.replies) {
        if (reply.id == id) {
          return _LocatedComment(comment: reply, parent: comment);
        }
      }
    }
    return null;
  }

  List<Comment> _updateById(
    List<Comment> comments,
    String id,
    Comment Function(Comment comment) update,
  ) {
    return comments.map((comment) {
      if (comment.id == id) return update(comment);
      final replies = comment.replies.map((reply) {
        return reply.id == id ? update(reply) : reply;
      }).toList();
      return replies == comment.replies
          ? comment
          : comment.copyWith(replies: replies);
    }).toList();
  }

  List<Comment> _replaceById(List<Comment> comments, Comment replacement) {
    return _updateById(comments, replacement.id, (_) => replacement);
  }

  void _sendCommentNotification({
    required String postId,
    required String? postAuthorId,
    required String? senderName,
    required String content,
  }) {
    if (postAuthorId == null ||
        postAuthorId.isEmpty ||
        postAuthorId == _currentUserId) {
      return;
    }
    unawaited(
      _pushService.sendCommentNotification(
        toUserId: postAuthorId,
        fromUserId: _currentUserId,
        fromUserName: senderName ?? '사용자',
        postId: postId,
        commentPreview: content,
      ),
    );
  }

  void _subscribeToRealtime(String postId) {
    _commentSub?.cancel();
    _realtimeService.subscribeToPostComments(postId);
    _commentSub = _realtimeService.commentStream.listen((data) {
      if (data['postId'] != postId) return;
      final event = data['event'] as String?;
      if (event != 'insert' && event != 'delete') return;
      _realtimeDebounce?.cancel();
      _realtimeDebounce = Timer(const Duration(milliseconds: 350), () {
        if (!isClosed) add(RefreshCommentsFromRealtime(postId: postId));
      });
    });
  }

  @override
  Future<void> close() async {
    _realtimeDebounce?.cancel();
    await _commentSub?.cancel();
    return super.close();
  }
}

class _LocatedComment {
  final Comment comment;
  final Comment? parent;

  const _LocatedComment({required this.comment, this.parent});
}
