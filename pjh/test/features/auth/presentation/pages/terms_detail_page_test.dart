import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/auth/presentation/pages/terms_detail_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

void main() {
  testWidgets('약관 전문과 명시적 동의 동작을 제공한다', (tester) async {
    var agreed = false;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: TermsDetailPage(
            title: '개인정보 처리방침',
            content: List.filled(30, '검토할 약관 본문').join('\n'),
            onAgree: () => agreed = true,
          ),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('개인정보 처리방침'), findsOneWidget);
    await tester.tap(find.text('동의'));
    expect(agreed, isTrue);
  });
}
