import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/social/domain/entities/social_user.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/profile_bloc.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/profile_page.dart';

class _MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

class _MockSocialRepository extends Mock implements SocialRepository {}

void main() {
  late _MockProfileBloc profileBloc;
  late _MockSocialRepository repository;
  late SocialUser user;

  setUp(() {
    profileBloc = _MockProfileBloc();
    repository = _MockSocialRepository();
    final now = DateTime(2026, 7, 15);
    user = SocialUser(
      id: 'user-2',
      email: 'private@example.com',
      displayName: 'Mina',
      username: 'mina',
      bio: 'A concise public introduction.',
      createdAt: now,
      updatedAt: now,
      postsCount: 3,
      followersCount: 12,
      followingCount: 7,
    );
    final loaded = ProfileLoaded(user: user, isFollowing: false);
    when(() => profileBloc.state).thenReturn(loaded);
    whenListen(
      profileBloc,
      const Stream<ProfileState>.empty(),
      initialState: loaded,
    );
    when(
      () => repository.getUserPostsFiltered(
        authorId: any(named: 'authorId'),
        petId: any(named: 'petId'),
        beforeCreatedAt: any(named: 'beforeCreatedAt'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Right(<Map<String, dynamic>>[]));
  });

  testWidgets('renders compact identity and opens a dedicated follower route',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => BlocProvider<ProfileBloc>.value(
            value: profileBloc,
            child: ProfilePage(
              userId: 'user-2',
              currentUserId: 'viewer',
              socialRepository: repository,
            ),
          ),
        ),
        GoRoute(
          path: '/followers/:id',
          builder: (_, state) =>
              Scaffold(body: Text("FOLLOWERS ${state.pathParameters['id']}")),
        ),
        GoRoute(
          path: '/following/:id',
          builder: (_, state) =>
              Scaffold(body: Text("FOLLOWING ${state.pathParameters['id']}")),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mina'), findsOneWidget);
    expect(find.text('@mina'), findsOneWidget);
    expect(find.text('A concise public introduction.'), findsOneWidget);
    expect(find.byKey(const Key('profile_follow_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile_stat_followers')));
    await tester.pumpAndSettle();
    expect(find.text('FOLLOWERS user-2'), findsOneWidget);
  });
}
