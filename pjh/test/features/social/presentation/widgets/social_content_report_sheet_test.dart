import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/social_content_report_sheet.dart';

class _Repository extends Mock implements SocialRepository {}

void main() {
  late _Repository repository;

  setUp(() {
    repository = _Repository();
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    SocialReportTarget target = SocialReportTarget.comment,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: SocialContentReportSheet(
              target: target,
              targetId: 'target-1',
              currentUserId: 'viewer',
              repository: repository,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows success only after the repository accepts the report', (
    tester,
  ) async {
    final completer = Completer<Either<Failure, void>>();
    when(
      () => repository.reportComment('target-1', 'viewer', '스팸 또는 광고'),
    ).thenAnswer((_) => completer.future);

    await pumpSheet(tester);
    await tester.tap(
      find.byKey(const Key('social_report_reason_스팸 또는 광고')),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('social_report_submit')));
    await tester.tap(find.byKey(const Key('social_report_submit')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(
      () => repository.reportComment('target-1', 'viewer', '스팸 또는 광고'),
    ).called(1);

    completer.complete(const Right(null));
    await tester.pumpAndSettle();
    expect(find.byType(SocialContentReportSheet), findsNothing);
  });

  testWidgets('failure remains in the sheet and hides raw repository text', (
    tester,
  ) async {
    when(
      () => repository.reportPost('target-1', 'viewer', '기타'),
    ).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'database-secret')),
    );

    await pumpSheet(tester, target: SocialReportTarget.post);
    await tester.tap(find.byKey(const Key('social_report_reason_기타')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('social_report_submit')));
    await tester.tap(find.byKey(const Key('social_report_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('social_report_error')), findsOneWidget);
    expect(find.textContaining('database-secret'), findsNothing);
    expect(find.byType(SocialContentReportSheet), findsOneWidget);
  });
}
