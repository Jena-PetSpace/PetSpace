import 'package:equatable/equatable.dart';
import '../../domain/entities/comment.dart';

abstract class CommentState extends Equatable {
  const CommentState();

  @override
  List<Object?> get props => [];
}

class CommentInitial extends CommentState {}

class CommentLoading extends CommentState {}

class CommentLoaded extends CommentState {
  final List<Comment> comments;
  final bool hasMore;
  final bool isLoadingMore;
  final String? error;

  const CommentLoaded({
    required this.comments,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.error,
  });

  @override
  List<Object?> get props => [comments, hasMore, isLoadingMore, error];

  CommentLoaded copyWith({
    List<Comment>? comments,
    bool? hasMore,
    bool? isLoadingMore,
    String? error,
  }) {
    return CommentLoaded(
      comments: comments ?? this.comments,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }
}

class CommentError extends CommentState {
  final String message;

  const CommentError(this.message);

  @override
  List<Object?> get props => [message];
}
