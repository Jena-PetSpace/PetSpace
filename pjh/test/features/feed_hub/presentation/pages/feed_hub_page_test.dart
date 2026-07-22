import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/feed_hub/presentation/cubit/community_cubit.dart';
import 'package:meong_nyang_diary/features/feed_hub/presentation/pages/feed_hub_page.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';

class _MockRepository extends Mock implements SocialRepository {}

void main() {
  late _MockRepository repository;
  late CommunityCubit cubit;

  setUp(() {
    repository = _MockRepository();
    when(
      () => repository.getCommunityPosts(
        category: any(named: 'category'),
        limit: any(named: 'limit'),
        beforeCreatedAt: any(named: 'beforeCreatedAt'),
      ),
    ).thenAnswer(
      (_) async => const Right([
        {
          'id': 'post-1',
          'author_id': 'author-1',
          'caption': '\n\n제목 없이 저장된 예전 글도 보여요.',
          'category': 'chat',
          'created_at': '2026-07-22T04:00:00.000Z',
          'users': {'display_name': '보리네'},
        },
      ]),
    );
    cubit = CommunityCubit(repository: repository);
  });

  tearDown(() => cubit.close());

  testWidgets('정확한 피드·커뮤니티 언어와 카테고리, legacy 본문을 표시한다', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          home: FeedHubPage(
            initialTab: 1,
            communityCubit: cubit,
            feedContent: const Center(child: Text('피드 본문')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('피드'), findsOneWidget);
    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.text('발견'), findsNothing);
    expect(find.text('라운지'), findsNothing);
    for (final label in ['전체', '잡담', '자랑', '궁금해요', '정보']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('제목 없이 저장된 예전 글도 보여요.'), findsOneWidget);
    expect(find.byKey(const Key('community_post_title')), findsNothing);
    expect(find.byKey(const Key('community_post_body')), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });
}
