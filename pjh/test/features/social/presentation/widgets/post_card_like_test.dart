import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post_likes_page.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/post_card.dart';

class _MockSocialRepository extends Mock implements SocialRepository {}

Post _post({bool liked = false, int count = 0}) => Post(
      id: 'post-1',
      authorId: 'author-1',
      authorName: 'Mina',
      type: PostType.image,
      imageUrls: const ['https://example.com/pet.jpg'],
      likesCount: count,
      isLikedByCurrentUser: liked,
      createdAt: DateTime(2026, 7, 18),
    );

void main() {
  late _MockSocialRepository repository;

  setUp(() {
    repository = _MockSocialRepository();
    when(() => repository.getUserStreak(any())).thenAnswer(
      (_) async => const Right(0),
    );
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    required Post post,
    required VoidCallback onLike,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostCard(
                post: post,
                currentUserId: 'viewer',
                onLike: onLike,
                onComment: () {},
                onShare: () {},
                repository: repository,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('zero like count still opens the likes list', (tester) async {
    when(
      () => repository.getPostLikesPage(
        postId: 'post-1',
        currentUserId: 'viewer',
        cursor: null,
        query: '',
        limit: 20,
      ),
    ).thenAnswer(
      (_) async => const Right(PostLikesPage(items: [], hasMore: false)),
    );

    await pumpCard(tester, post: _post(), onLike: () {});
    final count = find.byKey(const Key('post_card_likes_count'));
    expect(tester.getSize(count).height, 44);
    await tester.tap(count);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('좋아요'), findsOneWidget);
    expect(find.byKey(const Key('likes_empty')), findsOneWidget);
  });

  testWidgets('double tap adds a like only when not already liked',
      (tester) async {
    var likeCalls = 0;
    await pumpCard(
      tester,
      post: _post(),
      onLike: () => likeCalls++,
    );

    final media = find.byKey(const Key('post_card_media_0'));
    await tester.tap(media);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(media);
    await tester.pump();
    expect(likeCalls, 1);
    await tester.pump(const Duration(milliseconds: 850));

    await pumpCard(
      tester,
      post: _post(liked: true, count: 1),
      onLike: () => likeCalls++,
    );
    await tester.tap(media);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(media);
    await tester.pump();
    expect(likeCalls, 1);
    await tester.pump(const Duration(milliseconds: 850));
  });
}
