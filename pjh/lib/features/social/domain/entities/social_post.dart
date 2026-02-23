import 'package:equatable/equatable.dart';
import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../auth/domain/entities/user_profile.dart';

class SocialPost extends Equatable {
  final String id;
  final String userId;
  final String petId;
  final String emotionAnalysisId;
  final String title;
  final String? content;
  final String? imageUrl;
  final int likesCount;
  final int commentsCount;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 관련 엔티티들 (조인된 데이터)
  final UserProfile? userProfile;
  final Pet? pet;
  final EmotionAnalysis? emotionAnalysis;
  final bool? isLikedByCurrentUser;

  const SocialPost({
    required this.id,
    required this.userId,
    required this.petId,
    required this.emotionAnalysisId,
    required this.title,
    this.content,
    this.imageUrl,
    required this.likesCount,
    required this.commentsCount,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
    this.userProfile,
    this.pet,
    this.emotionAnalysis,
    this.isLikedByCurrentUser,
  });

  SocialPost copyWith({
    String? id,
    String? userId,
    String? petId,
    String? emotionAnalysisId,
    String? title,
    String? content,
    String? imageUrl,
    int? likesCount,
    int? commentsCount,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserProfile? userProfile,
    Pet? pet,
    EmotionAnalysis? emotionAnalysis,
    bool? isLikedByCurrentUser,
  }) {
    return SocialPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      petId: petId ?? this.petId,
      emotionAnalysisId: emotionAnalysisId ?? this.emotionAnalysisId,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userProfile: userProfile ?? this.userProfile,
      pet: pet ?? this.pet,
      emotionAnalysis: emotionAnalysis ?? this.emotionAnalysis,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
    );
  }

  String get displayAuthor {
    return userProfile?.displayName ?? '익명 사용자';
  }

  String get petDisplayName {
    return pet?.name ?? '반려동물';
  }

  String get dominantEmotion {
    if (emotionAnalysis == null) return '알 수 없음';

    final emotions = {
      '기쁨': emotionAnalysis!.emotions.happiness,
      '슬픔': emotionAnalysis!.emotions.sadness,
      '불안': emotionAnalysis!.emotions.anxiety,
      '졸림': emotionAnalysis!.emotions.sleepiness,
      '호기심': emotionAnalysis!.emotions.curiosity,
    };

    return emotions.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${createdAt.month}월 ${createdAt.day}일';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        petId,
        emotionAnalysisId,
        title,
        content,
        imageUrl,
        likesCount,
        commentsCount,
        isPublic,
        createdAt,
        updatedAt,
        userProfile,
        pet,
        emotionAnalysis,
        isLikedByCurrentUser,
      ];
}

class PostComment extends Equatable {
  final String id;
  final String userId;
  final String postId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 관련 엔티티
  final UserProfile? userProfile;

  const PostComment({
    required this.id,
    required this.userId,
    required this.postId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.userProfile,
  });

  PostComment copyWith({
    String? id,
    String? userId,
    String? postId,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserProfile? userProfile,
  }) {
    return PostComment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      postId: postId ?? this.postId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userProfile: userProfile ?? this.userProfile,
    );
  }

  String get displayAuthor {
    return userProfile?.displayName ?? '익명 사용자';
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${createdAt.month}월 ${createdAt.day}일';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        postId,
        content,
        createdAt,
        updatedAt,
        userProfile,
      ];
}