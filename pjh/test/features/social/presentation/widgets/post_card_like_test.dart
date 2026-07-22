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

Post _post({
  bool liked = false,
  int count = 0,
  String? location,
}) =>
    Post(
      id: 'post-1',
      authorId: 'author-1',
      authorName: 'Mina',
      type: PostType.image,
      imageUrls: const ['https://example.com/pet.jpg'],
      likesCount: count,
      isLikedByCurrentUser: liked,
      location: location,
      locationLat: location == null ? null : 37,
      locationLng: location == null ? null : 127,
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
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
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

    expect(find.text('좋아요 0'), findsOneWidget);
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

  testWidgets(
      'comment, share, save, and long location keep 44dp targets at 150%',
      (tester) async {
    await pumpCard(
      tester,
      post: _post(
        location: '아주 긴 공개 장소 이름 서울숲 반려동물 산책길',
      ),
      onLike: () {},
      size: const Size(320, 568),
      textScale: 1.5,
    );

    expect(
      tester.getSize(find.byKey(const Key('post_card_comment_button'))).height,
      44,
    );
    expect(
      tester.getSize(find.byKey(const Key('post_card_comment_button'))).width,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(const Key('post_card_share_button'))).height,
      44,
    );
    expect(
      tester.getSize(find.byKey(const Key('post_card_bookmark_button'))).height,
      44,
    );
    expect(
      tester.getSize(find.byKey(const Key('post_card_location_button'))).height,
      44,
    );
    expect(
      find.text('아주 긴 공개 장소 이름 서울숲 반려동물 산책길'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
