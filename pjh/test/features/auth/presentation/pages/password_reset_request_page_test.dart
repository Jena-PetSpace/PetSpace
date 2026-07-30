import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:meong_nyang_diary/features/auth/presentation/pages/password_reset_request_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';
import 'package:meong_nyang_diary/shared/widgets/petspace_bottom_action_bar.dart';
import 'package:meong_nyang_diary/shared/widgets/petspace_uiux_v3.dart';

class _MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  test('재설정 요청은 계정 존재 여부를 공개 메시지로 구분하지 않는다', () {
    final source = File(
      'lib/features/auth/presentation/pages/password_reset_request_page.dart',
    ).readAsStringSync();

    expect(source, contains('계정 존재 여부를'));
    expect(source, contains('가입 여부는 화면에 표시하지 않아요'));
    expect(source, contains('shouldCreateUser: false'));
    expect(source, contains('_goToVerification(_emailController.text.trim())'));
    expect(source, isNot(contains("return '등록되지 않은 이메일입니다.'")));
  });

  testWidgets('재설정 OTP 요청은 신규 계정 생성을 명시적으로 차단한다', (
    tester,
  ) async {
    final auth = _MockGoTrueClient();
    when(
      () => auth.signInWithOtp(
        email: any(named: 'email'),
        emailRedirectTo: any(named: 'emailRedirectTo'),
        shouldCreateUser: any(named: 'shouldCreateUser'),
      ),
    ).thenAnswer((_) async {});
    final router = GoRouter(
      initialLocation: '/request',
      routes: [
        GoRoute(
          path: '/request',
          builder: (_, __) => PasswordResetRequestPage(authClient: auth),
        ),
        GoRoute(
          path: '/auth/password-reset/verify',
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-reset-email')),
      'jena@example.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('password-reset-submit')));
    await tester.pumpAndSettle();

    verify(
      () => auth.signInWithOtp(
        email: 'jena@example.com',
        emailRedirectTo: null,
        shouldCreateUser: false,
      ),
    ).called(1);
  });

  testWidgets('이메일 형식이 유효할 때만 인증 코드 버튼이 활성화된다', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PasswordResetRequestPage(),
        ),
      ),
    );

    final emailField = find.byKey(
      const ValueKey('password-reset-email'),
    );
    final submitButton = find.byKey(
      const ValueKey('password-reset-submit'),
    );

    expect(
      tester.widget<PetSpaceV3PrimaryButton>(submitButton).onPressed,
      isNull,
    );

    await tester.enterText(emailField, 'wrong-email');
    await tester.pump();
    expect(find.text('올바른 이메일 주소를 입력해주세요.'), findsOneWidget);
    expect(
      tester.widget<PetSpaceV3PrimaryButton>(submitButton).onPressed,
      isNull,
    );

    await tester.enterText(emailField, 'jena@example.com');
    await tester.pump();
    expect(find.text('올바른 이메일 주소를 입력해주세요.'), findsNothing);
    expect(
      tester.widget<PetSpaceV3PrimaryButton>(submitButton).onPressed,
      isNotNull,
    );
  });

  testWidgets('장식 배지와 분리된 흰색 footer 없이 한 캔버스를 사용한다', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PasswordResetRequestPage(),
        ),
      ),
    );

    expect(find.byIcon(Icons.lock_reset_rounded), findsNothing);
    expect(find.byType(PetSpaceBottomActionBar), findsOneWidget);

    final actionBar = find.byType(PetSpaceBottomActionBar);
    final material = tester.widget<Material>(
      find.descendant(of: actionBar, matching: find.byType(Material)).first,
    );
    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(of: actionBar, matching: find.byType(DecoratedBox)).first,
    );

    expect(material.color, AppTheme.backgroundColor);
    expect((decoratedBox.decoration as BoxDecoration).border, isNull);
  });
}
