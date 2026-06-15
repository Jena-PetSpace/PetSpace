import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/my/presentation/utils/saved_posts_pagination.dart';

Map<String, dynamic> _row(String id, String savedAt) => {
      'id': id,
      'saved_at': savedAt,
    };

void main() {
  group('SavedPostsPage.fromFetched — 커서 페이지네이션', () {
    test('가득 찬 페이지(pageSize)면 hasMore=true, 커서=마지막 saved_at', () {
      final rows = [
        _row('a', '2026-06-15T10:00:00.000Z'),
        _row('b', '2026-06-14T10:00:00.000Z'),
        _row('c', '2026-06-13T10:00:00.000Z'),
      ];

      final result = SavedPostsPage.fromFetched(rows, pageSize: 3);

      expect(result.hasMore, isTrue);
      expect(result.nextCursor, '2026-06-13T10:00:00.000Z');
      expect(result.posts.length, 3);
    });

    test('pageSize 미만이면 hasMore=false', () {
      final rows = [_row('a', '2026-06-15T10:00:00.000Z')];

      final result = SavedPostsPage.fromFetched(rows, pageSize: 3);

      expect(result.hasMore, isFalse);
      expect(result.nextCursor, '2026-06-15T10:00:00.000Z');
    });

    test('빈 페이지면 hasMore=false, 커서는 null', () {
      final result = SavedPostsPage.fromFetched(const [], pageSize: 3);

      expect(result.hasMore, isFalse);
      expect(result.nextCursor, isNull);
      expect(result.posts, isEmpty);
    });

    test('saved_at 누락 행이면 커서는 null로 안전 처리', () {
      final rows = [
        {'id': 'a'}, // saved_at 없음
      ];

      final result = SavedPostsPage.fromFetched(rows, pageSize: 3);

      expect(result.nextCursor, isNull);
      expect(result.hasMore, isFalse);
    });
  });
}
