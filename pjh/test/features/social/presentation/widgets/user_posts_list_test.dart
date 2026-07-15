import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/widgets/user_posts_list.dart';

class _MockSocialRepository extends Mock implements SocialRepository {}

void main() {
  late _MockSocialRepository repository;

  setUp(() {
    repository = _MockSocialRepository();
  });

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 500,
              child: UserPostsList(
                userId: 'user-1',
                isMyProfile: true,
                repository: repository,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a neutral caption preview for text-only posts',
      (tester) async {
    when(
      () => repository.getUserPostsFiltered(
        authorId: 'user-1',
        petId: null,
        beforeCreatedAt: null,
        limit: 30,
      ),
    ).thenAnswer(
      (_) async => const Right([
        {
          'id': 'post-1',
          'post_type': 'text',
          'caption': 'A complete caption preview',
          'image_urls': null,
          'image_url': null,
          'created_at': '2026-07-15T00:00:00Z',
        },
      ]),
    );

    await pumpList(tester);

    expect(find.byKey(const Key('user_posts_grid')), findsOneWidget);
    expect(find.text('A complete caption preview'), findsOneWidget);
  });

  testWidgets('separates first-load error from empty and retries safely',
      (tester) async {
    var attempts = 0;
    when(
      () => repository.getUserPostsFiltered(
        authorId: 'user-1',
        petId: null,
        beforeCreatedAt: null,
        limit: 30,
      ),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) {
        return const Left(ServerFailure(message: 'repository-secret'));
      }
      return const Right(<Map<String, dynamic>>[]);
    });

    await pumpList(tester);

    expect(find.byKey(const Key('user_posts_retry')), findsOneWidget);
    expect(find.textContaining('repository-secret'), findsNothing);

    await tester.tap(find.byKey(const Key('user_posts_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('user_posts_retry')), findsNothing);
    expect(attempts, 2);
  });
}
