import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/auth/presentation/pages/kakao_consent_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

void main() {
  testWidgets('카카오 동의는 필수·선택을 구분하고 필수 동의 전 진행을 막는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: const KakaoConsentPage(),
        ),
      ),
    );

    expect(find.text('카카오로 계속하기'), findsOneWidget);
    expect(find.text('동의 화면 미리보기'), findsNothing);
    final consentText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join(' ');
    expect(consentText, contains('[필수]'));
    expect(consentText, contains('[선택]'));

    ElevatedButton button = tester.widget(find.byType(ElevatedButton).last);
    expect(button.onPressed, isNull);

    final profileConsent = find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains('프로필 정보'),
    );
    await tester.tap(profileConsent);
    await tester.pump();
    button = tester.widget(find.byType(ElevatedButton).last);
    expect(button.onPressed, isNotNull);
  });
}
