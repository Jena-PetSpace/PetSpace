import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/follow.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/followers_page.dart';

class _MockSocialRepository extends Mock implements SocialRepository {}

Follow _follow({
  required String id,
  String name = 'Mina',
  String username = 'mina',
  bool follower = true,
}) {
  final now = DateTime(2026, 7, 15);
  return Follow(
    id: id,
    followerId: follower ? id : 'owner',
    followingId: follower ? 'owner' : id,
    followerName: follower ? name : 'Owner',
    followingName: follower ? 'Owner' : name,
    followerUsername: follower ? username : null,
    followingUsername: follower ? null : username,
    status: FollowStatus.accepted,
    createdAt: now,
  );
}

void main() {
  late _MockSocialRepository repository;

  setUp(() {
    repository = _MockSocialRepository();
    when(
      () => repository.getFollowersPage(
        userId: any(named: 'userId'),
        limit: any(named: 'limit'),
        lastUserId: any(named: 'lastUserId'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) async => Right([_follow(id: 'follower-1')]));
    when(
      () => repository.getFollowingPage(
        userId: any(named: 'userId'),
        limit: any(named: 'limit'),
        lastUserId: any(named: 'lastUserId'),
        query: any(named: 'query'),
      ),
    ).thenAnswer(
      (_) async => Right([
        _follow(
          id: 'following-1',
          name: 'Joon',
          username: 'joon',
          follower: false,
        ),
      ]),
    );
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: FollowersPage(
            userId: 'owner',
            userName: 'Owner',
            repository: repository,
            searchDebounce: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('loads each tab independently and renders username',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('Mina'), findsOneWidget);
    expect(find.text('@mina'), findsOneWidget);
    verify(
      () => repository.getFollowersPage(
        userId: 'owner',
        limit: 20,
        lastUserId: null,
        query: '',
      ),
    ).called(1);
    verify(
      () => repository.getFollowingPage(
        userId: 'owner',
        limit: 20,
        lastUserId: null,
        query: '',
      ),
    ).called(1);

    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Joon'), findsOneWidget);
    expect(find.text('@joon'), findsOneWidget);
  });

  testWidgets('normalizes at-sign search and renders matching result',
      (tester) async {
    await pumpPage(tester);
    clearInteractions(repository);

    await tester.enterText(
      find.byKey(const Key('follow_search_field')),
      '@mina',
    );
    await tester.pump();
    await tester.pumpAndSettle();

    verify(
      () => repository.getFollowersPage(
        userId: 'owner',
        limit: 20,
        lastUserId: null,
        query: 'mina',
      ),
    ).called(1);
  });

  testWidgets('shows a retry state instead of a false empty state',
      (tester) async {
    when(
      () => repository.getFollowersPage(
        userId: any(named: 'userId'),
        limit: any(named: 'limit'),
        lastUserId: any(named: 'lastUserId'),
        query: any(named: 'query'),
      ),
    ).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'internal-secret')),
    );

    await pumpPage(tester);

    expect(find.byKey(const Key('followers_error')), findsOneWidget);
    expect(find.byKey(const Key('followers_empty')), findsNothing);
    expect(find.textContaining('internal-secret'), findsNothing);
  });
}
