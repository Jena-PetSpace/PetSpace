import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/bookmark_collection.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/saved_posts_page.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/utils/saved_posts_change_notifier.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/collection_picker_sheet.dart';

class _MockSocialRepository extends Mock implements SocialRepository {}

BookmarkCollection _collection(String id, String name) {
  final now = DateTime(2026, 7, 15);
  return BookmarkCollection(
    id: id,
    userId: 'viewer',
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late _MockSocialRepository repository;
  late SavedPostsChangeNotifier notifier;

  setUp(() {
    repository = _MockSocialRepository();
    notifier = SavedPostsChangeNotifier.forTest();
  });

  Future<void> pumpPicker(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    double keyboardInset = 0,
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
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              viewInsets: EdgeInsets.only(bottom: keyboardInset),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: CollectionPickerSheet(
              postId: 'post-1',
              userId: 'viewer',
              repository: repository,
              changeNotifier: notifier,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows exact location and publishes one successful move', (
    tester,
  ) async {
    when(
      () => repository.getBookmarkCollections('viewer'),
    ).thenAnswer((_) async => Right([_collection('walks', '산책 기록')]));
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
      () => repository.updateSavedPostCollection(
        postId: 'post-1',
        userId: 'viewer',
        collectionId: null,
      ),
    ).thenAnswer((_) async => const Right(null));

    await pumpPicker(tester);

    expect(find.text('분류하지 않음'), findsOneWidget);
    expect(find.text('산책 기록'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('picker_unassigned')));
    await tester.tap(find.byKey(const Key('picker_move_button')));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateSavedPostCollection(
        postId: 'post-1',
        userId: 'viewer',
        collectionId: null,
      ),
    ).called(1);
    expect(notifier.revision, 1);
    expect(notifier.lastChange?.type, SavedPostsChangeType.moved);
    expect(notifier.lastChange?.oldCollectionId, 'walks');
    expect(notifier.lastChange?.newCollectionId, isNull);
  });

  testWidgets('blocks movement when the post is not saved', (tester) async {
    when(
      () => repository.getBookmarkCollections('viewer'),
    ).thenAnswer((_) async => const Right(<BookmarkCollection>[]));
    when(
      () => repository.getSavedPostLocation(
        postId: 'post-1',
        userId: 'viewer',
      ),
    ).thenAnswer((_) async => const Right(null));

    await pumpPicker(tester);

    expect(find.byKey(const Key('picker_not_saved')), findsOneWidget);
    expect(find.text('먼저 게시물을 저장해주세요.'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('picker_move_button')),
    );
    expect(button.onPressed, isNull);
    expect(notifier.revision, 0);
  });

  testWidgets('load error retries without exposing raw failure',
      (tester) async {
    var collectionCalls = 0;
    when(() => repository.getBookmarkCollections('viewer'))
        .thenAnswer((_) async {
      collectionCalls++;
      if (collectionCalls == 1) {
        return const Left(ServerFailure(message: 'repository-secret'));
      }
      return Right([_collection('walks', '산책 기록')]);
    });
    when(
      () => repository.getSavedPostLocation(
        postId: 'post-1',
        userId: 'viewer',
      ),
    ).thenAnswer(
      (_) async => const Right(SavedPostLocation(savedPostId: 'saved-1')),
    );

    await pumpPicker(tester);

    expect(find.byKey(const Key('picker_load_error')), findsOneWidget);
    expect(find.textContaining('repository-secret'), findsNothing);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('산책 기록'), findsOneWidget);
    expect(find.byKey(const Key('picker_load_error')), findsNothing);
  });

  testWidgets('create failure keeps input and retry auto-selects collection', (
    tester,
  ) async {
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
    var createCalls = 0;
    when(
      () => repository.createBookmarkCollection(
        userId: 'viewer',
        name: '산책 기록',
      ),
    ).thenAnswer((_) async {
      createCalls++;
      if (createCalls == 1) {
        return const Left(ServerFailure(message: 'create-secret'));
      }
      return Right(_collection('walks', '산책 기록'));
    });

    await pumpPicker(tester);
    await tester.tap(find.byKey(const Key('picker_create_collection')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('picker_collection_name')),
      '산책 기록',
    );
    await tester.tap(find.byKey(const Key('picker_create_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('picker_create_error')), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('picker_collection_name')),
    );
    expect(field.controller?.text, '산책 기록');
    expect(find.textContaining('create-secret'), findsNothing);

    await tester.tap(find.byKey(const Key('picker_create_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('picker_collection_walks')), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(createCalls, 2);
  });

  testWidgets('move failure retains selection and retry publishes once', (
    tester,
  ) async {
    when(
      () => repository.getBookmarkCollections('viewer'),
    ).thenAnswer((_) async => Right([_collection('walks', '산책 기록')]));
    when(
      () => repository.getSavedPostLocation(
        postId: 'post-1',
        userId: 'viewer',
      ),
    ).thenAnswer(
      (_) async => const Right(SavedPostLocation(savedPostId: 'saved-1')),
    );
    var moveCalls = 0;
    when(
      () => repository.updateSavedPostCollection(
        postId: 'post-1',
        userId: 'viewer',
        collectionId: 'walks',
      ),
    ).thenAnswer((_) async {
      moveCalls++;
      if (moveCalls == 1) {
        return const Left(ServerFailure(message: 'move-secret'));
      }
      return const Right(null);
    });

    await pumpPicker(tester);
    await tester.tap(find.byKey(const Key('picker_collection_walks')));
    await tester.tap(find.byKey(const Key('picker_move_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('picker_move_error')), findsOneWidget);
    expect(find.byKey(const Key('picker_collection_walks')), findsOneWidget);
    expect(find.textContaining('move-secret'), findsNothing);
    expect(notifier.revision, 0);

    await tester.tap(find.byKey(const Key('picker_move_button')));
    await tester.pumpAndSettle();
    expect(moveCalls, 2);
    expect(notifier.revision, 1);
  });

  testWidgets('small screen, large text and keyboard keep input and CTA usable',
      (
    tester,
  ) async {
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

    await pumpPicker(
      tester,
      size: const Size(320, 568),
      textScale: 1.5,
      keyboardInset: 180,
    );
    await tester.tap(find.byKey(const Key('picker_create_collection')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('picker_collection_name')), findsOneWidget);
    expect(find.byKey(const Key('picker_move_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360x800 layout keeps the location options and CTA usable', (
    tester,
  ) async {
    when(
      () => repository.getBookmarkCollections('viewer'),
    ).thenAnswer((_) async => Right([_collection('walks', '산책 기록')]));
    when(
      () => repository.getSavedPostLocation(
        postId: 'post-1',
        userId: 'viewer',
      ),
    ).thenAnswer(
      (_) async => const Right(SavedPostLocation(savedPostId: 'saved-1')),
    );

    await pumpPicker(tester, size: const Size(360, 800));

    expect(find.text('분류하지 않음'), findsOneWidget);
    expect(find.text('산책 기록'), findsOneWidget);
    expect(find.byKey(const Key('picker_move_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('move pending disables collection creation submission', (
    tester,
  ) async {
    when(
      () => repository.getBookmarkCollections('viewer'),
    ).thenAnswer((_) async => Right([_collection('walks', '산책 기록')]));
    when(
      () => repository.getSavedPostLocation(
        postId: 'post-1',
        userId: 'viewer',
      ),
    ).thenAnswer(
      (_) async => const Right(SavedPostLocation(savedPostId: 'saved-1')),
    );
    final moveCompleter = Completer<Either<Failure, void>>();
    when(
      () => repository.updateSavedPostCollection(
        postId: 'post-1',
        userId: 'viewer',
        collectionId: 'walks',
      ),
    ).thenAnswer((_) => moveCompleter.future);

    await pumpPicker(tester);
    await tester.tap(find.byKey(const Key('picker_create_collection')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('picker_collection_name')),
      '새 컬렉션',
    );
    await tester.tap(find.byKey(const Key('picker_collection_walks')));
    await tester.tap(find.byKey(const Key('picker_move_button')));
    await tester.pump();

    final createButton = tester.widget<FilledButton>(
      find.byKey(const Key('picker_create_button')),
    );
    expect(createButton.onPressed, isNull);
    verifyNever(
      () => repository.createBookmarkCollection(
        userId: 'viewer',
        name: any(named: 'name'),
      ),
    );

    moveCompleter.complete(const Right(null));
    await tester.pumpAndSettle();
  });
}
