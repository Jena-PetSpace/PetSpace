import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/config/injection_container.dart';
import 'package:meong_nyang_diary/features/social/domain/entities/post.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/controllers/post_interaction_coordinator.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/hashtag_page.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/post_card_connector.dart';

class _MockRepository extends Mock implements SocialRepository {}

Post _post(int index) => Post(
      id: 'post-$index',
      authorId: 'author-$index',
      authorName: 'Author $index',
      type: PostType.text,
      content: 'pet $index',
      createdAt: DateTime(2026, 7, 19).subtract(Duration(minutes: index)),
    );

void main() {
  late _MockRepository repository;
  late PostInteractionCoordinator coordinator;

  setUp(() async {
    repository = _MockRepository();
    coordinator = PostInteractionCoordinator(repository: repository);
    if (sl.isRegistered<SocialRepository>()) {
      await sl.unregister<SocialRepository>();
    }
    sl.registerSingleton<SocialRepository>(repository);
    when(() => repository.getUserStreak(any())).thenAnswer(
      (_) async => const Right(0),
    );
  });

  tearDown(() async {
    if (sl.isRegistered<SocialRepository>()) {
      await sl.unregister<SocialRepository>();
    }
  });

  testWidgets('loads without a FeedBloc and dedupes offset pages',
      (tester) async {
    final firstPage = List.generate(20, _post);
    when(
      () => repository.getPostsByHashtag(
        hashtag: 'dogs',
        userId: 'viewer',
        sort: 'recent',
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => Right(firstPage));
    when(
      () => repository.getPostsByHashtag(
        hashtag: 'dogs',
        userId: 'viewer',
        sort: 'recent',
        limit: 20,
        offset: 20,
      ),
    ).thenAnswer((_) async => Right([_post(19), _post(20)]));

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: HashtagPage(
            hashtag: 'dogs',
            repository: repository,
            currentUserIdProvider: () => 'viewer',
            coordinator: coordinator,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PostCardConnector), findsWidgets);

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('hashtag-post-post-19')),
      find.byKey(const Key('hashtag_posts_list')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('hashtag_posts_list')),
      const Offset(0, -800),
    );
    await tester.pumpAndSettle();

    verify(
      () => repository.getPostsByHashtag(
        hashtag: 'dogs',
        userId: 'viewer',
        sort: 'recent',
        limit: 20,
        offset: 20,
      ),
    ).called(1);
    expect(
      find.byKey(const ValueKey('hashtag-post-post-19')),
      findsOneWidget,
    );
  });
}
