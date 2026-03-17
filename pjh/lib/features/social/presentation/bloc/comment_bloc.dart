import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../domain/usecases/get_comments.dart';
import '../../domain/usecases/create_comment.dart';
import '../../domain/usecases/delete_comment.dart';
import '../../domain/usecases/update_comment.dart';
import '../../domain/entities/comment.dart';
import 'comment_event.dart';
import 'comment_state.dart';
import '../../../../core/services/push_notification_service.dart';

class CommentBloc extends Bloc<CommentEvent, CommentState> {
  final GetComments _getComments;
  final CreateComment _createComment;
  final DeleteComment _deleteComment;
  final UpdateComment _updateComment;
  final String _currentUserId;
  final _pushService = PushNotificationService();

  static const int _commentsPerPage = 20;
  String? _lastCommentId;
  String? _currentPostId;

  CommentBloc({
    required GetComments getComments,
    required CreateComment createComment,
    required DeleteComment deleteComment,
    required UpdateComment updateComment,
    required String currentUserId,
  })  : _getComments = getComments,
        _createComment = createComment,
        _deleteComment = deleteComment,
        _updateComment = updateComment,
        _currentUserId = currentUserId,
        super(CommentInitial()) {
    on<LoadComments>(_onLoadComments);
    on<LoadMoreComments>(_onLoadMoreComments);
    on<CreateCommentRequested>(_onCreateCommentRequested);
    on<DeleteCommentRequested>(_onDeleteCommentRequested);
    on<UpdateCommentRequested>(_onUpdateCommentRequested);
  }

  Future<void> _onLoadComments(
    LoadComments event,
    Emitter<CommentState> emit,
  ) async {
    emit(CommentLoading());
    _currentPostId = event.postId;
    _lastCommentId = null;

    final result = await _getComments(
      GetCommentsParams(
        postId: event.postId,
        limit: _commentsPerPage,
        lastCommentId: null,
      ),
    );

    result.fold(
      (failure) => emit(CommentError(failure.message)),
      (comments) {
        if (comments.isNotEmpty) {
          _lastCommentId = comments.last.id;
        }
        emit(CommentLoaded(
          comments: comments,
          hasMore: comments.length >= _commentsPerPage,
        ));
      },
    );
  }

  Future<void> _onLoadMoreComments(
    LoadMoreComments event,
    Emitter<CommentState> emit,
  ) async {
    if (state is! CommentLoaded) return;

    final currentState = state as CommentLoaded;
    if (!currentState.hasMore || currentState.isLoadingMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    final result = await _getComments(
      GetCommentsParams(
        postId: event.postId,
        limit: _commentsPerPage,
        lastCommentId: _lastCommentId,
      ),
    );

    result.fold(
      (failure) => emit(CommentError(failure.message)),
      (comments) {
        if (comments.isNotEmpty) {
          _lastCommentId = comments.last.id;
        }
        emit(CommentLoaded(
          comments: [...currentState.comments, ...comments],
          hasMore: comments.length >= _commentsPerPage,
          isLoadingMore: false,
        ));
      },
    );
  }

  Future<void> _onCreateCommentRequested(
    CreateCommentRequested event,
    Emitter<CommentState> emit,
  ) async {
    // Create a Comment entity
    final comment = Comment(
      id: const Uuid().v4(),
      postId: event.postId,
      authorId: _currentUserId,
      authorName: '', // Will be populated by backend
      content: event.content,
      createdAt: DateTime.now(),
    );

    final result = await _createComment(
      CreateCommentParams(comment: comment),
    );

    result.fold(
      (failure) {
        emit(CommentError(failure.message));
        // Restore previous state after showing error
        if (_currentPostId != null) {
          add(LoadComments(postId: _currentPostId!));
        }
      },
      (newComment) {
        if (state is CommentLoaded) {
          final currentState = state as CommentLoaded;
          emit(currentState.copyWith(
            comments: [newComment, ...currentState.comments],
          ));
        } else {
          if (_currentPostId != null) {
            add(LoadComments(postId: _currentPostId!));
          }
        }
        // 게시글 작성자에게 댓글 알림 발송 (자기 자신 제외)
        if (event.postAuthorId != null &&
            event.postAuthorId!.isNotEmpty &&
            event.postAuthorId != _currentUserId) {
          _pushService.sendCommentNotification(
            toUserId: event.postAuthorId!,
            fromUserId: _currentUserId,
            fromUserName: event.senderName ?? '사용자',
            postId: event.postId,
            commentPreview: event.content,
          );
        }
      },
    );
  }

  Future<void> _onDeleteCommentRequested(
    DeleteCommentRequested event,
    Emitter<CommentState> emit,
  ) async {
    if (state is! CommentLoaded) return;

    final currentState = state as CommentLoaded;

    final result = await _deleteComment(
      DeleteCommentParams(commentId: event.commentId),
    );

    result.fold(
      (failure) {
        emit(CommentError(failure.message));
        Future.delayed(const Duration(seconds: 2), () {
          if (!emit.isDone) emit(currentState);
        });
      },
      (_) {
        final updatedComments = currentState.comments
            .where((comment) => comment.id != event.commentId)
            .toList();
        emit(currentState.copyWith(comments: updatedComments));
      },
    );
  }

  Future<void> _onUpdateCommentRequested(
    UpdateCommentRequested event,
    Emitter<CommentState> emit,
  ) async {
    if (state is! CommentLoaded) return;

    final currentState = state as CommentLoaded;

    // Find the existing comment to update
    final existingComment = currentState.comments.firstWhere(
      (comment) => comment.id == event.commentId,
    );

    // Create updated comment with new content
    final updatedComment = existingComment.copyWith(
      content: event.content,
      updatedAt: DateTime.now(),
    );

    final result = await _updateComment(
      UpdateCommentParams(comment: updatedComment),
    );

    result.fold(
      (failure) {
        emit(CommentError(failure.message));
        Future.delayed(const Duration(seconds: 2), () {
          if (!emit.isDone) emit(currentState);
        });
      },
      (newComment) {
        final updatedComments = currentState.comments.map((comment) {
          return comment.id == event.commentId ? newComment : comment;
        }).toList();
        emit(currentState.copyWith(comments: updatedComments));
      },
    );
  }
}
