import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/social/domain/entities/post_likes_page.dart';

void main() {
  test('cursor and page equality include stable pagination fields', () {
    final createdAt = DateTime.utc(2026, 7, 18);
    final cursor = PostLikesCursor(createdAt: createdAt, likeId: 'like-2');
    const item = PostLikeUser(
      likeId: 'like-2',
      userId: 'user-2',
      displayName: 'Mina',
      username: 'mina',
      relation: PostLikeRelation.following,
    );

    expect(
      PostLikesPage(
        items: const [item],
        hasMore: true,
        nextCursor: cursor,
      ),
      PostLikesPage(
        items: const [item],
        hasMore: true,
        nextCursor: PostLikesCursor(
          createdAt: createdAt,
          likeId: 'like-2',
        ),
      ),
    );
  });

  test('copyWith changes only the requested relationship', () {
    const item = PostLikeUser(
      likeId: 'like-1',
      userId: 'user-1',
      displayName: 'Joon',
      relation: PostLikeRelation.notFollowing,
    );

    final following = item.copyWith(relation: PostLikeRelation.following);

    expect(following.relation, PostLikeRelation.following);
    expect(following.likeId, item.likeId);
    expect(following.userId, item.userId);
    expect(following.displayName, item.displayName);
  });
}
