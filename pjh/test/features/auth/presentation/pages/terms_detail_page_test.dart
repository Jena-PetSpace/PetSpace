import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/auth/presentation/pages/terms_detail_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';
import 'package:meong_nyang_diary/shared/widgets/petspace_uiux_v3.dart';

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
    expect(find.byType(PetSpaceV3Card), findsOneWidget);
    expect(find.byType(PetSpaceV3PrimaryButton), findsOneWidget);
    expect(find.text('개인정보 처리방침'), findsOneWidget);
    await tester.tap(find.text('동의'));
    expect(agreed, isTrue);
  });

  testWidgets('200% 글자에서도 약관 본문과 동의 행동이 같은 캔버스에서 유지된다', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: const TermsDetailPage(
            title: '서비스 이용약관',
            content: '본문을 충분히 읽고 동의할 수 있어요.',
            onAgree: _noop,
          ),
        ),
      ),
    );

    expect(find.text('동의'), findsOneWidget);
    expect(
      tester.getSize(find.byType(PetSpaceV3PrimaryButton)).height,
      greaterThanOrEqualTo(52),
    );
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
