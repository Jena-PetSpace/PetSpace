import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/auth/presentation/pages/terms_agreement_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

void main() {
  testWidgets('저장 실패 시 선택을 유지하고 다음 화면으로 진행하지 않는다', (tester) async {
    var calls = 0;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: TermsAgreementPage(
            saveConsents: ({
              required termsAgreed,
              required privacyAgreed,
              required locationAgreed,
              required marketingAgreed,
              required termsVersion,
              required privacyVersion,
              required locationVersion,
              required marketingVersion,
            }) async {
              calls++;
              throw StateError('local test failure');
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('전체 동의'));
    await tester.pump();
    final scrollable = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, -120));
    await tester.pump();
    final positionBeforeSave =
        tester.state<ScrollableState>(scrollable).position.pixels;
    expect(positionBeforeSave, greaterThan(0));
    await tester.ensureVisible(find.text('동의하고 계속'));
    await tester.tap(find.text('동의하고 계속'));
    await tester.pump();

    expect(calls, 1);
    expect(find.text('동의 내용을 저장하지 못했어요'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(6));
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      positionBeforeSave,
    );
  });
}
