/// 저장 게시글 커서 페이지네이션의 한 페이지 결과.
///
/// saved_posts.created_at(저장 시각, 응답에 `saved_at`으로 노출)을 키셋 커서로
/// 사용한다. 내 글(getUserPostsFiltered)의 created_at 커서 패턴과 동일 구조.
class SavedPostsPage {
  final List<Map<String, dynamic>> posts;

  /// 다음 페이지 조회용 커서(마지막 행의 saved_at). 없으면 null.
  final String? nextCursor;

  /// 더 불러올 페이지가 있는지(이번 페이지가 pageSize를 채웠는지).
  final bool hasMore;

  const SavedPostsPage({
    required this.posts,
    required this.nextCursor,
    required this.hasMore,
  });

  factory SavedPostsPage.fromFetched(
    List<Map<String, dynamic>> fetched, {
    required int pageSize,
  }) {
    final cursor =
        fetched.isNotEmpty ? fetched.last['saved_at'] as String? : null;
    return SavedPostsPage(
      posts: fetched,
      nextCursor: cursor,
      // 페이지를 가득 채웠고 커서가 유효할 때만 다음 페이지 시도.
      hasMore: fetched.length >= pageSize && cursor != null,
    );
  }
}
