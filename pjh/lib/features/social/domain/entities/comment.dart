import 'package:equatable/equatable.dart';

class Comment extends Equatable {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorProfileImage;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likesCount;
  final bool isLikedByCurrentUser;
  final String? parentCommentId;
  final List<Comment> replies;

  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorProfileImage,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.likesCount = 0,
    this.isLikedByCurrentUser = false,
    this.parentCommentId,
    this.replies = const [],
  });

  Comment copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorProfileImage,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likesCount,
    bool? isLikedByCurrentUser,
    String? parentCommentId,
    List<Comment>? replies,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorProfileImage: authorProfileImage ?? this.authorProfileImage,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likesCount: likesCount ?? this.likesCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replies: replies ?? this.replies,
    );
  }

  @override
  List<Object?> get props => [
        id,
        postId,
        authorId,
        authorName,
        authorProfileImage,
        content,
        createdAt,
        updatedAt,
        likesCount,
        isLikedByCurrentUser,
        parentCommentId,
        replies,
      ];
}