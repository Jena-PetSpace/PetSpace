import 'package:equatable/equatable.dart';

import '../../../emotion/domain/entities/emotion_analysis.dart';

enum PostType { text, image, emotionAnalysis, video }

class Post extends Equatable {
  final String id;
  final String authorId;
  String get userId => authorId; // userId getter for compatibility
  final String authorName;
  final String? authorProfileImage;
  final PostType type;
  final String? content;
  final List<String> imageUrls;
  final String? videoUrl;
  final EmotionAnalysis? emotionAnalysis;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLikedByCurrentUser;
  final bool isPublic;
  final bool isPrivate;
  final String? location;

  const Post({
    required this.id,
    required this.authorId,
    String? userId, // userId parameter for compatibility - ignored since we use authorId
    required this.authorName,
    this.authorProfileImage,
    required this.type,
    this.content,
    this.imageUrls = const [],
    this.videoUrl,
    this.emotionAnalysis,
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.isLikedByCurrentUser = false,
    this.isPublic = true,
    this.isPrivate = false,
    this.location,
  });

  Post copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorProfileImage,
    PostType? type,
    String? content,
    List<String>? imageUrls,
    String? videoUrl,
    EmotionAnalysis? emotionAnalysis,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    bool? isLikedByCurrentUser,
    bool? isPublic,
    bool? isPrivate,
    String? location,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorProfileImage: authorProfileImage ?? this.authorProfileImage,
      type: type ?? this.type,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      emotionAnalysis: emotionAnalysis ?? this.emotionAnalysis,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      isPublic: isPublic ?? this.isPublic,
      isPrivate: isPrivate ?? this.isPrivate,
      location: location ?? this.location,
    );
  }

  @override
  List<Object?> get props => [
        id,
        authorId,
        authorName,
        authorProfileImage,
        type,
        content,
        imageUrls,
        videoUrl,
        emotionAnalysis,
        tags,
        createdAt,
        updatedAt,
        likesCount,
        commentsCount,
        sharesCount,
        isLikedByCurrentUser,
        isPublic,
        isPrivate,
        location,
      ];
}