import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/auth/domain/entities/user.dart';
import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_bloc.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_event.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_state.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/feed_bloc.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/feed_page.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/comments_bottom_sheet.dart';

class _MockFeedBloc extends MockBloc<FeedEvent, FeedState>
    implements FeedBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockCommentBloc extends MockBloc<CommentEvent, CommentState>
    implements CommentBloc {}

class _MockSocialRepository extends Mock implements SocialRepository {}

class _FakeFeedEvent extends Fake implements FeedEvent {}

class _FakeCommentEvent extends Fake implements CommentEvent {}

Post _post() {
  return Post(
    id: 'post-1',
    authorId: 'author-1',
    authorName: 'Mina',
    type: PostType.image,
    content: 'hello',
    imageUrls: const <String>[],
    createdAt: DateTime(2026, 7, 18),
    commentsCount: 3,
  );
}

User _user() {
  return User(
    uid: 'viewer',
    email: 'private@example.com',
    displayName: 'Viewer',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    pets: const <String>[],
    following: const <String>[],
    followers: const <String>[],
    settings: const UserSettings(
      notificationsEnabled: true,
      privacyLevel: PrivacyLevel.public,
      showEmotionAnalysisToPublic: false,
    ),
  );
}

void main() {
  late _MockFeedBloc feedBloc;
  late _MockAuthBloc authBloc;
  late _MockSocialRepository repository;

  setUpAll(() {
    registerFallbackValue(_FakeFeedEvent());
    registerFallbackValue(_FakeCommentEvent());
  });

  setUp(() {
    feedBloc = _MockFeedBloc();
    authBloc = _MockAuthBloc();
    repository = _MockSocialRepository();
    final feedState = FeedLoaded(
      posts: [_post()],
      hasReachedMax: true,
    );
    when(() => feedBloc.state).thenReturn(feedState);
    whenListen(
      feedBloc,
      const Stream<FeedState>.empty(),
      initialState: feedState,
    );
    final authState = AuthAuthenticated(_user());
    when(() => authBloc.state).thenReturn(authState);
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: authState,
    );
  });

  _MockCommentBloc mockCommentBloc({
    Stream<CommentState> stream = const Stream<CommentState>.empty(),
  }) {
    final bloc = _MockCommentBloc();
    const initial = CommentLoaded(
      comments: [],
      totalCount: 0,
      hasMore: false,
    );
    whenListen(bloc, stream, initialState: initial);
    when(() => bloc.close()).thenAnswer((_) async {});
    return bloc;
  }

  Future<void> pumpFeed(
    WidgetTester tester, {
    required CommentBlocFactory factory,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MultiBlocProvider(
          providers: [
            BlocProvider<FeedBloc>.value(value: feedBloc),
            BlocProvider<AuthBloc>.value(value: authBloc),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FeedPage(
                repository: repository,
                commentsBlocFactory: factory,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    clearInteractions(feedBloc);
  }

  testWidgets('comment icon and count open the same comments sheet', (
    tester,
  ) async {
    final firstBloc = mockCommentBloc();
    final secondBloc = mockCommentBloc();
    final blocs = <CommentBloc>[firstBloc, secondBloc];
    var factoryCalls = 0;

    await pumpFeed(
      tester,
      factory: () => blocs[factoryCalls++],
    );

    final icon = find.byIcon(Icons.comment_outlined);
    final action = find.ancestor(of: icon, matching: find.byType(InkWell));
    expect(
      find.descendant(of: action, matching: find.text('3')),
      findsOneWidget,
    );

    await tester.tap(icon);
    await tester.pumpAndSettle();
    expect(find.byType(CommentsBottomSheet), findsOneWidget);
    await tester.tap(find.byKey(const Key('comments_sheet_close')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.byType(CommentsBottomSheet), findsOneWidget);
    await tester.tap(find.byKey(const Key('comments_sheet_close')));
    await tester.pumpAndSettle();

    expect(factoryCalls, 2);
    verify(() => firstBloc.close()).called(1);
    verify(() => secondBloc.close()).called(1);
  });

  testWidgets('successful comment mutation reconciles only the changed post', (
    tester,
  ) async {
    final controller = StreamController<CommentState>.broadcast();
    addTearDown(controller.close);
    final commentBloc = mockCommentBloc(stream: controller.stream);
    when(() => repository.getPost('post-1')).thenAnswer(
      (_) async => Right(_post().copyWith(commentsCount: 4)),
    );

    await pumpFeed(tester, factory: () => commentBloc);
    await tester.tap(find.byIcon(Icons.comment_outlined));
    await tester.pumpAndSettle();

    controller.add(
      const CommentLoaded(
        comments: [],
        totalCount: 1,
        hasMore: false,
        actionOutcome: CommentActionOutcome(
          id: 1,
          kind: CommentActionKind.commentCreated,
          succeeded: true,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('comments_sheet_close')));
    await tester.pumpAndSettle();

    verify(() => repository.getPost('post-1')).called(1);
    verifyNever(
      () => feedBloc.add(
        const RefreshFeedRequested(userId: null, followingOnly: false),
      ),
    );
    expect(find.text('4'), findsOneWidget);
  });
}
