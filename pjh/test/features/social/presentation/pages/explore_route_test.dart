import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/social/presentation/bloc/search_bloc.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/explore_page.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/search_page.dart';

class _MockSearchBloc extends MockBloc<SearchEvent, SearchState>
    implements SearchBloc {}

class _FakeSearchEvent extends Fake implements SearchEvent {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeSearchEvent()));

  testWidgets('explore is a thin wrapper over the canonical SearchPage',
      (tester) async {
    final bloc = _MockSearchBloc();
    when(() => bloc.state).thenReturn(const SearchState());
    whenListen(
      bloc,
      const Stream<SearchState>.empty(),
      initialState: const SearchState(),
    );
    when(() => bloc.close()).thenAnswer((_) async {});

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => BlocProvider<SearchBloc>.value(
          value: bloc,
          child: const MaterialApp(
            home: ExplorePage(initialQuery: 'pet'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SearchPage), findsOneWidget);
    expect(find.byKey(const Key('search_query_field')), findsOneWidget);
  });
}
