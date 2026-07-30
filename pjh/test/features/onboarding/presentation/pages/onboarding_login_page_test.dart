import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

  Widget host({ThemeData? theme, double textScale = 1}) => ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          theme: theme ?? AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const OnboardingLoginPage(showAppleButton: true),
          ),
        ),
      );

  testWidgets('첫 화면에서 이메일 로그인과 원형 소셜 로그인을 함께 제공한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host());

    expect(find.byKey(const ValueKey('auth-email-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-password-field')), findsOneWidget);
    expect(find.text('함께한 하루가\n더 오래 기억되도록'), findsOneWidget);
    expect(find.textContaining('감정부터 건강 신호까지 AI로 확인'), findsOneWidget);
    expect(find.text('로그인하기'), findsOneWidget);
    expect(find.text('회원가입'), findsOneWidget);
    expect(find.text('아이디 찾기'), findsOneWidget);
    expect(find.text('비밀번호 찾기'), findsOneWidget);
    expect(find.byKey(const ValueKey('social-login-Apple')), findsOneWidget);
    expect(find.byKey(const ValueKey('social-login-Google')), findsOneWidget);
    expect(find.byKey(const ValueKey('social-login-Kakao')), findsOneWidget);
    expect(find.byKey(const Key('google-login-brand-icon')), findsOneWidget);
    expect(find.byKey(const Key('kakao-login-brand-icon')), findsOneWidget);
    expect(find.bySemanticsLabel('Google로 로그인하기'), findsOneWidget);
    expect(find.bySemanticsLabel('카카오 로그인'), findsOneWidget);
    expect(find.text('이메일로 계속하기'), findsNothing);
    expect(find.byIcon(Icons.pets), findsNothing);
    expect(find.textContaining('가입 과정에서 이용약관'), findsNothing);
    expect(find.byKey(const ValueKey('auth-password-confirm-field')),
        findsNothing);

    final idDecoration = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const ValueKey('auth-email-field')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(idDecoration.decoration.labelText, '아이디');

    await tester.tap(find.text('회원가입'));
    await tester.pump();
    expect(find.byKey(const ValueKey('auth-password-confirm-field')),
        findsOneWidget);
    expect(find.text('회원가입 계속하기'), findsOneWidget);
    expect(find.text('영문과 숫자를 포함해 8자 이상 입력해주세요.'), findsNothing);
  });

  testWidgets('iOS 소셜 버튼은 Apple·Google·Kakao 순서와 58pt 지름·16pt 간격을 유지한다', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host());
    await tester.pump();

    final apple = tester.getRect(
      find.byKey(const ValueKey('social-login-Apple')),
    );
    final google = tester.getRect(
      find.byKey(const ValueKey('social-login-Google')),
    );
    final kakao = tester.getRect(
      find.byKey(const ValueKey('social-login-Kakao')),
    );

    for (final rect in [apple, google, kakao]) {
      expect(rect.width, 58);
      expect(rect.height, 58);
    }
    expect(apple.left, lessThan(google.left));
    expect(google.left, lessThan(kakao.left));
    expect(google.left - apple.right, 16);
    expect(kakao.left - google.right, 16);
    expect(find.byKey(const Key('apple-login-brand-icon')), findsOneWidget);
  });

  test('Google 원형 버튼은 2026-07-07 공식 iOS Light 4x 원본 bytes를 유지한다', () {
    final encoded = File(
      'assets/images/google_sign_in_round_light.png.b64',
    ).readAsStringSync();
    final bytes = base64Decode(encoded.replaceAll(RegExp(r'\s+'), ''));

    expect(
      sha256.convert(bytes).toString(),
      'accb9b0c050e1fe06bc6333e294421a2f4dc7716f89ce1da2316337a8769132d',
    );
  });

  testWidgets('로그인·회원가입 전환은 아이디를 유지하고 비밀번호만 지운다', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    final email = find.byKey(const ValueKey('auth-email-field'));
    final password = find.byKey(const ValueKey('auth-password-field'));

    await tester.enterText(email, 'jena@example.com');
    await tester.enterText(password, 'Petspace8');
    await tester.tap(find.byKey(const Key('auth-mode-toggle')));
    await tester.pump();

    expect(tester.widget<TextFormField>(email).controller!.text,
        'jena@example.com');
    expect(tester.widget<TextFormField>(password).controller!.text, isEmpty);
  });

  testWidgets('비밀번호 72자 상한을 로그인과 회원가입에 동일하게 적용한다', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      '${List.filled(36, 'A1').join()}Z',
    );
    await tester.pump();

    expect(find.text('비밀번호는 최대 72자까지 입력할 수 있어요.'), findsOneWidget);
  });

  testWidgets('Google 버튼은 실제 Google 인증 이벤트를 요청한다', (tester) async {
    await tester.pumpWidget(host());

    final googleButton = find.byKey(
      const ValueKey('social-login-Google'),
    );
    await tester.ensureVisible(googleButton);
    await tester.tap(googleButton);
    await tester.pump();

    verify(() => authBloc.add(AuthSignInWithGoogleRequested())).called(1);
  });

  testWidgets('Apple 버튼은 접근성 탭으로 실제 Apple 인증 이벤트를 요청한다', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host());

    final appleNode = tester.getSemantics(
      find.bySemanticsLabel('Apple로 로그인하기'),
    );
    expect(
      appleNode.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    // Flutter 자체 semantics 테스트와 동일한 방식으로 보조기기 액션을 보낸다.
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      appleNode.id,
      SemanticsAction.tap,
    );
    await tester.pump();

    verify(() => authBloc.add(AuthSignInWithAppleRequested())).called(1);
    semantics.dispose();
  });

  testWidgets('카카오톡 버튼은 실제 Kakao 인증 이벤트를 요청한다', (tester) async {
    await tester.pumpWidget(host());

    final kakaoButton = find.byKey(
      const ValueKey('social-login-Kakao'),
    );
    await tester.ensureVisible(kakaoButton);
    await tester.tap(kakaoButton);
    await tester.pump();

    verify(() => authBloc.add(AuthSignInWithKakaoRequested())).called(1);
  });

  testWidgets('소셜 인증 중에는 해당 버튼만 진행 상태이고 중복 인증을 막는다', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host());

    final googleButton = find.byKey(
      const ValueKey('social-login-Google'),
    );
    await tester.ensureVisible(googleButton);
    await tester.tap(googleButton);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('social-login-progress-Google')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('social-login-progress-Apple')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('social-login-progress-Kakao')),
      findsNothing,
    );

    for (final label in [
      'Apple로 로그인하기',
      'Google로 로그인하기',
      '카카오 로그인',
    ]) {
      final data =
          tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
    }

    await tester.tap(
      find.byKey(const ValueKey('social-login-Kakao')),
      warnIfMissed: false,
    );
    await tester.pump();
    verifyNever(() => authBloc.add(AuthSignInWithKakaoRequested()));
    semantics.dispose();
  });

  testWidgets('아이디 이메일 형식과 영문·숫자 8자 비밀번호를 입력 중 검증한다', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.enterText(
      find.byKey(const ValueKey('auth-email-field')),
      'wrong-id',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'short',
    );
    await tester.pump();

    expect(find.text('올바른 이메일 주소를 입력해주세요.'), findsOneWidget);
    expect(find.text('영문과 숫자를 포함해 8자 이상 입력해주세요.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('auth-email-field')),
      'jena@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'Petspace8',
    );
    await tester.pump();

    expect(find.text('올바른 이메일 주소를 입력해주세요.'), findsNothing);
    expect(find.text('영문과 숫자를 포함해 8자 이상 입력해주세요.'), findsNothing);
  });

  testWidgets('로그인 폼은 별도 전환이나 AppBar 없이 하나의 캔버스를 사용한다', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host());

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

    expect(scaffold.backgroundColor, AppTheme.backgroundColor);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(Form), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byKey(const ValueKey('email-auth-submit')), findsOneWidget);
  });

  testWidgets('아이디 찾기는 이메일 아이디와 소셜 가입 경로를 정확히 안내한다', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tester.tap(find.text('아이디 찾기'));
    await tester.pumpAndSettle();

    expect(find.text('아이디를 찾고 있나요?'), findsOneWidget);
    expect(find.textContaining('아이디는 가입할 때 사용한 이메일'), findsOneWidget);
    expect(find.textContaining('Apple·Google·Kakao'), findsOneWidget);
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

  testWidgets('320 너비·200% 글자에서도 이메일과 소셜 로그인에 접근할 수 있다', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      host(theme: AppTheme.darkTheme, textScale: 2),
    );
    await tester.pump();

    for (final provider in [
      'Apple',
      'Google',
      'Kakao',
    ]) {
      expect(
        find.byKey(ValueKey('social-login-$provider')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(
      find.byKey(const ValueKey('email-auth-submit')),
    );
    expect(find.byKey(const ValueKey('email-auth-submit')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('email-auth-submit'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });
}
