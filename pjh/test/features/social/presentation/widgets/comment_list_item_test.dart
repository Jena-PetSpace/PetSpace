import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/social/domain/entities/comment.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_bloc.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_event.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_state.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/comment_list_item.dart';

class _MockCommentBloc extends MockBloc<CommentEvent, CommentState>
    implements CommentBloc {}

class _FakeCommentEvent extends Fake implements CommentEvent {}

Comment _comment(
  String id, {
  String authorId = 'viewer',
  String? parentId,
  List<Comment> replies = const <Comment>[],
}) {
  return Comment(
    id: id,
    postId: 'post-1',
    authorId: authorId,
    authorName: 'Author $id',
    content: 'content $id',
    createdAt: DateTime(2026, 7, 15),
    parentId: parentId,
    replies: replies,
  );
}

void main() {
  late _MockCommentBloc bloc;
  late Comment parent;

  setUpAll(() {
    registerFallbackValue(_FakeCommentEvent());
  });

  setUp(() {
    bloc = _MockCommentBloc();
    parent = _comment(
      'parent',
      replies: List<Comment>.generate(
        4,
        (index) => _comment('reply-$index', parentId: 'parent'),
      ),
    );
    final state = CommentLoaded(comments: [parent], totalCount: 5);
    when(() => bloc.state).thenReturn(state);
    whenListen(bloc, const Stream<CommentState>.empty(), initialState: state);
  });

  testWidgets('shows two reply previews and expands or folds the remainder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider<CommentBloc>.value(
                value: bloc,
                child: CommentListItem(
                  comment: parent,
                  currentUserId: 'viewer',
                  onDelete: () {},
                  onReply: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('content reply-0'), findsOneWidget);
    expect(find.text('content reply-1'), findsOneWidget);
    expect(find.text('content reply-2'), findsNothing);
    expect(find.text('답글 2개 더 보기'), findsOneWidget);

    await tester.tap(find.byKey(const Key('comment_replies_toggle_parent')));
    await tester.pumpAndSettle();
    expect(find.text('content reply-2'), findsOneWidget);
    expect(find.text('content reply-3'), findsOneWidget);
    expect(find.text('답글 접기'), findsOneWidget);

    await tester.ensureVisible(find.text('답글 접기'));
    await tester.tap(find.text('답글 접기'));
    await tester.pumpAndSettle();
    expect(find.text('content reply-2'), findsNothing);
  });

  testWidgets('reply like and delete actions are 44px and target nested id', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider<CommentBloc>.value(
                value: bloc,
                child: CommentListItem(
                  comment: parent,
                  currentUserId: 'viewer',
                  onDelete: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final likeFinder = find.byKey(const Key('comment_like_reply-0'));
    expect(tester.getSize(likeFinder).height, greaterThanOrEqualTo(44));
    await tester.tap(likeFinder);
    verify(
      () => bloc.add(
        const LikeCommentRequested(
          commentId: 'reply-0',
          isCurrentlyLiked: false,
        ),
      ),
    ).called(1);

    final deleteMenu = find.byKey(const Key('comment_delete_reply-0'));
    expect(tester.getSize(deleteMenu).height, greaterThanOrEqualTo(44));
    await tester.tap(deleteMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.text('답글 삭제'), findsOneWidget);
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    verify(
      () => bloc.add(const DeleteCommentRequested(commentId: 'reply-0')),
    ).called(1);
  });

  testWidgets('owner top-level menu confirms before invoking delete', (
    tester,
  ) async {
    var deleteCalls = 0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BlocProvider<CommentBloc>.value(
                value: bloc,
                child: CommentListItem(
                  comment: parent,
                  currentUserId: 'viewer',
                  onDelete: () => deleteCalls++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final menu = find.byKey(const Key('comment_delete_parent'));
    expect(tester.getSize(menu).height, greaterThanOrEqualTo(44));
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.text('댓글 삭제'), findsOneWidget);
    expect(deleteCalls, 0);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(deleteCalls, 1);
  });
}
