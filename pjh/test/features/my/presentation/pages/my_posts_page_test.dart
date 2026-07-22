import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:meong_nyang_diary/features/auth/domain/entities/user.dart';
import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/bloc/emotion_analysis_bloc.dart';
import 'package:meong_nyang_diary/features/my/presentation/pages/my_posts_page.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_bloc.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_event.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_state.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/feed_bloc.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockFeedBloc extends MockBloc<FeedEvent, FeedState>
    implements FeedBloc {}

class _MockEmotionBloc
    extends MockBloc<EmotionAnalysisEvent, EmotionAnalysisState>
    implements EmotionAnalysisBloc {}

class _MockPetBloc extends MockBloc<PetEvent, PetState> implements PetBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuthBloc authBloc;
  late _MockFeedBloc feedBloc;
  late _MockEmotionBloc emotionBloc;
  late _MockPetBloc petBloc;

  setUp(() {
    final user = User(
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
    feedBloc = _MockFeedBloc();
    emotionBloc = _MockEmotionBloc();
    petBloc = _MockPetBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: AuthAuthenticated(user),
    );
    whenListen(
      feedBloc,
      const Stream<FeedState>.empty(),
      initialState: const FeedError('private-feed-error'),
    );
    whenListen(
      emotionBloc,
      const Stream<EmotionAnalysisState>.empty(),
      initialState: const EmotionAnalysisError('private-emotion-error'),
    );
    whenListen(
      petBloc,
      const Stream<PetState>.empty(),
      initialState: const PetLoaded(pets: []),
    );
  });

  tearDown(() async {
    await authBloc.close();
    await feedBloc.close();
    await emotionBloc.close();
    await petBloc.close();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/my/posts',
      routes: [
        GoRoute(
          path: '/my/posts',
          builder: (_, __) => const MyPostsPage(),
        ),
        GoRoute(
          path: '/feed',
          builder: (_, state) => Scaffold(
            body: Text('feed-tab-${state.uri.queryParameters['tab']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<FeedBloc>.value(value: feedBloc),
            BlocProvider<EmotionAnalysisBloc>.value(value: emotionBloc),
            BlocProvider<PetBloc>.value(value: petBloc),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
              ),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('탭과 오류 문구는 긴 글자에서도 안전하며 저장소 원문을 숨긴다', (tester) async {
    await pumpPage(tester);

    expect(find.text('게시물'), findsOneWidget);
    expect(find.text('감정분석'), findsOneWidget);
    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.byKey(const Key('my_posts_feed_error')), findsOneWidget);
    expect(find.textContaining('private-feed-error'), findsNothing);

    await tester.tap(find.text('감정분석'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my_posts_emotion_error')), findsOneWidget);
    expect(find.textContaining('private-emotion-error'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('커뮤니티 CTA는 승인된 community query로 이동한다', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('커뮤니티'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('커뮤니티 가기'));
    await tester.pumpAndSettle();

    expect(find.text('feed-tab-community'), findsOneWidget);
  });
}
