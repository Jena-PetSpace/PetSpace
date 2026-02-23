// Supabase 기반 Post Model
// TRD 문서의 posts 테이블 스키마에 맞게 구현

import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../domain/entities/post.dart';

class PostModel {
  final String id;
  final String authorId;
  final String? petId;
  final String? imageUrl;  // Supabase: image_url (단일 URL)
  final Map<String, dynamic>? emotionAnalysis;  // Supabase: emotion_analysis (JSONB)
  final String? caption;
  final List<String> hashtags;  // Supabase: hashtags (TEXT[])
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPrivate;
  final String? location;

  // JOIN으로 가져온 사용자 정보
  final String? authorName;
  final String? authorPhotoUrl;

  const PostModel({
    required this.id,
    required this.authorId,
    this.petId,
    this.imageUrl,
    this.emotionAnalysis,
    this.caption,
    this.hashtags = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isPrivate = false,
    this.location,
    this.authorName,
    this.authorPhotoUrl,
  });

  // Supabase JSON -> Model
  factory PostModel.fromJson(Map<String, dynamic> json) {
    // users 테이블 JOIN 데이터 처리
    final userData = json['users'] as Map<String, dynamic>?;

    return PostModel(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      petId: json['pet_id'] as String?,
      imageUrl: json['image_url'] as String?,
      emotionAnalysis: json['emotion_analysis'] as Map<String, dynamic>?,
      caption: json['caption'] as String?,
      hashtags: json['hashtags'] != null
          ? List<String>.from(json['hashtags'] as List)
          : [],
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isPrivate: json['is_private'] as bool? ?? false,
      location: json['location'] as String?,
      authorName: userData?['display_name'] as String?,
      authorPhotoUrl: userData?['photo_url'] as String?,
    );
  }

  // Model -> Supabase JSON (for INSERT/UPDATE)
  Map<String, dynamic> toJson() {
    return {
      'author_id': authorId,
      'pet_id': petId,
      'image_url': imageUrl,
      'emotion_analysis': emotionAnalysis,
      'caption': caption,
      'hashtags': hashtags,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'is_private': isPrivate,
      'location': location,
      // created_at, updated_at은 Supabase에서 자동 관리
    };
  }

  // Model -> Domain Entity
  Post toEntity() {
    EmotionAnalysis? analysis;
    if (emotionAnalysis != null) {
      try {
        analysis = EmotionAnalysis.fromJson(emotionAnalysis!);
      } catch (e) {
        // 감정 분석 데이터 파싱 실패 시 null
        analysis = null;
      }
    }

    PostType type = PostType.text;
    if (analysis != null) {
      type = PostType.emotionAnalysis;
    } else if (imageUrl != null) {
      type = PostType.image;
    }

    return Post(
      id: id,
      authorId: authorId,
      authorName: authorName ?? 'Unknown User',
      authorProfileImage: authorPhotoUrl,
      type: type,
      content: caption,
      imageUrls: imageUrl != null ? [imageUrl!] : [],
      emotionAnalysis: analysis,
      tags: hashtags,
      createdAt: createdAt,
      updatedAt: updatedAt,
      likesCount: likesCount,
      commentsCount: commentsCount,
      isPrivate: isPrivate,
      location: location,
    );
  }

  // Domain Entity -> Model
  factory PostModel.fromEntity(Post post) {
    return PostModel(
      id: post.id,
      authorId: post.authorId,
      imageUrl: post.imageUrls.isNotEmpty ? post.imageUrls.first : null,
      emotionAnalysis: post.emotionAnalysis?.toJson(),
      caption: post.content,
      hashtags: post.tags,
      likesCount: post.likesCount,
      commentsCount: post.commentsCount,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt ?? post.createdAt,
      isPrivate: post.isPrivate,
      location: post.location,
      authorName: post.authorName,
      authorPhotoUrl: post.authorProfileImage,
    );
  }

  PostModel copyWith({
    String? id,
    String? authorId,
    String? petId,
    String? imageUrl,
    Map<String, dynamic>? emotionAnalysis,
    String? caption,
    List<String>? hashtags,
    int? likesCount,
    int? commentsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPrivate,
    String? location,
    String? authorName,
    String? authorPhotoUrl,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      petId: petId ?? this.petId,
      imageUrl: imageUrl ?? this.imageUrl,
      emotionAnalysis: emotionAnalysis ?? this.emotionAnalysis,
      caption: caption ?? this.caption,
      hashtags: hashtags ?? this.hashtags,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPrivate: isPrivate ?? this.isPrivate,
      location: location ?? this.location,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
    );
  }
}