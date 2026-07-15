import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/config/injection_container.dart';
import 'package:meong_nyang_diary/core/services/profile_service.dart';
import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:meong_nyang_diary/features/profile/presentation/pages/profile_edit_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockProfileService extends Mock implements ProfileService {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _FakeAuthEvent extends Fake implements AuthEvent {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockProfileService service;
  late _MockAuthBloc authBloc;

  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
  });

  setUp(() async {
    await sl.reset();
    service = _MockProfileService();
    sl.registerSingleton<ProfileService>(service);
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(AuthInitial());
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthInitial(),
    );
  });

  tearDown(() async {
    await authBloc.close();
    await sl.reset();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    double textScale = 1,
    Size surface = const Size(390, 844),
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const ProfileEditPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('현재 이름과 bio를 불러와 폼에 채우고 150%에서도 overflow가 없다', (tester) async {
    when(() => service.getProfile()).thenAnswer(
      (_) async => {
        'display_name': '정현',
        'bio': '흰둥이 보호자입니다',
        'photo_url': null,
      },
    );

    await pumpPage(
      tester,
      surface: const Size(360, 800),
      textScale: 1.5,
    );

    final nameField = tester.widget<TextFormField>(
      find.byKey(const Key('profile_edit_name_field')),
    );
    final bioField = tester.widget<TextFormField>(
      find.byKey(const Key('profile_edit_bio_field')),
    );
    expect(nameField.controller!.text, '정현');
    expect(bioField.controller!.text, '흰둥이 보호자입니다');
    expect(find.byKey(const Key('profile_edit_save_button')), findsOneWidget);
    final saveSafeArea = tester.widget<SafeArea>(
      find.byKey(const Key('profile_edit_save_safe_area')),
    );
    expect(saveSafeArea.minimum.bottom, greaterThanOrEqualTo(60));
    expect(
      tester.getSize(find.byKey(const Key('profile_edit_save_button'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('초기 조회 실패는 안전한 오류와 재시도를 제공한다', (tester) async {
    var fail = true;
    when(() => service.getProfile()).thenAnswer((_) async {
      if (fail) throw StateError('private-url');
      return {'display_name': '정현', 'bio': '', 'photo_url': null};
    });

    await pumpPage(tester);
    expect(find.byKey(const Key('profile_edit_error')), findsOneWidget);
    expect(find.textContaining('private-url'), findsNothing);

    fail = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_edit_form')), findsOneWidget);
  });

  testWidgets('텍스트 저장 성공 시 Auth profile refresh를 요청한다', (tester) async {
    when(() => service.getProfile()).thenAnswer(
      (_) async => {'display_name': '정현', 'bio': '', 'photo_url': null},
    );
    when(
      () => service.updateProfile(
        displayName: any(named: 'displayName'),
        bio: any(named: 'bio'),
      ),
    ).thenAnswer((_) async {});

    await pumpPage(tester);
    await tester.enterText(
      find.byKey(const Key('profile_edit_name_field')),
      '새이름',
    );
    await tester.enterText(
      find.byKey(const Key('profile_edit_bio_field')),
      '새 소개',
    );
    await tester.tap(find.byKey(const Key('profile_edit_save_button')));
    await tester.pump();

    verify(
      () => service.updateProfile(displayName: '새이름', bio: '새 소개'),
    ).called(1);
    verify(() => authBloc.add(any(that: isA<AuthProfileRefreshRequested>())))
        .called(1);
  });
}
