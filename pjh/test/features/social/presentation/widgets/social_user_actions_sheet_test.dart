import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/social_user_actions_sheet.dart';

class _Repository extends Mock implements SocialRepository {}

void main() {
  late _Repository repository;

  setUp(() => repository = _Repository());

  Future<void> pumpLauncher(
    WidgetTester tester, {
    VoidCallback? onBlocked,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                key: const Key('open_user_actions'),
                onPressed: () => SocialUserActionsSheet.show(
                  context,
                  targetUserId: 'target-user',
                  targetUserName: '보리네',
                  currentUserId: 'viewer',
                  repository: repository,
                  onBlocked: onBlocked,
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('사용자 신고는 게시물·댓글 신고와 분리해 reportUser를 호출한다', (
    tester,
  ) async {
    when(
      () => repository.reportUser('target-user', 'viewer', '스팸 또는 광고'),
    ).thenAnswer((_) async => const Right(null));
    await pumpLauncher(tester);

    await tester.tap(find.byKey(const Key('open_user_actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('social_user_report_action')));
    await tester.pumpAndSettle();

    expect(find.text('사용자 신고'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('social_report_reason_스팸 또는 광고')),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('social_report_submit')));
    await tester.tap(find.byKey(const Key('social_report_submit')));
    await tester.pumpAndSettle();

    verify(
      () => repository.reportUser('target-user', 'viewer', '스팸 또는 광고'),
    ).called(1);
  });

  testWidgets('차단 성공 뒤 현재 화면 제거 콜백을 한 번 호출한다', (tester) async {
    var blockedCount = 0;
    when(
      () => repository.blockUser('target-user'),
    ).thenAnswer((_) async => const Right(null));
    await pumpLauncher(tester, onBlocked: () => blockedCount++);

    await tester.tap(find.byKey(const Key('open_user_actions')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('social_user_block_action')),
    );
    await tester.tap(find.byKey(const Key('social_user_block_action')));
    await tester.pumpAndSettle();
    expect(find.text('보리네님을 차단할까요?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('social_user_block_confirm')));
    await tester.pumpAndSettle();

    verify(() => repository.blockUser('target-user')).called(1);
    expect(blockedCount, 1);
    expect(find.text('보리네님을 차단했습니다.'), findsOneWidget);
  });

  testWidgets('320x568과 200% 글자에서도 신고·차단 설명과 행동을 잃지 않는다', (
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
              body: Builder(
                builder: (context) => FilledButton(
                  key: const Key('open_scaled_user_actions'),
                  onPressed: () => SocialUserActionsSheet.show(
                    context,
                    targetUserId: 'target-user',
                    targetUserName: '매우 긴 사용자 이름',
                    currentUserId: 'viewer',
                    repository: repository,
                  ),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_scaled_user_actions')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('social_user_report_action')), findsOneWidget);
    expect(find.byKey(const Key('social_user_block_action')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('social_user_block_action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('social_user_block_confirm')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
