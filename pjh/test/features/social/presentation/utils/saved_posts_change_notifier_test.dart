import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/social/presentation/utils/saved_posts_change_notifier.dart';

void main() {
  test('성공 변경을 발행할 때 revision이 단조 증가하고 payload를 보존한다', () {
    final notifier = SavedPostsChangeNotifier.forTest();
    var calls = 0;
    notifier.addListener(() => calls++);
    notifier.publish(
      type: SavedPostsChangeType.saved,
      postId: 'post-1',
      wasSaved: false,
      isSaved: true,
    );
    notifier.publish(
      type: SavedPostsChangeType.moved,
      postId: 'post-1',
      wasSaved: true,
      isSaved: true,
      newCollectionId: 'collection-1',
    );
    expect(calls, 2);
    expect(notifier.revision, 2);
    expect(notifier.lastChange?.newCollectionId, 'collection-1');
  });
}
