import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/config/injection_container.dart';
import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/controllers/post_interaction_coordinator.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/post_card_connector.dart';

class _MockRepository extends Mock implements SocialRepository {}

Post _post({
  bool liked = false,
  int likes = 0,
  int comments = 1,
  String authorId = 'viewer',
}) =>
    Post(
      id: 'post-1',
      authorId: authorId,
      authorName: 'Mina',
      type: PostType.text,
      content: 'hello',
      createdAt: DateTime(2026, 7, 19),
      likesCount: likes,
      commentsCount: comments,
      isLikedByCurrentUser: liked,
      location: '서울숲',
      locationLat: 37.0,
      locationLng: 127.0,
    );

void main() {
  late _MockRepository repository;
  late PostInteractionCoordinator coordinator;
  late List<Post> changed;
  late List<String> removed;

  setUp(() async {
    repository = _MockRepository();
    coordinator = PostInteractionCoordinator(repository: repository);
    changed = [];
    removed = [];
    if (sl.isRegistered<SocialRepository>()) {
      await sl.unregister<SocialRepository>();
    }
    sl.registerSingleton<SocialRepository>(repository);
    when(() => repository.getUserStreak(any())).thenAnswer(
      (_) async => const Right(0),
    );
  });

  tearDown(() async {
    if (sl.isRegistered<SocialRepository>()) {
      await sl.unregister<SocialRepository>();
    }
  });

  Future<void> pumpConnector(
    WidgetTester tester, {
    Post? post,
    Future<bool> Function()? commentsLauncher,
    Future<bool?> Function()? detailLauncher,
    Future<void> Function(String text)? shareHandler,
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
              child: PostCardConnector(
                post: post ?? _post(),
                currentUserId: 'viewer',
                repository: repository,
                coordinator: coordinator,
                commentsLauncher: commentsLauncher,
                detailLauncher: detailLauncher,
                shareHandler: shareHandler,
                shareText: '서울숲 게시물을 확인해보세요.',
                onPostChanged: changed.add,
                onPostRemoved: removed.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('comment close reconciles the authoritative comment count',
      (tester) async {
    when(() => repository.getPost('post-1')).thenAnswer(
      (_) async => Right(_post(comments: 4)),
    );
    await pumpConnector(tester, commentsLauncher: () async => true);

    await tester.tap(find.byKey(const Key('post_card_comment_button')));
    await tester.pumpAndSettle();

    expect(changed.last.commentsCount, 4);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets(
      'detail return reconciles post, liked, and saved fields independently',
      (tester) async {
    when(() => repository.getPost('post-1')).thenAnswer(
      (_) async => Right(_post(likes: 3, comments: 4)),
    );
    when(
      () => repository.isPostLiked('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(true));
    when(
      () => repository.isPostSaved('post-1', 'viewer'),
    ).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'saved-secret')),
    );

    await pumpConnector(tester, detailLauncher: () async => false);
    await tester.tap(find.byKey(const Key('post_card_open_detail')));
    await tester.pumpAndSettle();

    expect(changed.last.likesCount, 3);
    expect(changed.last.commentsCount, 4);
    expect(changed.last.isLikedByCurrentUser, isTrue);
    expect(changed.last.isSavedByCurrentUser, isFalse);
    expect(find.textContaining('saved-secret'), findsNothing);
    expect(find.textContaining('일부를 새로고침'), findsOneWidget);
  });

  testWidgets('detail removal result removes the card without stale refresh', (
    tester,
  ) async {
    await pumpConnector(tester, detailLauncher: () async => true);

    await tester.tap(find.byKey(const Key('post_card_open_detail')));
    await tester.pumpAndSettle();

    expect(removed, ['post-1']);
    verifyNever(() => repository.getPost('post-1'));
    verifyNever(() => repository.isPostLiked('post-1', 'viewer'));
    verifyNever(() => repository.isPostSaved('post-1', 'viewer'));
  });

  testWidgets('like is sent once through the shared coordinator',
      (tester) async {
    when(() => repository.likePost('post-1', 'viewer')).thenAnswer(
      (_) async => const Right(null),
    );
    when(() => repository.getPost('post-1')).thenAnswer(
      (_) async => Right(_post(liked: true, likes: 1)),
    );
    when(() => repository.isPostLiked('post-1', 'viewer')).thenAnswer(
      (_) async => const Right(true),
    );
    await pumpConnector(tester);

    await tester.tap(find.byKey(const Key('post_card_like_button')));
    await tester.tap(find.byKey(const Key('post_card_like_button')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    verify(() => repository.likePost('post-1', 'viewer')).called(1);
    expect(changed.last.likesCount, 1);
  });

  testWidgets('location share text contains no coordinate, radius, or emoji',
      (tester) async {
    String? shared;
    await pumpConnector(
      tester,
      shareHandler: (text) async => shared = text,
    );

    await tester.tap(find.byKey(const Key('post_card_share_button')));
    await tester.pump();

    expect(shared, '서울숲 게시물을 확인해보세요.');
    expect(shared, isNot(contains('37.')));
    expect(shared, isNot(contains('500')));
    expect(shared, isNot(contains('📍')));
  });

  testWidgets('confirmed deletion removes the post once', (tester) async {
    when(() => repository.deletePost('post-1')).thenAnswer(
      (_) async => const Right(null),
    );
    await pumpConnector(tester);

    await tester.tap(find.byTooltip('게시물 옵션'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();

    verify(() => repository.deletePost('post-1')).called(1);
    expect(removed, ['post-1']);
  });

  testWidgets('block removes once on success and never on failure', (
    tester,
  ) async {
    var succeeds = true;
    when(() => repository.blockUser('author-1')).thenAnswer(
      (_) async => succeeds
          ? const Right(null)
          : const Left(ServerFailure(message: 'private failure')),
    );

    Future<void> confirmBlock() async {
      await tester.tap(find.byTooltip('게시물 옵션'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.person_off_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('social_user_block_action')));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      await tester.tap(
        find.descendant(of: dialog, matching: find.byType(TextButton)).last,
      );
      await tester.pumpAndSettle();
    }

    await pumpConnector(tester, post: _post(authorId: 'author-1'));
    await confirmBlock();
    expect(removed, ['post-1']);

    removed.clear();
    succeeds = false;
    await pumpConnector(tester, post: _post(authorId: 'author-1'));
    await confirmBlock();

    verify(() => repository.blockUser('author-1')).called(2);
    expect(removed, isEmpty);
  });
}
