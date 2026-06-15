import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';
import 'package:meong_nyang_diary/features/social/presentation/utils/feed_grid_filter.dart';

Post _post(String id, {List<String> images = const []}) => Post(
      id: id,
      authorId: 'u',
      authorName: '집사',
      type: PostType.image,
      imageUrls: images,
      createdAt: DateTime(2026, 6, 15),
    );

void main() {
  group('feedGridPosts — 이미지 있는 글만 필터', () {
    test('imageUrls가 있는 글만 남긴다', () {
      final posts = [
        _post('a', images: ['https://x/a.jpg']),
        _post('b'), // 텍스트 글(이미지 없음)
        _post('c', images: ['https://x/c1.jpg', 'https://x/c2.jpg']),
      ];

      final grid = feedGridPosts(posts);

      expect(grid.map((p) => p.id), ['a', 'c']);
    });

    test('원본 리스트를 변형하지 않는다', () {
      final posts = [
        _post('a', images: ['https://x/a.jpg']),
        _post('b'),
      ];

      feedGridPosts(posts);

      // 원본은 그대로 2건 — 필터는 렌더용 사본만 생성
      expect(posts.length, 2);
    });

    test('이미지 글이 하나도 없으면 빈 리스트', () {
      final posts = [_post('b'), _post('d')];
      expect(feedGridPosts(posts), isEmpty);
    });

    test('빈 입력은 빈 출력', () {
      expect(feedGridPosts(const <Post>[]), isEmpty);
    });
  });
}
