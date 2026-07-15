import 'package:equatable/equatable.dart';
import '../../domain/entities/comment.dart';

enum CommentActionKind {
  commentCreated,
  replyCreated,
  commentDeleted,
  replyDeleted,
  commentUpdated,
  likeFailed,
}

class CommentActionOutcome extends Equatable {
  final int id;
  final CommentActionKind kind;
  final bool succeeded;
  final String? message;

  const CommentActionOutcome({
    required this.id,
    required this.kind,
    required this.succeeded,
    this.message,
  });

  @override
  List<Object?> get props => [id, kind, succeeded, message];
}

abstract class CommentState extends Equatable {
  const CommentState();

  @override
  List<Object?> get props => [];
}

class CommentInitial extends CommentState {}

class CommentLoading extends CommentState {}

class CommentLoaded extends CommentState {
  final List<Comment> comments;
  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isSubmitting;
  final Set<String> pendingLikeIds;
  final Set<String> pendingDeleteIds;
  final CommentActionOutcome? actionOutcome;
  final String? error;

  const CommentLoaded({
    required this.comments,
    this.totalCount = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isSubmitting = false,
    this.pendingLikeIds = const <String>{},
    this.pendingDeleteIds = const <String>{},
    this.actionOutcome,
    this.error,
  });

  @override
  List<Object?> get props => [
    comments,
    totalCount,
    hasMore,
    isLoadingMore,
    isSubmitting,
    pendingLikeIds,
    pendingDeleteIds,
    actionOutcome,
    error,
  ];

  CommentLoaded copyWith({
    List<Comment>? comments,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isSubmitting,
    Set<String>? pendingLikeIds,
    Set<String>? pendingDeleteIds,
    CommentActionOutcome? actionOutcome,
    bool clearActionOutcome = false,
    String? error,
    bool clearError = false,
  }) {
    return CommentLoaded(
      comments: comments ?? this.comments,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      pendingLikeIds: Set<String>.unmodifiable(
        pendingLikeIds ?? this.pendingLikeIds,
      ),
      pendingDeleteIds: Set<String>.unmodifiable(
        pendingDeleteIds ?? this.pendingDeleteIds,
      ),
      actionOutcome: clearActionOutcome
          ? null
          : (actionOutcome ?? this.actionOutcome),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CommentError extends CommentState {
  final String message;

  const CommentError(this.message);

  @override
  List<Object?> get props => [message];
}
