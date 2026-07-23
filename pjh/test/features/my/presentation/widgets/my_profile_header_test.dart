import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/config/injection_container.dart';
import 'package:meong_nyang_diary/core/services/profile_service.dart';
import 'package:meong_nyang_diary/features/auth/domain/entities/user.dart';
import 'package:meong_nyang_diary/features/my/presentation/widgets/my_profile_header.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockProfileService extends Mock implements ProfileService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late User user;

  late _MockProfileService service;

  setUp(() async {
    await sl.reset();
    service = _MockProfileService();
    sl.registerSingleton<ProfileService>(service);
    user = User(
      uid: 'user-1',
      email: 'private@example.com',
      displayName: '정현',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      pets: const <String>[],
      following: const <String>[],
      followers: const <String>[],
      settings: const UserSettings(
        notificationsEnabled: true,
        privacyLevel: PrivacyLevel.public,
        showEmotionAnalysisToPublic: false,
      ),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<GoRouter> pumpHeader(
    WidgetTester tester, {
    double textScale = 1,
    ThemeData? theme,
    Size? surface,
  }) async {
    if (surface != null) {
      tester.view.physicalSize = surface;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: MyProfileHeader(user: user),
          ),
        ),
        GoRoute(
          path: '/my/edit-profile',
          builder: (context, __) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('fake_profile_save'),
                onPressed: () => context.pop(true),
                child: const Text('완료'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/settings/my',
          builder: (_, __) => const Scaffold(body: Text('SETTINGS')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp.router(
          theme: theme ?? AppTheme.lightTheme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('실제 bio와 통계를 표시하고 가상 handle·레벨·포인트를 숨긴다', (tester) async {
    when(() => service.getProfile()).thenAnswer(
      (_) async => {
        'display_name': '정현',
        'bio': '흰둥이와 매일 산책해요',
        'photo_url': null,
      },
    );
    when(() => service.getProfileStats()).thenAnswer(
      (_) async => {'posts': 3, 'followers': 4, 'following': 5},
    );

    await pumpHeader(tester, textScale: 1.5);

    expect(find.text('흰둥이와 매일 산책해요'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.textContaining('레벨 1'), findsNothing);
    expect(find.textContaining('0 P'), findsNothing);
    expect(find.textContaining('@private'), findsNothing);
    final avatarBottom = tester
        .getBottomLeft(
          find.byKey(const Key('my_profile_avatar')),
        )
        .dy;
    expect(
      tester.getSize(find.byKey(const Key('my_profile_avatar'))),
      Size(92.h, 92.h),
    );
    final bioTop = tester
        .getTopLeft(
          find.byKey(const Key('my_profile_bio')),
        )
        .dy;
    final nameTop = tester
        .getTopLeft(
          find.byKey(const Key('my_profile_name')),
        )
        .dy;
    final statsTop = tester
        .getTopLeft(
          find.byKey(const Key('my_stats_bar')),
        )
        .dy;
    final avatarTop = tester
        .getTopLeft(
          find.byKey(const Key('my_profile_avatar')),
        )
        .dy;
    final nameLeft = tester
        .getTopLeft(
          find.byKey(const Key('my_profile_name')),
        )
        .dx;
    final postsLeft = tester.getTopLeft(find.text('게시글')).dx;
    expect(statsTop, greaterThan(nameTop));
    expect(avatarTop, closeTo(nameTop, 1));
    expect(postsLeft, closeTo(nameLeft, 1));
    expect(bioTop, greaterThanOrEqualTo(avatarBottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('기본 글자 크기에서 프로필 이미지와 이름·통계 블록의 상하단을 맞춘다', (
    tester,
  ) async {
    when(() => service.getProfile()).thenAnswer(
      (_) async => {
        'display_name': '정현',
        'bio': '흰둥이와 매일 산책해요',
        'photo_url': null,
      },
    );
    when(() => service.getProfileStats()).thenAnswer(
      (_) async => {'posts': 3, 'followers': 4, 'following': 5},
    );

    await pumpHeader(tester, surface: const Size(390, 844));

    final avatar = find.byKey(const Key('my_profile_avatar'));
    final stats = find.byKey(const Key('my_stats_bar'));
    final name = find.byKey(const Key('my_profile_name'));
    expect(
        tester.getTopLeft(avatar).dy, closeTo(tester.getTopLeft(name).dy, 1));
    expect(
      tester.getBottomLeft(avatar).dy,
      closeTo(tester.getBottomLeft(stats).dy, 1),
    );
    expect(
      tester.getTopLeft(find.text('게시글')).dx,
      closeTo(tester.getTopLeft(name).dx, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('통계 실패는 0이 아니라 오류·재시도를 표시하고 회복한다', (tester) async {
    var failStats = true;
    when(() => service.getProfile()).thenAnswer(
      (_) async => {'display_name': '정현', 'bio': '', 'photo_url': null},
    );
    when(() => service.getProfileStats()).thenAnswer((_) async {
      if (failStats) throw StateError('secret-error');
      return {'posts': 1, 'followers': 2, 'following': 3};
    });

    await pumpHeader(tester);

    expect(find.byKey(const Key('my_stats_error')), findsOneWidget);
    expect(find.textContaining('secret-error'), findsNothing);
    failStats = false;
    await tester.tap(find.byKey(const Key('my_stats_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my_stats_bar')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('프로필 조회 실패는 실제 사용자 fallback과 안전한 재시도를 제공한다', (tester) async {
    var failProfile = true;
    when(() => service.getProfile()).thenAnswer((_) async {
      if (failProfile) throw StateError('profile-secret');
      return {
        'display_name': '정현',
        'bio': '다시 불러온 소개',
        'photo_url': null,
      };
    });
    when(() => service.getProfileStats()).thenAnswer(
      (_) async => {'posts': 0, 'followers': 0, 'following': 0},
    );

    await pumpHeader(tester);
    expect(find.byKey(const Key('my_profile_error')), findsOneWidget);
    expect(find.textContaining('profile-secret'), findsNothing);

    failProfile = false;
    await tester.tap(find.byKey(const Key('my_profile_retry')));
    await tester.pumpAndSettle();
    expect(find.text('다시 불러온 소개'), findsOneWidget);
  });

  testWidgets('프로필 편집 true 반환 후 profile과 stats를 다시 조회한다', (tester) async {
    when(() => service.getProfile()).thenAnswer(
      (_) async => {'display_name': '정현', 'bio': '', 'photo_url': null},
    );
    when(() => service.getProfileStats()).thenAnswer(
      (_) async => {'posts': 0, 'followers': 0, 'following': 0},
    );

    await pumpHeader(tester);
    await tester.tap(find.byKey(const Key('my_profile_edit_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fake_profile_save')));
    await tester.pumpAndSettle();

    verify(() => service.getProfile()).called(2);
    verify(() => service.getProfileStats()).called(2);
  });

  testWidgets('다크 테마에서 MY 제목과 프로필 표면이 읽기 가능한 색을 사용한다', (tester) async {
    when(() => service.getProfile()).thenAnswer(
      (_) async => {'display_name': '정현', 'bio': '', 'photo_url': null},
    );
    when(() => service.getProfileStats()).thenAnswer(
      (_) async => {'posts': 0, 'followers': 0, 'following': 0},
    );

    await pumpHeader(tester, theme: AppTheme.darkTheme);

    final title = tester.widget<Text>(find.text('MY'));
    final header = tester.widget<Container>(
      find.byKey(const Key('my_profile_header')),
    );
    expect(title.style?.color, AppTheme.darkTheme.colorScheme.onSurface);
    expect(header.color, AppTheme.darkTheme.colorScheme.surface);
  });
}
