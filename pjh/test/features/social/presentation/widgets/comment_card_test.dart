import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/social/domain/entities/comment.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/comment_card.dart';

void main() {
  final comment = Comment(
    id: 'comment-1',
    postId: 'post-1',
    authorId: 'author-1',
    authorName: '보리네',
    content: '산책하기 좋은 날씨네요.',
    createdAt: DateTime(2026, 7, 30),
  );

  testWidgets('타인 댓글 메뉴는 댓글 신고와 사용자 행동을 분리한다', (tester) async {
    Comment? reported;
    Comment? userTarget;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: CommentCard(
              comment: comment,
              currentUserId: 'viewer',
              onReply: () {},
              onLike: () {},
              onReport: (value) => reported = value,
              onUserActions: (value) => userTarget = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('comment_options_comment-1')));
    await tester.pumpAndSettle();
    expect(find.text('댓글 신고'), findsOneWidget);
    expect(find.text('사용자 신고 · 차단'), findsOneWidget);

    await tester.tap(find.text('댓글 신고'));
    await tester.pumpAndSettle();
    expect(reported, comment);
    expect(userTarget, isNull);
  });

  testWidgets('차단된 작성자의 답글은 즉시 렌더링에서 제외한다', (tester) async {
    final withReply = comment.copyWith(
      replies: [
        Comment(
          id: 'reply-1',
          postId: 'post-1',
          authorId: 'blocked-author',
          authorName: '숨김 사용자',
          content: '숨겨질 답글',
          createdAt: DateTime(2026, 7, 30),
        ),
      ],
    );
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: CommentCard(
              comment: withReply,
              currentUserId: 'viewer',
              onReply: () {},
              onLike: () {},
              hiddenAuthorIds: const {'blocked-author'},
            ),
          ),
        ),
      ),
    );

    expect(find.text('숨겨질 답글'), findsNothing);
  });

  testWidgets('320x568과 200% 글자에서도 댓글 행동이 overflow하지 않는다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CommentCard(
                  comment: Comment(
                    id: 'scaled-comment',
                    postId: 'post-1',
                    authorId: 'author-1',
                    authorName: '매우 긴 반려동물 보호자 이름',
                    content: '큰 글자에서도 댓글 내용과 신고 행동을 모두 확인할 수 있어야 합니다.',
                    likesCount: 123,
                    createdAt: DateTime(2026, 7, 30),
                  ),
                  currentUserId: 'viewer',
                  onReply: _noop,
                  onLike: _noop,
                  onReport: (_) {},
                  onUserActions: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('comment_options_scaled-comment')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
