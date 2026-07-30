import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/services/app_package_info.dart';
import 'package:meong_nyang_diary/features/auth/domain/entities/user.dart';
import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:meong_nyang_diary/features/my/presentation/pages/my_settings_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuthBloc authBloc;
  late StreamController<AuthState> states;

  final user = User(
    uid: 'user-1',
    email: 'user@example.com',
    displayName: '정현',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    pets: const [],
    following: const [],
    followers: const [],
    settings: const UserSettings(
      notificationsEnabled: true,
      privacyLevel: PrivacyLevel.public,
      showEmotionAnalysisToPublic: false,
    ),
    emailConfirmedAt: DateTime(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
  });

  setUp(() {
    authBloc = _MockAuthBloc();
    states = StreamController<AuthState>.broadcast();
    when(() => authBloc.close()).thenAnswer((_) async {});
    when(() => authBloc.state).thenReturn(AuthAuthenticated(user));
    whenListen(authBloc, states.stream, initialState: AuthAuthenticated(user));
  });

  tearDown(() async {
    await states.close();
    await authBloc.close();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: MySettingsPage(
              packageInfoLoader: () async =>
                  const AppPackageInfo(version: '2.4.1', buildNumber: '37'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpRouterPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/settings/my',
      routes: [
        GoRoute(
          path: '/settings/my',
          builder: (_, __) => MySettingsPage(
            packageInfoLoader: () async =>
                const AppPackageInfo(version: '2.4.1', buildNumber: '37'),
          ),
        ),
        GoRoute(
          path: '/settings/privacy',
          builder: (_, __) => const Scaffold(
            body: Center(
              child: Text(
                'privacy-route-probe',
                key: Key('privacy-route-probe'),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> revealAccountManagement(WidgetTester tester) async {
    await tester.drag(
      find.byKey(const Key('my_settings_content')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('앱 정보에는 실행 버전과 오픈소스 라이선스 진입점을 표시한다', (
    tester,
  ) async {
    await pumpPage(tester);
    await revealAccountManagement(tester);
    await tester.tap(find.text('앱 정보 · 버전'));
    await tester.pumpAndSettle();

    expect(find.text('2.4.1 (37)'), findsOneWidget);
    expect(find.text('View licenses'), findsOneWidget);
    await tester.tap(find.text('View licenses'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('차단 관리 메뉴는 계정 섹션에서 정본 개인정보 경로로 이동한다', (
    tester,
  ) async {
    await pumpRouterPage(tester);

    final tile = find.text('개인정보 보호 · 차단 관리');
    expect(tile, findsOneWidget);
    expect(find.text('개인정보처리방침'), findsOneWidget);
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('privacy-route-probe')), findsOneWidget);
  });

  testWidgets('로그아웃은 확인 뒤 진행 상태를 잠그고 실패를 안전하게 안내한다', (tester) async {
    await pumpPage(tester);
    await revealAccountManagement(tester);
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout_confirm_button')));
    await tester.pump();

    expect(find.byKey(const Key('account_action_progress')), findsOneWidget);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    verify(
      () => authBloc.add(any(that: isA<AuthSignOutRequested>())),
    ).called(1);

    states.add(const AuthError('private backend detail'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account_action_progress')), findsNothing);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
    expect(find.byKey(const Key('account_action_error')), findsOneWidget);
    expect(find.textContaining('private backend detail'), findsNothing);
  });

  testWidgets('회원탈퇴는 정확한 확인 문구 전에는 실행되지 않는다', (tester) async {
    await pumpPage(tester);
    await revealAccountManagement(tester);
    await tester.tap(find.text('회원탈퇴'));
    await tester.pumpAndSettle();

    final confirm = tester.widget<TextButton>(
      find.byKey(const Key('delete_account_confirm_button')),
    );
    expect(confirm.onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('delete_account_phrase')),
      '탈퇴',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('delete_account_confirm_button')));
    await tester.pump();
    expect(find.byKey(const Key('account_action_progress')), findsOneWidget);
    verify(
      () => authBloc.add(any(that: isA<AuthDeleteAccountRequested>())),
    ).called(1);
  });

  testWidgets('작은 화면과 150% 글자 크기에서도 설정 섹션이 overflow되지 않는다', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(320, 568),
      textScale: 1.5,
    );

    expect(tester.takeException(), isNull);
    for (var index = 0; index < 4; index++) {
      await tester.drag(
        find.byKey(const Key('my_settings_content')),
        const Offset(0, -350),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
