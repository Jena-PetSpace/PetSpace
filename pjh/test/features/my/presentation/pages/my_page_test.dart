import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

import 'package:meong_nyang_diary/config/injection_container.dart';
import 'package:meong_nyang_diary/core/services/profile_service.dart';
import 'package:meong_nyang_diary/features/auth/domain/entities/user.dart';
import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:meong_nyang_diary/features/my/presentation/pages/my_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';
import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/saved_posts_page.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockProfileService extends Mock implements ProfileService {}

class _MockSocialRepository extends Mock implements SocialRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const SavedPostsScope.all());
  });

  late _MockAuthBloc authBloc;
  late _MockProfileService profileService;
  late _MockSocialRepository socialRepository;
  late User user;

  setUp(() async {
    await sl.reset();
    profileService = _MockProfileService();
    socialRepository = _MockSocialRepository();
    sl.registerSingleton<ProfileService>(profileService);
    sl.registerSingleton<SocialRepository>(socialRepository);
    when(() => socialRepository.getSavedPostsPage(
          userId: any(named: 'userId'),
          scope: any(named: 'scope'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => const Right(SavedPostsPage(
          items: [],
          hasMore: false,
        )));
    when(() => socialRepository.countSavedPosts(
          userId: any(named: 'userId'),
          scope: any(named: 'scope'),
        )).thenAnswer((_) async => const Right(0));
    when(() => profileService.getProfile()).thenAnswer(
      (_) async => {'display_name': '정현', 'bio': '흰둥이 보호자', 'photo_url': null},
    );
    when(() => profileService.getProfileStats()).thenAnswer(
      (_) async => {'posts': 1, 'followers': 2, 'following': 3},
    );
    user = User(
      uid: 'user-1',
      email: 'private@example.com',
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
    );
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(AuthAuthenticated(user));
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthAuthenticated(user),
    );
  });

  tearDown(() async {
    await authBloc.close();
    await sl.reset();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required Future<List<Map<String, dynamic>>> Function() myInitial,
    Either<Failure, SavedPostsPage>? savedResult,
    double textScale = 1,
    Size surface = const Size(390, 844),
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: MyPage(
              loadMyPostsInitial: myInitial,
              loadMyPostsMore: () async => <Map<String, dynamic>>[],
            ),
          ),
        ),
        GoRoute(
          path: '/create-post',
          builder: (_, __) => const Scaffold(body: Text('CREATE')),
        ),
        GoRoute(
          path: '/feed',
          builder: (_, __) => const Scaffold(body: Text('FEED')),
        ),
      ],
    );
    if (savedResult != null) {
      when(() => socialRepository.getSavedPostsPage(
            userId: any(named: 'userId'),
            scope: any(named: 'scope'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => savedResult);
    }
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.lightTheme,
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
  }

  testWidgets('조회 실패는 빈 상태가 아니라 안전한 오류와 재시도를 표시한다', (tester) async {
    var fail = true;
    await pumpPage(
      tester,
      myInitial: () async {
        if (fail) throw StateError('repository-secret');
        return [
          {
            'id': 'post-1',
            'caption': '',
            'post_type': 'text',
            'image_urls': null,
            'image_url': null,
          },
        ];
      },
    );

    expect(find.byKey(const Key('my_posts_error')), findsOneWidget);
    expect(find.text('아직 게시글이 없어요'), findsNothing);
    expect(find.textContaining('repository-secret'), findsNothing);

    fail = false;
    await tester.tap(find.text('다시 시도').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
  });

  testWidgets('성공 empty만 빈 상태로 표시하고 가상 뱃지 섹션은 노출하지 않는다', (tester) async {
    await pumpPage(
      tester,
      myInitial: () async => <Map<String, dynamic>>[],
      surface: const Size(360, 800),
      textScale: 1.5,
    );

    expect(find.text('아직 게시글이 없어요'), findsOneWidget);
    expect(find.text('활동한 뱃지'), findsNothing);
    expect(find.textContaining('레벨 1'), findsNothing);
    expect(find.textContaining('0 P'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('저장 탭 조회 실패도 저장 empty와 구분한다', (tester) async {
    await pumpPage(
      tester,
      myInitial: () async => <Map<String, dynamic>>[],
      savedResult: const Left(ServerFailure(message: 'saved-secret')),
    );

    await tester.tap(find.byIcon(Icons.bookmark_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('saved_posts_error')), findsOneWidget);
    expect(find.text('저장한 게시글이 없어요'), findsNothing);
    expect(find.textContaining('saved-secret'), findsNothing);
  });
}
