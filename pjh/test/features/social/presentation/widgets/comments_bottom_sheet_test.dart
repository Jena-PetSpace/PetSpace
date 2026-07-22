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
import 'package:meong_nyang_diary/features/social/domain/entities/comment.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_bloc.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_event.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_state.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/post_detail_page.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/comments_bottom_sheet.dart';

class _MockCommentBloc extends MockBloc<CommentEvent, CommentState>
    implements CommentBloc {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockSocialRepository extends Mock implements SocialRepository {}

class _FakeCommentEvent extends Fake implements CommentEvent {}

Comment _comment([String id = 'comment-1']) {
  return Comment(
    id: id,
    postId: 'post-1',
    authorId: 'author-1',
    authorName: 'Mina',
    content: 'content $id',
    createdAt: DateTime(2026, 7, 18),
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
  late _MockAuthBloc authBloc;
  late _MockSocialRepository repository;

  setUpAll(() {
    registerFallbackValue(_FakeCommentEvent());
  });

  setUp(() {
    authBloc = _MockAuthBloc();
    repository = _MockSocialRepository();
    final authState = AuthAuthenticated(_user());
    when(() => authBloc.state).thenReturn(authState);
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: authState,
    );
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    required CommentBloc bloc,
    required ValueNotifier<bool> mutationNotifier,
    Size size = const Size(390, 844),
    TextScaler textScaler = TextScaler.noScaling,
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
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: Scaffold(
              body: CommentsBottomSheet(
                postId: 'post-1',
                postAuthorId: 'author-1',
                currentUserId: 'viewer',
                repository: repository,
                mutationNotifier: mutationNotifier,
                commentBlocFactory: () => bloc,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('creates one bloc and reuses it in full detail', (tester) async {
    final bloc = _MockCommentBloc();
    final state = CommentLoaded(
      comments: [_comment()],
      totalCount: 1,
      hasMore: false,
    );
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<CommentState>.empty(), initialState: state);
    when(() => bloc.close()).thenAnswer((_) async {});
    when(
      () => repository.getPostDetail('post-1'),
    ).thenAnswer((_) async => const Right(null));
    final mutationNotifier = ValueNotifier<bool>(false);

    await pumpSheet(
      tester,
      bloc: bloc,
      mutationNotifier: mutationNotifier,
    );

    verify(() => bloc.add(const LoadComments(postId: 'post-1'))).called(1);
    clearInteractions(bloc);
    await tester.tap(find.byKey(const Key('comments_sheet_open_detail')));
    await tester.pumpAndSettle();

    final detail = tester.widget<PostDetailPage>(find.byType(PostDetailPage));
    expect(detail.commentBloc, same(bloc));
    verifyNever(() => bloc.add(const LoadComments(postId: 'post-1')));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('comments_sheet_list')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    verify(() => bloc.close()).called(1);
    mutationNotifier.dispose();
  });

  testWidgets('preserves failed reply and clears it only after success', (
    tester,
  ) async {
    final bloc = _MockCommentBloc();
    final controller = StreamController<CommentState>.broadcast();
    addTearDown(controller.close);
    final initial = CommentLoaded(
      comments: [_comment()],
      totalCount: 1,
      hasMore: false,
    );
    whenListen(bloc, controller.stream, initialState: initial);
    when(() => bloc.close()).thenAnswer((_) async {});
    final mutationNotifier = ValueNotifier<bool>(false);

    await pumpSheet(
      tester,
      bloc: bloc,
      mutationNotifier: mutationNotifier,
    );

    await tester.tap(find.byKey(const Key('comment_reply_comment-1')));
    await tester.pump();
    final replyInput = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('comments_sheet_input')),
        matching: find.byType(EditableText),
      ),
    );
    expect(replyInput.focusNode.hasFocus, isTrue);
    await tester.enterText(
      find.byKey(const Key('comments_sheet_input')),
      'reply body',
    );
    await tester.tap(find.byKey(const Key('comments_sheet_send')));
    await tester.pump();
    verify(
      () => bloc.add(
        const CreateReplyRequested(
          postId: 'post-1',
          parentId: 'comment-1',
          content: 'reply body',
          postAuthorId: 'author-1',
          senderName: 'Viewer',
        ),
      ),
    ).called(1);

    controller.add(
      CommentLoaded(
        comments: [_comment()],
        totalCount: 1,
        hasMore: false,
        actionOutcome: const CommentActionOutcome(
          id: 1,
          kind: CommentActionKind.replyCreated,
          succeeded: false,
          message: 'safe failure',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('reply body'), findsOneWidget);
    expect(
      find.byKey(const Key('comments_sheet_reply_target')),
      findsOneWidget,
    );
    expect(mutationNotifier.value, isFalse);

    controller.add(
      CommentLoaded(
        comments: [_comment()],
        totalCount: 2,
        hasMore: false,
        actionOutcome: const CommentActionOutcome(
          id: 2,
          kind: CommentActionKind.replyCreated,
          succeeded: true,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('reply body'), findsNothing);
    expect(
      find.byKey(const Key('comments_sheet_reply_target')),
      findsNothing,
    );
    expect(mutationNotifier.value, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    mutationNotifier.dispose();
  });

  testWidgets('non-owner comment report waits for repository success', (
    tester,
  ) async {
    final bloc = _MockCommentBloc();
    final state = CommentLoaded(
      comments: [_comment()],
      totalCount: 1,
      hasMore: false,
    );
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<CommentState>.empty(), initialState: state);
    when(() => bloc.close()).thenAnswer((_) async {});
    when(
      () => repository.reportComment(
        'comment-1',
        'viewer',
        '스팸 또는 광고',
      ),
    ).thenAnswer((_) async => const Right(null));
    final mutationNotifier = ValueNotifier<bool>(false);

    await pumpSheet(
      tester,
      bloc: bloc,
      mutationNotifier: mutationNotifier,
    );
    await tester.tap(find.byKey(const Key('comment_report_comment-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('신고').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('social_report_reason_스팸 또는 광고')),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('social_report_submit')));
    await tester.tap(find.byKey(const Key('social_report_submit')));
    await tester.pumpAndSettle();

    verify(
      () => repository.reportComment(
        'comment-1',
        'viewer',
        '스팸 또는 광고',
      ),
    ).called(1);
    expect(find.text('신고가 접수되었습니다.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    mutationNotifier.dispose();
  });

  testWidgets('keeps input and send reachable on a small 150 percent screen', (
    tester,
  ) async {
    final bloc = _MockCommentBloc();
    final state = CommentLoaded(
      comments: [_comment()],
      totalCount: 1,
      hasMore: false,
    );
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<CommentState>.empty(), initialState: state);
    when(() => bloc.close()).thenAnswer((_) async {});
    final mutationNotifier = ValueNotifier<bool>(false);

    await pumpSheet(
      tester,
      bloc: bloc,
      mutationNotifier: mutationNotifier,
      size: const Size(320, 568),
      textScaler: const TextScaler.linear(1.5),
    );

    expect(find.byKey(const Key('comments_sheet_input')), findsOneWidget);
    expect(find.byKey(const Key('comments_sheet_send')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    mutationNotifier.dispose();
  });

  testWidgets('show path keeps input above keyboard view insets', (
    tester,
  ) async {
    final bloc = _MockCommentBloc();
    final state = CommentLoaded(
      comments: [_comment()],
      totalCount: 1,
      hasMore: false,
    );
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<CommentState>.empty(), initialState: state);
    when(() => bloc.close()).thenAnswer((_) async {});
    tester.view.physicalSize = const Size(320, 568);
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
              textScaler: const TextScaler.linear(1.5),
              viewInsets: const EdgeInsets.only(bottom: 220),
            ),
            child: child!,
          ),
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('open_comments_sheet'),
                    onPressed: () => CommentsBottomSheet.show(
                      context: context,
                      postId: 'post-1',
                      postAuthorId: 'author-1',
                      currentUserId: 'viewer',
                      repository: repository,
                      commentBlocFactory: () => bloc,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open_comments_sheet')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('comments_sheet_input')), findsOneWidget);
    expect(find.byKey(const Key('comments_sheet_send')), findsOneWidget);
    expect(
        tester.getBottomLeft(find.byKey(const Key('comments_sheet_send'))).dy,
        lessThanOrEqualTo(348));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('comments_sheet_close')));
    await tester.pumpAndSettle();
    verify(() => bloc.close()).called(1);
  });

  testWidgets('loads the 21st item and keeps the canonical total', (
    tester,
  ) async {
    final bloc = _MockCommentBloc();
    final controller = StreamController<CommentState>.broadcast();
    addTearDown(controller.close);
    final firstPage = List<Comment>.generate(
      20,
      (index) => _comment('comment-$index'),
    );
    final initial = CommentLoaded(
      comments: firstPage,
      totalCount: 21,
      hasMore: true,
    );
    whenListen(bloc, controller.stream, initialState: initial);
    when(() => bloc.close()).thenAnswer((_) async {});
    final mutationNotifier = ValueNotifier<bool>(false);

    await pumpSheet(
      tester,
      bloc: bloc,
      mutationNotifier: mutationNotifier,
    );
    expect(find.text('댓글 21'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('comments_sheet_list')),
      const Offset(0, -3000),
    );
    await tester.pump();
    verify(
      () => bloc.add(const LoadMoreComments(postId: 'post-1')),
    ).called(greaterThanOrEqualTo(1));

    controller.add(
      CommentLoaded(
        comments: [...firstPage, _comment('comment-20')],
        totalCount: 21,
        hasMore: false,
      ),
    );
    await tester.pump();
    expect(find.text('댓글 21'), findsOneWidget);
    expect(find.text('content comment-20'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    mutationNotifier.dispose();
  });
}
