import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/config/injection_container.dart';
import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/auth/domain/entities/user.dart';
import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:meong_nyang_diary/features/my/presentation/pages/my_saved_posts_page.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/bookmark_collection.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/saved_posts_page.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/bookmark_bloc.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRepository extends Mock implements SocialRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockAuthBloc authBloc;
  late _MockRepository repository;

  setUp(() async {
    await sl.reset();
    repository = _MockRepository();
    authBloc = _MockAuthBloc();
    final user = User(
      uid: 'u1',
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
    when(() => authBloc.state).thenReturn(AuthAuthenticated(user));
    whenListen(authBloc, const Stream<AuthState>.empty(),
        initialState: AuthAuthenticated(user));
    final collection = BookmarkCollection(
      id: 'c1',
      userId: 'u1',
      name: '산책 기록',
      createdAt: DateTime(2026, 7, 15),
      updatedAt: DateTime(2026, 7, 15),
    );
    when(() => repository.getBookmarkCollections('u1'))
        .thenAnswer((_) async => Right([collection]));
    when(() => repository.countSavedPosts(
          userId: 'u1',
          scope: const SavedPostsScope.all(),
        )).thenAnswer((_) async => const Right(4));
    when(() => repository.countSavedPosts(
          userId: 'u1',
          scope: const SavedPostsScope.unassigned(),
        )).thenAnswer((_) async => const Right(2));
    sl.registerSingleton<SocialRepository>(repository);
    sl.registerFactory<BookmarkBloc>(
        () => BookmarkBloc(repository: repository));
  });

  tearDown(() async {
    await authBloc.close();
    await sl.reset();
  });

  testWidgets('허브는 전체·미분류 카운트와 사용자 컬렉션을 구분해 표시한다', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const MySavedPostsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saved_posts_total_count')), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('전체 저장 · 미분류 2개'), findsOneWidget);
    expect(find.byKey(const Key('unassigned_collection')), findsOneWidget);
    expect(find.text('산책 기록'), findsOneWidget);
  });

  testWidgets('컬렉션 조회 실패에도 미분류 진입과 인라인 재시도를 유지한다', (tester) async {
    when(() => repository.getBookmarkCollections('u1')).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'collections-failed')),
    );
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const MySavedPostsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unassigned_collection')), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('collections_error')), findsOneWidget);
  });
}
