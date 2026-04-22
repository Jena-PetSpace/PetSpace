// Supabase 기반 Post Model
// TRD 문서의 posts 테이블 스키마에 맞게 구현

import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../domain/entities/post.dart';

class PostModel {
  final String id;
  final String authorId;
  final String? petId;
  /// 레거시 단일 URL (하위 호환 읽기 전용)
  final String? imageUrl;
  final List<String> imageUrls;
  final String postType;
  final Map<String, dynamic>?
      emotionAnalysis; // Supabase: emotion_analysis (JSONB)
  final String? caption;
  final List<String> hashtags; // Supabase: hashtags (TEXT[])
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPrivate;
  final String? location;
  final double? locationLat;
  final double? locationLng;

  // JOIN으로 가져온 사용자 정보
  final String? authorName;
  final String? authorPhotoUrl;

  // 배치 조회로 계산된 현재 유저 상태 (DB 컬럼 아님)
  final bool isLikedByCurrentUser;
  final bool isSavedByCurrentUser;

  const PostModel({
    required this.id,
    required this.authorId,
    this.petId,
    this.imageUrl,
    this.imageUrls = const [],
    this.postType = 'photo',
    this.emotionAnalysis,
    this.caption,
    this.hashtags = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isPrivate = false,
    this.location,
    this.locationLat,
    this.locationLng,
    this.authorName,
    this.authorPhotoUrl,
    this.isLikedByCurrentUser = false,
    this.isSavedByCurrentUser = false,
  });

  // Supabase JSON -> Model
  factory PostModel.fromJson(Map<String, dynamic> json) {
    // users 테이블 JOIN 데이터 처리
    final userData = json['users'] as Map<String, dynamic>?;

    // image_urls 우선, 없으면 image_url 레거시 폴백
    final rawImageUrls = json['image_urls'];
    List<String> imageUrls;
    if (rawImageUrls != null && (rawImageUrls as List).isNotEmpty) {
      imageUrls = List<String>.from(rawImageUrls);
    } else if (json['image_url'] != null) {
      imageUrls = [json['image_url'] as String];
    } else {
      imageUrls = [];
    }

    return PostModel(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      petId: json['pet_id'] as String?,
      imageUrl: json['image_url'] as String?,
      imageUrls: imageUrls,
      postType: _ensureValidPostType(json['post_type'] as String?),
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
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      authorName: userData?['display_name'] as String?,
      authorPhotoUrl: userData?['photo_url'] as String?,
    );
  }

  // Model -> Supabase JSON (for INSERT/UPDATE)
  Map<String, dynamic> toJson() {
    return {
      'author_id': authorId,
      if (petId != null) 'pet_id': petId,
      // 하위 호환: image_url에 첫 번째 URL 기록
      if (imageUrls.isNotEmpty) 'image_url': imageUrls.first
      else if (imageUrl != null) 'image_url': imageUrl,
      'image_urls': imageUrls,
      'post_type': _ensureValidPostType(postType),
      if (emotionAnalysis != null) 'emotion_analysis': emotionAnalysis,
      if (caption != null) 'caption': caption,
      if (hashtags.isNotEmpty) 'hashtags': hashtags,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'is_private': isPrivate,
      if (location != null) 'location': location,
      if (locationLat != null) 'location_lat': locationLat,
      if (locationLng != null) 'location_lng': locationLng,
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
        analysis = null;
      }
    }

    PostType type;
    switch (postType) {
      case 'photo':
      case 'image':
        type = PostType.image;
      case 'emotion':
      case 'emotion_analysis':
        type = PostType.emotionAnalysis;
      case 'community':
      case 'text':
        type = PostType.text;
      case 'video':
        type = PostType.video;
      default:
        // 레거시: postType 없을 때 내용으로 추론
        if (analysis != null) {
          type = PostType.emotionAnalysis;
        } else if (imageUrls.isNotEmpty) {
          type = PostType.image;
        } else {
          type = PostType.text;
        }
    }

    return Post(
      id: id,
      authorId: authorId,
      authorName: authorName ?? 'Unknown User',
      authorProfileImage: authorPhotoUrl,
      type: type,
      content: caption,
      imageUrls: imageUrls,
      emotionAnalysis: analysis,
      tags: hashtags,
      createdAt: createdAt,
      updatedAt: updatedAt,
      likesCount: likesCount,
      commentsCount: commentsCount,
      isLikedByCurrentUser: isLikedByCurrentUser,
      isSavedByCurrentUser: isSavedByCurrentUser,
      isPrivate: isPrivate,
      location: location,
      locationLat: locationLat,
      locationLng: locationLng,
    );
  }

  // DB CHECK 제약: photo / community / emotion 만 허용
  static const _validPostTypes = {'photo', 'community', 'emotion'};

  static String _ensureValidPostType(String? value) {
    if (value != null && _validPostTypes.contains(value)) return value;
    return 'photo';
  }

  static String _postTypeToString(PostType type) {
    switch (type) {
      case PostType.image:
        return 'photo';
      case PostType.emotionAnalysis:
        return 'emotion';
      case PostType.text:
        return 'community';
      case PostType.video:
        return 'photo'; // 비디오 미지원 → 사진으로 폴백
    }
  }

  // Domain Entity -> Model
  factory PostModel.fromEntity(Post post) {
    return PostModel(
      id: post.id,
      authorId: post.authorId,
      imageUrl: post.imageUrls.isNotEmpty ? post.imageUrls.first : null,
      imageUrls: post.imageUrls,
      postType: _postTypeToString(post.type),
      emotionAnalysis: post.emotionAnalysis?.toJson(),
      caption: post.content,
      hashtags: post.tags,
      likesCount: post.likesCount,
      commentsCount: post.commentsCount,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt ?? post.createdAt,
      isPrivate: post.isPrivate,
      location: post.location,
      locationLat: post.locationLat,
      locationLng: post.locationLng,
      authorName: post.authorName,
      authorPhotoUrl: post.authorProfileImage,
      isLikedByCurrentUser: post.isLikedByCurrentUser,
      isSavedByCurrentUser: post.isSavedByCurrentUser,
    );
  }

  PostModel copyWith({
    String? id,
    String? authorId,
    String? petId,
    String? imageUrl,
    List<String>? imageUrls,
    String? postType,
    Map<String, dynamic>? emotionAnalysis,
    String? caption,
    List<String>? hashtags,
    int? likesCount,
    int? commentsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPrivate,
    String? location,
    double? locationLat,
    double? locationLng,
    String? authorName,
    String? authorPhotoUrl,
    bool? isLikedByCurrentUser,
    bool? isSavedByCurrentUser,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      petId: petId ?? this.petId,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      postType: postType ?? this.postType,
      emotionAnalysis: emotionAnalysis ?? this.emotionAnalysis,
      caption: caption ?? this.caption,
      hashtags: hashtags ?? this.hashtags,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPrivate: isPrivate ?? this.isPrivate,
      location: location ?? this.location,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      isSavedByCurrentUser: isSavedByCurrentUser ?? this.isSavedByCurrentUser,
    );
  }
}
