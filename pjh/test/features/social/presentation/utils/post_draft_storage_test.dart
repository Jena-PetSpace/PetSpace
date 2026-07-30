import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meong_nyang_diary/features/social/presentation/utils/post_draft_storage.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('피드와 커뮤니티 임시저장은 서로 다른 namespace를 사용한다', () async {
    await PostDraftStorage.saveFeed(
      content: '산책 사진',
      hashtags: const ['산책'],
    );
    await PostDraftStorage.saveCommunity(
      title: '산책 질문',
      content: '몇 시가 좋을까요?',
      category: 'qa',
    );

    final feed = await PostDraftStorage.loadFeed();
    final community = await PostDraftStorage.loadCommunity();

    expect(feed?.content, '산책 사진');
    expect(feed?.hashtags, const ['산책']);
    expect(community?.title, '산책 질문');
    expect(community?.content, '몇 시가 좋을까요?');
    expect(community?.category, 'qa');

    await PostDraftStorage.clearFeed();
    expect(await PostDraftStorage.loadFeed(), isNull);
    expect((await PostDraftStorage.loadCommunity())?.title, '산책 질문');

    await PostDraftStorage.clearCommunity();
    expect(await PostDraftStorage.loadCommunity(), isNull);
  });

  test('기존 무-namespace draft는 피드 draft로만 복원한다', () async {
    SharedPreferences.setMockInitialValues({
      'post_draft_content': '기존 피드 본문',
      'post_draft_hashtags': <String>['기존'],
    });

    final feed = await PostDraftStorage.loadFeed();

    expect(feed?.content, '기존 피드 본문');
    expect(feed?.hashtags, const ['기존']);
    expect(await PostDraftStorage.loadCommunity(), isNull);
  });
}
