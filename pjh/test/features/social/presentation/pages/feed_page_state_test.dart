import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/auth/domain/entities/user.dart';
import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/feed_bloc.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/feed_page.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/post_card_connector.dart';

class _MockFeedBloc extends MockBloc<FeedEvent, FeedState>
    implements FeedBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockSocialRepository extends Mock implements SocialRepository {}

class _FakeFeedEvent extends Fake implements FeedEvent {}

Post _post({int commentsCount = 3}) => Post(
      id: 'post-1',
      authorId: 'author-1',
      authorName: 'Mina',
      type: PostType.image,
      content: 'hello',
      imageUrls: const [],
      createdAt: DateTime(2026, 7, 19),
      commentsCount: commentsCount,
    );

User _user() => User(
      uid: 'viewer',
      email: 'viewer@example.com',
      displayName: 'Viewer',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      pets: const [],
      following: const [],
      followers: const [],
      settings: const UserSettings(
        notificationsEnabled: true,
        privacyLevel: PrivacyLevel.public,
        showEmotionAnalysisToPublic: false,
      ),
    );

void main() {
  setUpAll(() => registerFallbackValue(_FakeFeedEvent()));

  testWidgets('load-more retry preserves followingOnly', (tester) async {
    final feedBloc = _MockFeedBloc();
    final authBloc = _MockAuthBloc();
    final controller = StreamController<FeedState>.broadcast();
    addTearDown(controller.close);
    const initial = FeedLoaded(posts: [], hasReachedMax: false);
    when(() => feedBloc.state).thenReturn(initial);
    whenListen(feedBloc, controller.stream, initialState: initial);
    final authState = AuthAuthenticated(_user());
    when(() => authBloc.state).thenReturn(authState);
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: authState,
    );

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MultiBlocProvider(
          providers: [
            BlocProvider<FeedBloc>.value(value: feedBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: const MaterialApp(
            home: Scaffold(body: FeedPage(followingOnly: true)),
          ),
        ),
      ),
    );
    await tester.pump();
    clearInteractions(feedBloc);

    controller.add(
      const FeedLoaded(
        posts: [],
        hasReachedMax: false,
        error: '다음 게시물을 불러오지 못했어요.',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('재시도'));
    await tester.pump();

    verify(
      () => feedBloc.add(
        const LoadMorePostsRequested(
          userId: null,
          followingOnly: true,
        ),
      ),
    ).called(1);
  });

  testWidgets('authoritative comment override yields to a newer bloc count', (
    tester,
  ) async {
    final feedBloc = _MockFeedBloc();
    final authBloc = _MockAuthBloc();
    final repository = _MockSocialRepository();
    final controller = StreamController<FeedState>.broadcast();
    addTearDown(controller.close);
    final initial = FeedLoaded(posts: [_post()], hasReachedMax: true);
    when(() => feedBloc.state).thenReturn(initial);
    whenListen(feedBloc, controller.stream, initialState: initial);
    final authState = AuthAuthenticated(_user());
    when(() => authBloc.state).thenReturn(authState);
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: authState,
    );

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MultiBlocProvider(
          providers: [
            BlocProvider<FeedBloc>.value(value: feedBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: MaterialApp(
            home: Scaffold(body: FeedPage(repository: repository)),
          ),
        ),
      ),
    );
    await tester.pump();

    tester
        .widget<PostCardConnector>(find.byType(PostCardConnector))
        .onPostChanged(_post(commentsCount: 4));
    await tester.pump();
    expect(
      tester
          .widget<PostCardConnector>(find.byType(PostCardConnector))
          .post
          .commentsCount,
      4,
    );

    controller.add(
      FeedLoaded(posts: [_post(commentsCount: 5)], hasReachedMax: true),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<PostCardConnector>(find.byType(PostCardConnector))
          .post
          .commentsCount,
      5,
    );
  });
}
