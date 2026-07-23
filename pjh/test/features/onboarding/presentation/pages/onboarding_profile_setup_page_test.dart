import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/config/injection_container.dart';
import 'package:meong_nyang_diary/core/services/profile_service.dart';
import 'package:meong_nyang_diary/features/onboarding/presentation/pages/onboarding_profile_setup_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockProfileService extends Mock implements ProfileService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await sl.reset();
    sl.registerSingleton<ProfileService>(_MockProfileService());
  });

  tearDown(() async => sl.reset());

  test('첫 프로필은 닉네임·사진만 요청하고 공개 범위를 설명한다', () {
    final source = File(
      'lib/features/onboarding/presentation/pages/onboarding_profile_setup_page.dart',
    ).readAsStringSync();

    expect(source, contains("labelText: '닉네임 *'"));
    expect(source, contains('프로필 사진 선택'));
    expect(source, contains('이메일과 로그인 정보는 공개되지 않아요'));
    expect(source, isNot(contains('_bioController')));
    expect(source, isNot(contains('bio:')));
  });

  testWidgets('작은 화면·큰 글자에서도 닉네임과 고정 CTA를 분명히 표시한다', (tester) async {
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
          home: const OnboardingProfileSetupPage(),
        ),
      ),
    );
    await tester.pump();

    final action = find.byKey(const Key('onboarding_profile_bottom_action'));
    final submit = find.byKey(const Key('onboarding_profile_continue'));
    expect(action, findsOneWidget);
    expect(submit, findsOneWidget);
    expect(find.text('프로필 사진 · 선택'), findsOneWidget);
    expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);

    await tester.tap(submit);
    await tester.pump();
    expect(find.text('닉네임을 입력해주세요'), findsOneWidget);
  });
}
