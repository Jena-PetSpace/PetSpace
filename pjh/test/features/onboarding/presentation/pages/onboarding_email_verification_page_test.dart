import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/onboarding/presentation/pages/onboarding_email_verification_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

void main() {
  test('이메일 인증 화면은 토큰·응답·원문 예외를 로그나 UI에 노출하지 않는다', () {
    final source = File(
      'lib/features/onboarding/presentation/pages/onboarding_email_verification_page.dart',
    ).readAsStringSync();

    expect(source, contains('인증을 완료하지 못했어요'));
    expect(source, isNot(contains('response.toString()')));
    expect(source, isNot(contains("developer.log('재발송")));
    expect(source, isNot(contains("'인증 실패: \${e.toString()}'")));
    expect(source, isNot(contains("'인증 실패: \${e.message}'")));
  });

  testWidgets('320 너비·200% 글자에서도 인증 코드 6칸과 재발송 안내가 넘치지 않는다', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: const OnboardingEmailVerificationPage(
            email: 'user@example.com',
          ),
        ),
      ),
    );
    await tester.pump();

    final codeRow = find.byKey(const Key('email_verification_code_row'));
    expect(codeRow, findsOneWidget);
    expect(find.byKey(const Key('email_verification_submit')), findsOneWidget);
    expect(tester.getSize(codeRow).width, lessThanOrEqualTo(272));
    for (var index = 0; index < 6; index++) {
      expect(
        find.byKey(ValueKey('email-verification-digit-$index')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
