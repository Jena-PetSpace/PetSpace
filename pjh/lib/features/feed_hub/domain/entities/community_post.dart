import 'package:equatable/equatable.dart';

/// 커뮤니티(Q&A) 게시물 엔티티.
///
/// `getCommunityPosts`가 반환하는 raw Map(`posts` + users JOIN)을 타입 안전하게
/// 매핑한다. 사진 피드의 [Post] 엔티티와 달리 likes/comments 인터랙션이 없는
/// 카드 렌더링 전용 읽기 모델이다.
///
/// 카테고리는 STEP 2에서 `category` 컬럼으로 정규화되기 전까지 hashtags에서
/// 도출한다([categoryLabel]).
class CommunityPost extends Equatable {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String content;
  final List<String> hashtags;
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
      likes: json['likes_count'] as int? ?? 0,
      comments: json['comments_count'] as int? ?? 0,
      createdAt: createdAtStr != null
          ? DateTime.parse(createdAtStr)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  /// 운영자(관리자) 작성 글 여부 — 매거진/공지 표시용.
  bool get isAdmin => authorName == '관리자';

  /// hashtags에서 도출한 카테고리 한글 라벨. 없으면 빈 문자열.
  String get categoryLabel {
    for (final tag in hashtags) {
      switch (tag) {
        case 'qa':
          return 'Q&A';
        case 'health':
          return '건강';
        case 'training':
          return '훈련';
        case 'food':
          return '먹거리';
        case 'life':
          return '생활';
        case 'magazine':
          return '매거진';
      }
    }
    return '';
  }

  @override
  List<Object?> get props => [
        id,
        authorId,
        authorName,
        authorPhotoUrl,
        content,
        hashtags,
        likes,
        comments,
        createdAt,
      ];
}
