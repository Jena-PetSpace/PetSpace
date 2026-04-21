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
  final String? postAuthorId; // 알림 발송용 게시글 작성자 ID
  final String? senderName; // 알림 발송용 댓글 작성자 이름

  const CreateCommentRequested({
    required this.postId,
    required this.content,
    this.postAuthorId,
    this.senderName,
  });

  @override
  List<Object?> get props => [postId, content, postAuthorId];
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

class LikeCommentRequested extends CommentEvent {
  final String commentId;
  final bool isCurrentlyLiked;

  const LikeCommentRequested({
    required this.commentId,
    required this.isCurrentlyLiked,
  });

  @override
  List<Object?> get props => [commentId, isCurrentlyLiked];
}

class CreateReplyRequested extends CommentEvent {
  final String postId;
  final String parentCommentId;
  final String content;
  final String? postAuthorId;
  final String? senderName;

  const CreateReplyRequested({
    required this.postId,
    required this.parentCommentId,
    required this.content,
    this.postAuthorId,
    this.senderName,
  });

  @override
  List<Object?> get props => [postId, parentCommentId, content];
}
