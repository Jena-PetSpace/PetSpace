import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:meong_nyang_diary/features/onboarding/presentation/pages/onboarding_login_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockAuthBloc extends Mock implements AuthBloc {}

void main() {
  late _MockAuthBloc authBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(AuthUnauthenticated());
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget host() => ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const OnboardingLoginPage(showAppleButton: true),
          ),
        ),
      );

  testWidgets('provider 이름을 고정하고 이메일 로그인·회원가입을 분리한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host());

    expect(find.text('Apple로 계속하기'), findsOneWidget);
    expect(find.text('Google로 계속하기'), findsOneWidget);
    expect(find.text('카카오로 계속하기'), findsOneWidget);
    expect(find.text('이메일로 계속하기'), findsOneWidget);

    await tester.ensureVisible(find.text('이메일로 계속하기'));
    await tester.tap(find.text('이메일로 계속하기'));
    await tester.pump();
    expect(find.text('로그인'), findsWidgets);
    expect(find.text('회원가입'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-password-confirm-field')),
        findsNothing);

    await tester.tap(find.text('회원가입'));
    await tester.pump();
    expect(find.byKey(const ValueKey('auth-password-confirm-field')),
        findsOneWidget);
    expect(find.textContaining('영문과 숫자를 포함해 8자 이상'), findsOneWidget);
  });

  test('첫 진입과 구형 소개 슬라이드는 provider 선택 화면으로 연결된다', () {
    final router =
        File('lib/core/navigation/app_router.dart').readAsStringSync();
    final onboardingRoutes = router.substring(
      router.indexOf("path: '/onboarding'"),
      router.indexOf("path: '/onboarding/email-verification'"),
    );

    expect(
      "redirect: (context, state) => '/onboarding/login'"
          .allMatches(onboardingRoutes),
      hasLength(2),
    );
    expect(onboardingRoutes, contains('const OnboardingLoginPage()'));
  });
}
