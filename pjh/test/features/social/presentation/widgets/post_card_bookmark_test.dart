import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/config/injection_container.dart';
import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/bookmark_collection.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/saved_posts_page.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/utils/saved_posts_change_notifier.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/post_card.dart';

class _MockSocialRepository extends Mock implements SocialRepository {}

Post _post({bool saved = false}) => Post(
      id: 'post-1',
      authorId: 'author-1',
      authorName: 'Mina',
      type: PostType.text,
      content: 'A trustworthy post',
      createdAt: DateTime(2026, 7, 15),
      isSavedByCurrentUser: saved,
    );

void main() {
  late _MockSocialRepository repository;
  late SavedPostsChangeNotifier notifier;

  setUp(() async {
    repository = _MockSocialRepository();
    notifier = SavedPostsChangeNotifier.forTest();
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

  Future<void> pumpCard(WidgetTester tester, {required bool saved}) async {
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
            body: PostCard(
              post: _post(saved: saved),
              currentUserId: 'viewer',
              onLike: () {},
              onComment: () {},
              onShare: () {},
              repository: repository,
              savedPostsNotifier: notifier,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('serializes save and publishes only after server success', (
    tester,
  ) async {
    final completer = Completer<Either<Failure, void>>();
    when(
      () => repository.savePost('post-1', 'viewer'),
    ).thenAnswer((_) => completer.future);
    when(
      () => repository.getBookmarkCollections('viewer'),
    ).thenAnswer((_) async => const Right(<BookmarkCollection>[]));
    when(
      () => repository.getSavedPostLocation(
        postId: 'post-1',
        userId: 'viewer',
      ),
    ).thenAnswer(
      (_) async => const Right(SavedPostLocation(savedPostId: 'saved-1')),
    );

    await pumpCard(tester, saved: false);
    final bookmark = find.byKey(const Key('post_card_bookmark_button'));
    await tester.tap(bookmark);
    await tester.pump();
    await tester.tap(bookmark, warnIfMissed: false);
    await tester.pump();

    verify(() => repository.savePost('post-1', 'viewer')).called(1);
    expect(notifier.revision, 0);

    completer.complete(const Right(null));
    await tester.pumpAndSettle();

    expect(notifier.revision, 1);
    expect(notifier.lastChange?.type, SavedPostsChangeType.saved);
    expect(find.text('게시물을 저장했어요'), findsOneWidget);
    expect(find.text('컬렉션 선택'), findsOneWidget);

    await tester.tap(find.text('컬렉션 선택'));
    await tester.pumpAndSettle();
    expect(find.text('저장 위치 선택'), findsOneWidget);
  });

  testWidgets('save failure keeps unsaved state and never opens picker', (
    tester,
  ) async {
    when(
      () => repository.savePost('post-1', 'viewer'),
    ).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'save-secret')),
    );

    await pumpCard(tester, saved: false);
    final bookmark = find.byKey(const Key('post_card_bookmark_button'));
    expect(tester.getSize(bookmark), const Size(44, 44));
    expect(find.bySemanticsLabel('게시글 저장'), findsOneWidget);
    await tester.tap(bookmark);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_border_outlined), findsOneWidget);
    expect(find.text('컬렉션 선택'), findsNothing);
    expect(find.textContaining('save-secret'), findsNothing);
    expect(notifier.revision, 0);
  });

  testWidgets('saved tap exposes menu and failed unsave keeps bookmark', (
    tester,
  ) async {
    when(
      () => repository.getSavedPostLocation(
        postId: 'post-1',
        userId: 'viewer',
      ),
    ).thenAnswer(
      (_) async => const Right(
        SavedPostLocation(savedPostId: 'saved-1', collectionId: 'walks'),
      ),
    );
    when(
      () => repository.unsavePost('post-1', 'viewer'),
    ).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'repository-secret')),
    );

    await pumpCard(tester, saved: true);
    await tester.tap(find.byKey(const Key('post_card_bookmark_button')));
    await tester.pumpAndSettle();

    expect(find.text('컬렉션 변경'), findsOneWidget);
    expect(find.text('저장 취소'), findsOneWidget);
    await tester.tap(find.byKey(const Key('post_card_unsave')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.textContaining('repository-secret'), findsNothing);
    expect(notifier.revision, 0);
  });

  testWidgets('successful unsave publishes old collection exactly once', (
    tester,
  ) async {
    when(
      () => repository.getSavedPostLocation(
        postId: 'post-1',
        userId: 'viewer',
      ),
    ).thenAnswer(
      (_) async => const Right(
        SavedPostLocation(savedPostId: 'saved-1', collectionId: 'walks'),
      ),
    );
    when(
      () => repository.unsavePost('post-1', 'viewer'),
    ).thenAnswer((_) async => const Right(null));

    await pumpCard(tester, saved: true);
    await tester.tap(find.byKey(const Key('post_card_bookmark_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('post_card_unsave')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_border_outlined), findsOneWidget);
    expect(notifier.revision, 1);
    expect(notifier.lastChange?.type, SavedPostsChangeType.unsaved);
    expect(notifier.lastChange?.oldCollectionId, 'walks');
  });
}
