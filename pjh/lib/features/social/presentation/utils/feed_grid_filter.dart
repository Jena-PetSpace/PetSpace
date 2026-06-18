import '../../domain/entities/post.dart';

/// 그리드 뷰 렌더용 — 이미지가 있는 글만 추린 **새 리스트**를 반환한다.
///
/// 원본 리스트·BLoC state·페이지네이션은 절대 변형하지 않는다(렌더 시점 사본).
/// 무한스크롤 트리거는 여전히 원본 posts 기준으로 동작해야 한다.
List<Post> feedGridPosts(List<Post> posts) =>
    posts.where((p) => p.imageUrls.isNotEmpty).toList();
