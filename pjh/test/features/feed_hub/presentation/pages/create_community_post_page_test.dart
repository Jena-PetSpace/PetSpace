import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/feed_hub/presentation/pages/create_community_post_page.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

class _MockRepository extends Mock implements SocialRepository {}

class _FakePost extends Fake implements Post {}

void main() {
  late _MockRepository repository;

  setUpAll(() => registerFallbackValue(_FakePost()));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _MockRepository();
  });

  Future<void> pumpPage(WidgetTester tester, {ThemeData? theme}) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          theme: theme,
          initialRoute: '/write',
          routes: {
            '/': (_) => const Scaffold(body: Text('완료')),
            '/write': (_) => CreateCommunityPostPage(
                  repository: repository,
                  authorId: 'author-1',
                  authorName: '보리네',
                ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('필수 입력 전에는 등록 버튼을 활성화하지 않는다', (tester) async {
    await pumpPage(tester);

    final categoryCenters = ['질문', '정보', '자랑', '일상']
        .map((label) => tester.getCenter(find.text(label)))
        .toList();
    expect(
      categoryCenters.map((center) => center.dy).toSet().length,
      1,
      reason: '카테고리 선택지는 한 줄 흐름을 유지해야 합니다.',
    );

    final submitFinder = find.byKey(const Key('community_submit_button'));
    expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('community_title_field')),
      '산책 친구를 찾습니다',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('community_content_field')),
      '주말 오전에 함께 걸어요.',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);

    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('질문'));
    await tester.tap(find.text('질문'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(submitFinder).onPressed, isNotNull);
  });

  testWidgets('등록 실패는 원문을 노출하지 않고 입력과 카테고리를 보존한다', (tester) async {
    when(() => repository.createPost(any())).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'private sql detail')),
    );
    await pumpPage(tester);

    await tester.tap(find.text('정보'));
    await tester.enterText(
      find.byKey(const Key('community_title_field')),
      '산책 친구를 찾습니다',
    );
    await tester.enterText(
      find.byKey(const Key('community_content_field')),
      '주말 오전에 함께 걸어요.',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final submitFinder = find.byKey(const Key('community_submit_button'));
    expect(tester.widget<FilledButton>(submitFinder).onPressed, isNotNull);
    await tester.tap(submitFinder);
    await tester.pumpAndSettle();

    expect(find.textContaining('private sql detail'), findsNothing);
    expect(find.textContaining('입력 내용은 그대로 유지됩니다'), findsOneWidget);
    expect(find.text('산책 친구를 찾습니다'), findsOneWidget);
    expect(find.text('주말 오전에 함께 걸어요.'), findsOneWidget);

    final captured = verify(() => repository.createPost(captureAny()))
        .captured
        .single as Post;
    expect(captured.content, '산책 친구를 찾습니다\n\n주말 오전에 함께 걸어요.');
    expect(captured.category, 'info');
    expect(captured.isPublic, isTrue);
    expect(captured.isPrivate, isFalse);
  });

  testWidgets('단일 하단 CTA와 다크 안내 surface를 사용한다', (tester) async {
    await pumpPage(tester, theme: AppTheme.darkTheme);

    expect(find.byKey(const Key('community_submit_top')), findsNothing);
    expect(find.byKey(const Key('community_submit_button')), findsOneWidget);

    final notice = tester.widget<Container>(
      find.byKey(const Key('community_draft_notice')),
    );
    expect(
      (notice.decoration! as BoxDecoration).color,
      AppTheme.darkTheme.colorScheme.surfaceContainerHighest,
    );
  });

  testWidgets('320x568과 200% 글자에서 3지 이탈 행동이 모두 보인다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: MaterialApp(
            home: CreateCommunityPostPage(
              repository: repository,
              authorId: 'author-1',
              authorName: '보리네',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('community_title_field')),
      '작성 중인 제목',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: '작성 화면 자체가 overflow하면 안 됩니다.');
    await tester.tap(find.byKey(const Key('community_close_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('community_exit_keep')), findsOneWidget);
    expect(find.byKey(const Key('community_exit_discard')), findsOneWidget);
    expect(find.byKey(const Key('community_exit_save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
