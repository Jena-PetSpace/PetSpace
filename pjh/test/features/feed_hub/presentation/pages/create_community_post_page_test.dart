import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

  setUp(() => repository = _MockRepository());

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

  testWidgets('필수 입력은 필드 가까이 안내하고 작성 화면에 머문다', (tester) async {
    await pumpPage(tester);

    final categoryCenters = ['잡담', '자랑', '궁금해요', '정보']
        .map((label) => tester.getCenter(find.text(label)))
        .toList();
    expect(
      categoryCenters.map((center) => center.dy).toSet().length,
      1,
      reason: '카테고리 선택지는 한 줄 흐름을 유지해야 합니다.',
    );

    await tester.tap(find.byKey(const Key('community_submit_button')));
    await tester.pump();

    expect(find.text('제목을 입력해주세요.'), findsOneWidget);
    expect(find.text('내용을 입력해주세요.'), findsOneWidget);
    expect(find.text('커뮤니티 글쓰기'), findsOneWidget);
    verifyNever(() => repository.createPost(any()));
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
    await tester.tap(find.byKey(const Key('community_submit_button')));
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
}
