import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/features/social/domain/repositories/social_repository.dart';
import 'package:meong_nyang_diary/features/social/presentation/controllers/post_interaction_coordinator.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/location_posts_page.dart';

class _MockRepository extends Mock implements SocialRepository {}

void main() {
  testWidgets('shows only a public place name at small 150% text scale',
      (tester) async {
    final repository = _MockRepository();
    when(
      () => repository.getPostsByLocation(
        lat: 37.1234,
        lng: 127.5678,
        radiusM: 500,
        userId: 'viewer',
        limit: 20,
        offset: 0,
      ),
    ).thenAnswer((_) async => const Right([]));
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          home: LocationPostsPage(
            lat: 37.1234,
            lng: 127.5678,
            locationName: '아주 긴 공개 장소 이름 서울숲 반려동물 산책길',
            repository: repository,
            currentUserIdProvider: () => 'viewer',
            coordinator: PostInteractionCoordinator(repository: repository),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('아주 긴 공개 장소 이름'), findsOneWidget);
    expect(find.textContaining('37.1234'), findsNothing);
    expect(find.textContaining('127.5678'), findsNothing);
    expect(find.textContaining('500'), findsNothing);
  });
}
