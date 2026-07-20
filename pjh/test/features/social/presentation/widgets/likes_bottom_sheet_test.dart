import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post_likes_page.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/likes_bottom_sheet.dart';

class _MockSocialRepository extends Mock implements SocialRepository {}

const _mina = PostLikeUser(
  likeId: 'like-1',
  userId: 'mina',
  displayName: 'Mina',
  username: 'mina',
  relation: PostLikeRelation.following,
);

void main() {
  late _MockSocialRepository repository;

  setUp(() {
    repository = _MockSocialRepository();
  });

  Future<void> pumpSheet(WidgetTester tester) async {
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
            body: LikesBottomSheet(
              postId: 'post-1',
              currentUserId: 'viewer',
              repository: repository,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('distinguishes an empty list from an empty search result',
      (tester) async {
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
    when(
      () => repository.getPostLikesPage(
        postId: 'post-1',
        currentUserId: 'viewer',
        cursor: null,
        query: 'nobody',
        limit: 20,
      ),
    ).thenAnswer(
      (_) async => const Right(PostLikesPage(items: [], hasMore: false)),
    );

    await pumpSheet(tester);
    expect(find.byKey(const Key('likes_empty')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('likes_search_field')),
      '@nobody',
    );
    await tester.pump(const Duration(milliseconds: 299));
    verifyNever(
      () => repository.getPostLikesPage(
        postId: 'post-1',
        currentUserId: 'viewer',
        cursor: null,
        query: 'nobody',
        limit: 20,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('likes_search_empty')), findsOneWidget);
  });

  testWidgets('failed unfollow restores only the affected row safely',
      (tester) async {
    when(
      () => repository.getPostLikesPage(
        postId: 'post-1',
        currentUserId: 'viewer',
        cursor: null,
        query: '',
        limit: 20,
      ),
    ).thenAnswer(
      (_) async => const Right(
        PostLikesPage(items: [_mina], hasMore: false),
      ),
    );
    when(
      () => repository.unfollowUser('viewer', 'mina'),
    ).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'database-secret')),
    );

    await pumpSheet(tester);
    expect(find.text('팔로잉'), findsOneWidget);
    await tester.tap(find.byKey(const Key('likes_follow_mina')));
    await tester.pumpAndSettle();

    expect(find.text('팔로잉'), findsOneWidget);
    expect(find.textContaining('database-secret'), findsNothing);
    expect(find.textContaining('다시 시도'), findsOneWidget);
  });

  testWidgets('initial failure exposes a retry without raw repository text',
      (tester) async {
    when(
      () => repository.getPostLikesPage(
        postId: 'post-1',
        currentUserId: 'viewer',
        cursor: null,
        query: '',
        limit: 20,
      ),
    ).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'repository-secret')),
    );

    await pumpSheet(tester);

    expect(find.byKey(const Key('likes_initial_error')), findsOneWidget);
    expect(find.textContaining('repository-secret'), findsNothing);
    expect(find.text('다시 시도'), findsOneWidget);
  });
}
