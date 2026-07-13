import 'package:equatable/equatable.dart';

import '../../../../shared/constants/community_categories.dart';

/// 커뮤니티(Q&A) 게시물 엔티티.
///
/// `getCommunityPosts`가 반환하는 raw Map(`posts` + users JOIN)을 타입 안전하게
/// 매핑한다. 사진 피드의 [Post] 엔티티와 달리 likes/comments 인터랙션이 없는
/// 카드 렌더링 전용 읽기 모델이다.
///
/// 카테고리는 `category` 컬럼(STEP 2 정규화)에서 읽는다. hashtags는 일반
/// 태그 용도로만 보존하며 더 이상 카테고리 분류에 쓰지 않는다.
class CommunityPost extends Equatable {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String content;
  final List<String> hashtags;

  /// 카테고리 컬럼 값. 신 체계(2026-07): chat/brag/qa/info.
  /// 구 체계 값(quiz/careguide/education/policy/event/health/training/
  /// food/life)은 재편 이전 글에 잔존 — 라벨은 categoryLabel이 호환 처리.
  /// 미분류는 null.
  final String? category;
  final int likes;
  final int comments;
  final DateTime createdAt;

  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.content,
    required this.hashtags,
    required this.category,
    required this.likes,
    required this.comments,
    required this.createdAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    final users = json['users'] as Map<String, dynamic>?;
    final createdAtStr = json['created_at'] as String?;
    return CommunityPost(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      authorName: users?['display_name'] as String? ?? '익명',
      authorPhotoUrl: users?['photo_url'] as String?,
      content: json['caption'] as String? ?? '',
      hashtags: json['hashtags'] != null
          ? List<String>.from(json['hashtags'] as List)
          : const [],
      category: json['category'] as String?,
      likes: json['likes_count'] as int? ?? 0,
      comments: json['comments_count'] as int? ?? 0,
      createdAt: createdAtStr != null
          ? DateTime.parse(createdAtStr)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// 운영자(관리자) 작성 글 여부 — 매거진/공지 표시용.
  bool get isAdmin => authorName == '관리자';

  /// category 컬럼 값을 한글 라벨로 변환. 미분류/미상이면 빈 문자열.
  /// 매핑은 shared 단일 소스([CommunityCategories.label])에 위임한다.
  String get categoryLabel => CommunityCategories.label(category);

  @override
  List<Object?> get props => [
        id,
        authorId,
        authorName,
        authorPhotoUrl,
        content,
        hashtags,
        category,
        likes,
        comments,
        createdAt,
      ];
}
