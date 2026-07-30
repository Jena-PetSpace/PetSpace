import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/feed_hub/presentation/widgets/community_post_card.dart';

void main() {
  testWidgets('커뮤니티 글은 게시물 신고와 사용자 신고·차단을 구분한다', (tester) async {
    var postReports = 0;
    var userActions = 0;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: CommunityPostCard(
              authorName: '보리네',
              category: '질문',
              title: '산책 시간 질문',
              content: '저녁 산책은 몇 시가 좋을까요?',
              likes: 1,
              comments: 2,
              timeAgo: '방금 전',
              onReportPost: () => postReports++,
              onUserActions: () => userActions++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('community_post_options')));
    await tester.pumpAndSettle();
    expect(find.text('게시물 신고'), findsOneWidget);
    expect(find.text('사용자 신고 · 차단'), findsOneWidget);

    await tester.tap(find.text('게시물 신고'));
    await tester.pumpAndSettle();
    expect(postReports, 1);
    expect(userActions, 0);
  });

  testWidgets('320x568과 200% 글자에서도 카드가 overflow하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CommunityPostCard(
                  authorName: '아주 긴 반려동물 보호자 이름',
                  category: '커뮤니티 질문',
                  title: '산책 시간에 대해 궁금한 점이 있어요',
                  content: '작은 화면과 큰 글자에서도 본문과 행동이 겹치면 안 됩니다.',
                  likes: 123,
                  comments: 45,
                  timeAgo: '방금 전',
                  onReportPost: _noop,
                  onUserActions: _noop,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('community_post_options')), findsOneWidget);
  });
}

void _noop() {}
