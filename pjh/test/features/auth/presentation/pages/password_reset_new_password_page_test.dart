import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:meong_nyang_diary/features/auth/presentation/pages/password_reset_new_password_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';
import 'package:meong_nyang_diary/shared/widgets/petspace_uiux_v3.dart';

class _MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(UserAttributes());
  });

  test('새 비밀번호는 8자·영문·숫자 계약과 안전한 공개 오류를 사용한다', () {
    final source = File(
      'lib/features/auth/presentation/pages/password_reset_new_password_page.dart',
    ).readAsStringSync();

    expect(source, contains("value.length < 8"));
    expect(source, contains("RegExp(r'[A-Za-z]')"));
    expect(source, contains("RegExp(r'\\d')"));
    expect(source, contains('비밀번호 변경에 실패했습니다. 잠시 후 다시 시도해주세요.'));
    expect(source, contains('try {'));
    expect(source, contains("context.go('/onboarding/login')"));
    expect(source, contains('setState(() => _isLoading = false)'));
    expect(source, isNot(contains("'비밀번호 변경 실패: \$e'")));
  });

  testWidgets('완료 후 로그아웃 실패에도 로그인 화면으로 빠져나간다', (
    tester,
  ) async {
    final auth = _MockGoTrueClient();
    when(
      () => auth.updateUser(any()),
    ).thenAnswer((_) async => UserResponse.fromJson(const {}));
    when(() => auth.signOut()).thenThrow(const AuthException('offline'));
    final router = GoRouter(
      initialLocation: '/new',
      routes: [
        GoRoute(
          path: '/new',
          builder: (_, __) => PasswordResetNewPasswordPage(
            email: 'jena@example.com',
            authClient: auth,
          ),
        ),
        GoRoute(
          path: '/onboarding/login',
          builder: (_, __) => const Text('로그인 화면'),
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
      find.byKey(const ValueKey('password-reset-new-password')),
      'Petspace8',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-reset-new-password-confirm')),
      'Petspace8',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('password-reset-new-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그인하러 가기'));
    await tester.pumpAndSettle();

    expect(find.text('로그인 화면'), findsOneWidget);
    verify(() => auth.signOut()).called(1);
  });

  testWidgets('새 비밀번호는 두 입력값이 계약에 맞고 일치할 때만 제출할 수 있다', (
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
          home: const PasswordResetNewPasswordPage(
            email: 'jena@example.com',
          ),
        ),
      ),
    );

    final submit = find.byKey(
      const ValueKey('password-reset-new-submit'),
    );
    expect(
      tester.widget<PetSpaceV3PrimaryButton>(submit).onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('password-reset-new-password')),
      'petspace',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-reset-new-password-confirm')),
      'petspace',
    );
    await tester.pump();
    expect(find.textContaining('영문과 숫자를 포함해'), findsWidgets);
    expect(
      tester.widget<PetSpaceV3PrimaryButton>(submit).onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('password-reset-new-password')),
      'Petspace8',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password-reset-new-password-confirm')),
      'Petspace8',
    );
    await tester.pump();
    expect(
      tester.widget<PetSpaceV3PrimaryButton>(submit).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
