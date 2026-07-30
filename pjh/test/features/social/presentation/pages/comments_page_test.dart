import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/social/domain/entities/comment.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_bloc.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_event.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/comment_state.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/comments_page.dart';

class _CommentBloc extends MockBloc<CommentEvent, CommentState>
    implements CommentBloc {}

class _Repository extends Mock implements SocialRepository {}

class _CommentEventFake extends Fake implements CommentEvent {}

void main() {
  setUpAll(() => registerFallbackValue(_CommentEventFake()));

  testWidgets('댓글 작성자를 차단하면 현재 댓글을 재조회 없이 숨긴다', (tester) async {
    final bloc = _CommentBloc();
    final repository = _Repository();
    final comment = Comment(
      id: 'comment-1',
      postId: 'post-1',
      authorId: 'author-1',
      authorName: '보리네',
      content: '숨김 전 댓글',
      createdAt: DateTime(2026, 7, 30),
    );
    when(() => bloc.state).thenReturn(
      CommentLoaded(comments: [comment], totalCount: 1, hasMore: false),
    );
    when(
      () => repository.blockUser('author-1'),
    ).thenAnswer((_) async => const Right(null));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => BlocProvider<CommentBloc>.value(
          value: bloc,
          child: MaterialApp(
            home: CommentsPage(
              postId: 'post-1',
              currentUserId: 'viewer',
              repository: repository,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('comment_options_comment-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사용자 신고 · 차단'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('social_user_block_action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('social_user_block_confirm')));
    await tester.pumpAndSettle();

    expect(find.text('숨김 전 댓글'), findsNothing);
    expect(find.byKey(const Key('comments_blocked_hidden')), findsOneWidget);
    verify(() => repository.blockUser('author-1')).called(1);

    await bloc.close();
  });
}
