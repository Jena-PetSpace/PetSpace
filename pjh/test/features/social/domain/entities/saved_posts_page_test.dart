import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/saved_posts_page.dart';

void main() {
  test('저장 범위는 전체·미분류·컬렉션을 명시적으로 구분한다', () {
    expect(const SavedPostsScope.all().type, SavedPostsScopeType.all);
    expect(const SavedPostsScope.unassigned().type,
        SavedPostsScopeType.unassigned);
    const collection = SavedPostsScope.collection('collection-1');
    expect(collection.type, SavedPostsScopeType.collection);
    expect(collection.collectionId, 'collection-1');
  });

  test('2열 커서는 저장 시각과 저장 행 id를 함께 보존한다', () {
    final time = DateTime.utc(2026, 7, 15);
    final cursor = SavedPostsCursor(savedAt: time, savedPostId: 'saved-1');
    expect(cursor, SavedPostsCursor(savedAt: time, savedPostId: 'saved-1'));
  });
}
