import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:meong_nyang_diary/features/auth/presentation/pages/password_reset_verification_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';
import 'package:meong_nyang_diary/shared/widgets/petspace_uiux_v3.dart';

class _MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(OtpType.magiclink);
  });

  test('인증 실패 시 원문 오류를 숨기고 입력 코드를 임의 초기화하지 않는다', () {
    final source = File(
      'lib/features/auth/presentation/pages/password_reset_verification_page.dart',
    ).readAsStringSync();
    final authFailure = source.substring(
      source.indexOf('} on AuthException catch'),
      source.indexOf('void _onCodeChanged'),
    );

    expect(authFailure, contains('인증을 완료하지 못했어요'));
    expect(authFailure, isNot(contains("'인증 실패: \${e.message}'")));
    expect(authFailure, isNot(contains('controller.clear()')));
    expect(source, contains('shouldCreateUser: false'));
    expect(source, contains('_completeResend();'));
    expect(source, contains('response.user != null'));
    expect(source, contains('} else {'));
  });

  testWidgets('재발송도 신규 계정 생성을 차단한다', (tester) async {
    final auth = _MockGoTrueClient();
    when(
      () => auth.signInWithOtp(
        email: any(named: 'email'),
        emailRedirectTo: any(named: 'emailRedirectTo'),
        shouldCreateUser: any(named: 'shouldCreateUser'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: PasswordResetVerificationPage(
            email: 'jena@example.com',
            authClient: auth,
            initialResendCountdown: 0,
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(TextButton, '재발송'));
    await tester.pump();

    verify(
      () => auth.signInWithOtp(
        email: 'jena@example.com',
        emailRedirectTo: null,
        shouldCreateUser: false,
      ),
    ).called(1);
  });

  testWidgets('OTP 응답에 사용자가 없으면 로딩을 풀고 재시도를 안내한다', (
    tester,
  ) async {
    final auth = _MockGoTrueClient();
    when(
      () => auth.verifyOTP(
        token: any(named: 'token'),
        type: any(named: 'type'),
        email: any(named: 'email'),
      ),
    ).thenAnswer((_) async => AuthResponse());

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: PasswordResetVerificationPage(
            email: 'jena@example.com',
            authClient: auth,
          ),
        ),
      ),
    );
    for (var index = 0; index < 6; index++) {
      await tester.enterText(
        find.byKey(ValueKey('password-reset-code-$index')),
        '${index + 1}',
      );
      await tester.pump();
    }
    final submit = find.byKey(
      const ValueKey('password-reset-verify-submit'),
    );
    await tester.tap(submit);
    await tester.pump();

    expect(find.textContaining('인증을 완료하지 못했어요'), findsOneWidget);
    expect(
      tester.widget<PetSpaceV3PrimaryButton>(submit).onPressed,
      isNotNull,
    );
  });

  testWidgets('인증 코드는 6자리를 모두 입력한 뒤에만 사용자가 제출한다', (tester) async {
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
          home: const PasswordResetVerificationPage(
            email: 'jena@example.com',
          ),
        ),
      ),
    );

    final submit = find.byKey(
      const ValueKey('password-reset-verify-submit'),
    );
    expect(
      tester.widget<PetSpaceV3PrimaryButton>(submit).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);

    final accessibleCode = find.byKey(
      const ValueKey('password-reset-code-accessible'),
    );
    expect(accessibleCode, findsOneWidget);
    expect(find.byKey(const ValueKey('password-reset-code-0')), findsNothing);

    await tester.enterText(accessibleCode, '123456');
    await tester.pump();

    expect(
      tester.widget<PetSpaceV3PrimaryButton>(submit).onPressed,
      isNotNull,
    );
    expect(tester.getRect(accessibleCode).height, greaterThanOrEqualTo(60));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('기본 글자 배율에서는 여섯 칸 입력을 유지한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PasswordResetVerificationPage(
            email: 'jena@example.com',
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('password-reset-code-accessible')),
      findsNothing,
    );
    expect(find.text('인증 코드 확인'), findsOneWidget);
    for (var index = 0; index < 6; index++) {
      expect(
        find.byKey(ValueKey('password-reset-code-$index')),
        findsOneWidget,
      );
    }
  });
}
