import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meong_nyang_diary/features/social/presentation/bloc/feed_bloc.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/create_post_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockFeedBloc extends MockBloc<FeedEvent, FeedState>
    implements FeedBloc {}

class _FakeFeedEvent extends Fake implements FeedEvent {}

void main() {
  late _MockFeedBloc bloc;
  late StreamController<FeedState> states;

  setUpAll(() => registerFallbackValue(_FakeFeedEvent()));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bloc = _MockFeedBloc();
    states = StreamController<FeedState>();
    when(() => bloc.state).thenReturn(FeedInitial());
    whenListen(bloc, states.stream, initialState: FeedInitial());
  });

  tearDown(() async {
    await states.close();
    await bloc.close();
  });

  Future<void> pumpPage(WidgetTester tester, {ThemeData? theme}) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => BlocProvider<FeedBloc>.value(
          value: bloc,
          child: MaterialApp(
            theme: theme,
            home: const CreatePostPage(
              currentUserId: 'author-1',
              currentUserName: '보리네',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('사진 최대 10장과 전체 공개만 약속한다', (tester) async {
    await pumpPage(tester);

    expect(find.text('전체 공개'), findsOneWidget);
    expect(find.textContaining('최대 10장'), findsWidgets);
    expect(find.textContaining('사진만 지원'), findsOneWidget);
    expect(find.textContaining('팔로워만'), findsNothing);
    expect(find.textContaining('동영상'), findsNothing);
  });

  testWidgets('작성 요청은 전체 공개이며 실패 시 안전한 안내와 입력을 보존한다', (tester) async {
    await pumpPage(tester);

    await tester.enterText(
      find.byKey(const Key('create_post_content_field')),
      '보리와 저녁 산책을 했어요 #산책',
    );
    tester.testTextInput.hide();
    await tester.pump();
    final submit = find.byKey(const Key('create_post_submit_button'));
    await tester.tap(submit);
    await tester.pump();

    final event = verify(
      () => bloc.add(captureAny(that: isA<CreatePostRequested>())),
    ).captured.single as CreatePostRequested;
    expect(event.post.isPublic, isTrue);
    expect(event.post.isPrivate, isFalse);
    expect(event.post.tags, contains('산책'));

    states.add(const FeedError('private backend detail'));
    await tester.pump();

    expect(find.textContaining('private backend detail'), findsNothing);
    expect(find.textContaining('입력 내용과 사진은 그대로 유지됩니다'), findsOneWidget);
    expect(find.text('보리와 저녁 산책을 했어요 #산책'), findsOneWidget);
  });

  testWidgets('태그만 작성해도 닫기 전에 저장 범위를 정확히 안내한다', (tester) async {
    await pumpPage(tester);

    final addTag = find.byKey(const Key('create_post_add_hashtag'));
    await tester.ensureVisible(addTag);
    await tester.pumpAndSettle();
    await tester.tap(addTag);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('create_post_hashtag_field')),
      '산책',
    );
    await tester.tap(find.byKey(const Key('create_post_hashtag_add_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create_post_close_button')));
    await tester.pumpAndSettle();

    expect(find.text('게시글 작성 취소'), findsOneWidget);
    expect(
      find.text('본문과 태그를 임시 저장하고 작성 화면을 닫을까요?\n사진과 위치는 저장되지 않습니다.'),
      findsOneWidget,
    );
  });

  testWidgets('단일 하단 CTA와 다크 surface를 사용한다', (tester) async {
    await pumpPage(tester, theme: AppTheme.darkTheme);

    expect(find.byKey(const Key('create_post_submit_top')), findsNothing);
    expect(find.byKey(const Key('create_post_submit_button')), findsOneWidget);

    final privacy = tester.widget<Container>(
      find.byKey(const Key('create_post_privacy_card')),
    );
    final location = tester.widget<Container>(
      find.byKey(const Key('create_post_location_card')),
    );
    expect(
      (privacy.decoration! as BoxDecoration).color,
      AppTheme.darkTheme.colorScheme.surface,
    );
    expect(
      (location.decoration! as BoxDecoration).color,
      AppTheme.darkTheme.colorScheme.surface,
    );
  });
}
