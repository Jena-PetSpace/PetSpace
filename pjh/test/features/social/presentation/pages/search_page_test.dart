import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/social/domain/entities/social_user.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/bloc/search_bloc.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/search_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockSearchBloc extends MockBloc<SearchEvent, SearchState>
    implements SearchBloc {}

class _MockRepository extends Mock implements SocialRepository {}

class _FakeSearchEvent extends Fake implements SearchEvent {}

void main() {
  late _MockSearchBloc bloc;
  late _MockRepository repository;

  setUpAll(() => registerFallbackValue(_FakeSearchEvent()));

  setUp(() {
    bloc = _MockSearchBloc();
    repository = _MockRepository();
    when(() => bloc.close()).thenAnswer((_) async {});
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    SearchState state = const SearchState(),
    String? initialQuery,
    ThemeData? theme,
  }) async {
    when(() => bloc.state).thenReturn(state);
    whenListen(
      bloc,
      const Stream<SearchState>.empty(),
      initialState: state,
    );
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => BlocProvider<SearchBloc>.value(
          value: bloc,
          child: MaterialApp(
            theme: theme,
            home: SearchPage(
              initialQuery: initialQuery,
              repository: repository,
              currentUserIdProvider: () => 'viewer',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('uses one four-tab canonical result surface', (tester) async {
    final now = DateTime(2026, 7, 19);
    await pumpPage(
      tester,
      initialQuery: 'mina',
      state: SearchState(
        query: 'mina',
        users: [
          SocialUser(
            id: 'u1',
            email: '',
            displayName: 'Mina',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );

    expect(find.text('전체'), findsOneWidget);
    expect(find.text('게시물'), findsOneWidget);
    expect(find.text('사용자'), findsWidgets);
    expect(find.text('해시태그'), findsOneWidget);
    expect(find.byKey(const Key('search_all_results')), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isFalse);
  });

  testWidgets('dark theme uses one consistent surface for search and tabs', (
    tester,
  ) async {
    await pumpPage(
      tester,
      initialQuery: 'pet',
      state: const SearchState(query: 'pet'),
      theme: AppTheme.darkTheme,
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final tabMaterial = tester.widget<Material>(
      find.byKey(const Key('search_result_tabs_surface')),
    );
    expect(appBar.backgroundColor, AppTheme.darkTheme.colorScheme.surface);
    expect(tabMaterial.color, AppTheme.darkTheme.colorScheme.surface);
    expect(tester.takeException(), isNull);
  });

  testWidgets('debounces query changes for 300 milliseconds', (tester) async {
    await pumpPage(tester);
    clearInteractions(bloc);

    await tester.enterText(
      find.byKey(const Key('search_query_field')),
      'pet',
    );
    await tester.pump(const Duration(milliseconds: 299));
    verifyNever(() => bloc.add(const SearchAllRequested(query: 'pet')));
    await tester.pump(const Duration(milliseconds: 1));

    verify(() => bloc.add(const SearchAllRequested(query: 'pet'))).called(1);
  });

  testWidgets('keyboard submit bypasses the debounce delay', (tester) async {
    await pumpPage(tester);
    clearInteractions(bloc);

    await tester.enterText(
      find.byKey(const Key('search_query_field')),
      'pet',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    verify(() => bloc.add(const SearchAllRequested(query: 'pet'))).called(1);
  });

  testWidgets('all tab distinguishes a partial error and retries', (
    tester,
  ) async {
    await pumpPage(
      tester,
      initialQuery: 'pet',
      state: const SearchState(
        query: 'pet',
        errors: {
          SearchSection.users: '사용자 결과를 불러오지 못했어요.',
        },
      ),
    );
    clearInteractions(bloc);

    final error = find.byKey(const Key('search_all_users_error'));
    expect(error, findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    await tester.tap(
      find.descendant(of: error, matching: find.byType(TextButton)),
    );
    await tester.pump();

    verify(() => bloc.add(const SearchAllRequested(query: 'pet'))).called(1);
  });
}
