import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/my/presentation/widgets/saved_posts_grid.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/saved_posts_page.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/utils/saved_posts_change_notifier.dart';

class _MockRepository extends Mock implements SocialRepository {}

void main() {
  late _MockRepository repository;
  late SavedPostsChangeNotifier notifier;

  setUpAll(() {
    registerFallbackValue(const SavedPostsScope.all());
  });

  setUp(() {
    repository = _MockRepository();
    notifier = SavedPostsChangeNotifier.forTest();
    when(
      () => repository.countSavedPosts(
        userId: any(named: 'userId'),
        scope: any(named: 'scope'),
      ),
    ).thenAnswer((_) async => const Right(1));
  });

  SavedPostItem item([int index = 1, PostType type = PostType.text]) =>
      SavedPostItem(
        savedPostId: 'saved-$index',
        savedAt: DateTime(2026, 7, 15),
        post: Post(
          id: 'post-$index',
          authorId: 'author',
          authorName: '보호자',
          type: type,
          content: '산책 기록',
          createdAt: DateTime(2026, 7, 14),
          isSavedByCurrentUser: true,
        ),
      );

  Future<void> pump(WidgetTester tester, {double textScale = 1}) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: SavedPostsGrid(
              repository: repository,
              userId: 'u1',
              scope: const SavedPostsScope.all(),
              changeNotifier: notifier,
            ),
          ),
        ),
        GoRoute(path: '/post/:id', builder: (_, __) => const Text('DETAIL')),
        GoRoute(path: '/feed', builder: (_, __) => const Text('FEED')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('저장 게시물을 3열 타일로 표시하고 상세로 이동한다', (tester) async {
    when(
      () => repository.getSavedPostsPage(
        userId: 'u1',
        scope: const SavedPostsScope.all(),
        cursor: null,
        limit: 30,
      ),
    ).thenAnswer(
      (_) async => Right(SavedPostsPage(items: [item()], hasMore: false)),
    );
    await pump(tester);
    expect(find.byKey(const Key('saved_post_post-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('saved_post_post-1')));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL'), findsOneWidget);
  });

  testWidgets('감정분석 배지는 150% 글자 크기에서도 읽을 수 있는 크기로 유지된다', (tester) async {
    when(
      () => repository.getSavedPostsPage(
        userId: 'u1',
        scope: const SavedPostsScope.all(),
        cursor: null,
        limit: 30,
      ),
    ).thenAnswer(
      (_) async => Right(
        SavedPostsPage(
          items: [item(1, PostType.emotionAnalysis)],
          hasMore: false,
        ),
      ),
    );

    await pump(tester, textScale: 1.5);
    final label = tester.widget<Text>(find.text('감정분석'));
    expect(label.style!.fontSize, greaterThanOrEqualTo(12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('notifier unsave는 현재 scope 타일을 즉시 제거한다', (tester) async {
    when(
      () => repository.getSavedPostsPage(
        userId: 'u1',
        scope: const SavedPostsScope.all(),
        cursor: null,
        limit: 30,
      ),
    ).thenAnswer(
      (_) async => Right(SavedPostsPage(items: [item()], hasMore: false)),
    );
    await pump(tester);
    notifier.publish(
      type: SavedPostsChangeType.unsaved,
      postId: 'post-1',
      wasSaved: true,
      isSaved: false,
    );
    await tester.pump();
    expect(find.byKey(const Key('saved_post_post-1')), findsNothing);
    expect(find.byKey(const Key('saved_posts_empty')), findsOneWidget);
  });

  testWidgets('첫 오류 뒤 notifier 재조회 성공은 오류 화면을 해제한다', (tester) async {
    var calls = 0;
    when(
      () => repository.getSavedPostsPage(
        userId: 'u1',
        scope: const SavedPostsScope.all(),
        cursor: null,
        limit: 30,
      ),
    ).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        return const Left(ServerFailure(message: 'first-failed'));
      }
      return Right(SavedPostsPage(items: [item()], hasMore: false));
    });
    await pump(tester);
    expect(find.byKey(const Key('saved_posts_error')), findsOneWidget);
    notifier.publish(
      type: SavedPostsChangeType.saved,
      postId: 'post-1',
      wasSaved: false,
      isSaved: true,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saved_posts_error')), findsNothing);
    expect(find.byKey(const Key('saved_post_post-1')), findsOneWidget);
  });

  testWidgets('notifier move-in은 현재 로드된 window 크기로 제자리 갱신한다', (tester) async {
    final cursor = SavedPostsCursor(
      savedAt: DateTime(2026, 7, 14),
      savedPostId: 'saved-30',
    );
    when(
      () => repository.getSavedPostsPage(
        userId: 'u1',
        scope: const SavedPostsScope.all(),
        cursor: null,
        limit: 30,
      ),
    ).thenAnswer(
      (_) async => Right(
        SavedPostsPage(
          items: List.generate(30, (index) => item(index + 1)),
          hasMore: true,
          nextCursor: cursor,
        ),
      ),
    );
    when(
      () => repository.getSavedPostsPage(
        userId: 'u1',
        scope: const SavedPostsScope.all(),
        cursor: cursor,
        limit: 30,
      ),
    ).thenAnswer(
      (_) async => Right(
        SavedPostsPage(
          items: [item(30), ...List.generate(20, (index) => item(index + 31))],
          hasMore: false,
        ),
      ),
    );
    when(
      () => repository.getSavedPostsPage(
        userId: 'u1',
        scope: const SavedPostsScope.all(),
        cursor: null,
        limit: 50,
      ),
    ).thenAnswer(
      (_) async => Right(
        SavedPostsPage(
          items: List.generate(50, (index) => item(index + 1)),
          hasMore: true,
          nextCursor: cursor,
        ),
      ),
    );

    await pump(tester);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    notifier.publish(
      type: SavedPostsChangeType.saved,
      postId: 'new-post',
      wasSaved: false,
      isSaved: true,
    );
    await tester.pumpAndSettle();
    verify(
      () => repository.getSavedPostsPage(
        userId: 'u1',
        scope: const SavedPostsScope.all(),
        cursor: null,
        limit: 50,
      ),
    ).called(1);
  });

  testWidgets('scope 변경 전 느린 응답은 새 scope 목록을 덮어쓰지 않는다', (tester) async {
    final oldResponse = Completer<Either<Failure, SavedPostsPage>>();
    when(
      () => repository.getSavedPostsPage(
        userId: 'u1',
        scope: const SavedPostsScope.all(),
        cursor: null,
        limit: 30,
      ),
    ).thenAnswer((_) => oldResponse.future);
    when(
      () => repository.getSavedPostsPage(
        userId: 'u1',
        scope: const SavedPostsScope.collection('c1'),
        cursor: null,
        limit: 30,
      ),
    ).thenAnswer(
      (_) async => Right(SavedPostsPage(items: [item(2)], hasMore: false)),
    );

    final scope = ValueNotifier<SavedPostsScope>(const SavedPostsScope.all());
    addTearDown(scope.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<SavedPostsScope>(
            valueListenable: scope,
            builder: (_, value, __) => SavedPostsGrid(
              repository: repository,
              userId: 'u1',
              scope: value,
              changeNotifier: notifier,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    scope.value = const SavedPostsScope.collection('c1');
    await tester.pumpAndSettle();
    oldResponse.complete(
      Right(SavedPostsPage(items: [item(1)], hasMore: false)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saved_post_post-2')), findsOneWidget);
    expect(find.byKey(const Key('saved_post_post-1')), findsNothing);
  });
}
