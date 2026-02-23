// Supabase 기반 Comment 모델

import '../../domain/entities/comment.dart';

class CommentModel extends Comment {
  const CommentModel({
    required super.id,
    required super.postId,
    required super.authorId,
    required super.authorName,
    super.authorProfileImage,
    required super.content,
    required super.createdAt,
    super.updatedAt,
    super.likesCount,
    super.isLikedByCurrentUser,
    super.parentCommentId,
    super.replies,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] ?? '',
      postId: json['post_id'] ?? '',
      authorId: json['author_id'] ?? '',
      authorName: json['author_name'] ?? '',
      authorProfileImage: json['author_profile_image'],
      content: json['content'] ?? '',
      parentCommentId: json['parent_comment_id'],
      likesCount: json['likes_count'] ?? 0,
      isLikedByCurrentUser: json['is_liked_by_current_user'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      replies: (json['replies'] as List<dynamic>?)?.map((reply) => CommentModel.fromJson(reply)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'author_id': authorId,
      'author_name': authorName,
      'author_profile_image': authorProfileImage,
      'content': content,
      'parent_comment_id': parentCommentId,
      'likes_count': likesCount,
      'is_liked_by_current_user': isLikedByCurrentUser,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'replies': replies.map((reply) => (reply as CommentModel).toJson()).toList(),
    };
  }

  Comment toEntity() {
    return Comment(
      id: id,
      postId: postId,
      authorId: authorId,
      authorName: authorName,
      authorProfileImage: authorProfileImage,
      content: content,
      parentCommentId: parentCommentId,
      likesCount: likesCount,
      isLikedByCurrentUser: isLikedByCurrentUser,
      createdAt: createdAt,
      updatedAt: updatedAt,
      replies: replies,
    );
  }

  factory CommentModel.fromEntity(Comment comment) {
    return CommentModel(
      id: comment.id,
      postId: comment.postId,
      authorId: comment.authorId,
      authorName: comment.authorName,
      authorProfileImage: comment.authorProfileImage,
      content: comment.content,
      parentCommentId: comment.parentCommentId,
      likesCount: comment.likesCount,
      isLikedByCurrentUser: comment.isLikedByCurrentUser,
      createdAt: comment.createdAt,
      updatedAt: comment.updatedAt,
      replies: comment.replies.map((reply) => CommentModel.fromEntity(reply)).toList(),
    );
  }

  @override
  CommentModel copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorProfileImage,
    String? content,
    String? parentCommentId,
    int? likesCount,
    bool? isLikedByCurrentUser,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Comment>? replies,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorProfileImage: authorProfileImage ?? this.authorProfileImage,
      content: content ?? this.content,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      likesCount: likesCount ?? this.likesCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      replies: replies ?? this.replies,
    );
  }
}