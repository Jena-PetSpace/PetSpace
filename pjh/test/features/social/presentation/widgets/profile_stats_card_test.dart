import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/social/presentation/widgets/profile_stats_card.dart';

void main() {
  testWidgets('formats counts and routes each enabled stat tap',
      (tester) async {
    var posts = 0;
    var followers = 0;
    var following = 0;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: ProfileStatsCard(
              postsCount: 12,
              followersCount: 1250,
              followingCount: 2000000,
              onPostsTap: () => posts++,
              onFollowersTap: () => followers++,
              onFollowingTap: () => following++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('12'), findsOneWidget);
    expect(find.text('1.3K'), findsOneWidget);
    expect(find.text('2.0M'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile_stat_posts')));
    await tester.tap(find.byKey(const Key('profile_stat_followers')));
    await tester.tap(find.byKey(const Key('profile_stat_following')));
    expect((posts, followers, following), (1, 1, 1));
  });
}
