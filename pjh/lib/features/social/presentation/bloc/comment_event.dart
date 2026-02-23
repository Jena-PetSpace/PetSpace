import 'package:equatable/equatable.dart';

abstract class CommentEvent extends Equatable {
  const CommentEvent();

  @override
  List<Object?> get props => [];
}

class LoadComments extends CommentEvent {
  final String postId;

  const LoadComments({required this.postId});

  @override
  List<Object?> get props => [postId];
}

class LoadMoreComments extends CommentEvent {
  final String postId;

  const LoadMoreComments({required this.postId});

  @override
  List<Object?> get props => [postId];
}

class CreateCommentRequested extends CommentEvent {
  final String postId;
  final String content;

  const CreateCommentRequested({
    required this.postId,
    required this.content,
  });

  @override
  List<Object?> get props => [postId, content];
}

class DeleteCommentRequested extends CommentEvent {
  final String commentId;

  const DeleteCommentRequested({required this.commentId});

  @override
  List<Object?> get props => [commentId];
}

class UpdateCommentRequested extends CommentEvent {
  final String commentId;
  final String content;

  const UpdateCommentRequested({
    required this.commentId,
    required this.content,
  });

  @override
  List<Object?> get props => [commentId, content];
}
