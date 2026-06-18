import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/social/data/models/post_model.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';

void main() {
  group('PostModel category 쓰기 경로', () {
    test('category가 있는 community 글은 toJson에 category를 포함한다', () {
      final post = Post(
        id: '',
        authorId: 'u-1',
        authorName: '집사',
        type: PostType.text,
        content: '제목\n\n본문',
        category: 'health',
        createdAt: DateTime(2026, 6, 15),
      );

      final json = PostModel.fromEntity(post).toJson();

      expect(json['category'], 'health');
      expect(json['post_type'], 'community');
    });

    test('category가 없는 사진 글은 toJson에 category 키를 넣지 않는다', () {
      final post = Post(
        id: '',
        authorId: 'u-1',
        authorName: '집사',
        type: PostType.image,
        imageUrls: const ['https://x/a.jpg'],
        createdAt: DateTime(2026, 6, 15),
      );

      final json = PostModel.fromEntity(post).toJson();

      expect(json.containsKey('category'), false);
    });
  });

  group('PostModel category 읽기 경로', () {
    test('fromJson이 category 컬럼을 매핑한다', () {
      final model = PostModel.fromJson({
        'id': 'p-1',
        'author_id': 'u-1',
        'caption': '본문',
        'category': 'food',
        'created_at': '2026-06-15T00:00:00.000Z',
      });

      expect(model.category, 'food');
    });
  });
}
