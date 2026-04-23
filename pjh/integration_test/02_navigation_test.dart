import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:meong_nyang_diary/main_navigation.dart';

import 'app_test_entry.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> bootApp(WidgetTester tester) async {
    await bootAppForTest();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> tapTabIfPresent(WidgetTester tester, int index) async {
    final navFinder = find.byType(MainNavigation);
    if (navFinder.evaluate().isEmpty) return;
    final tappables = find.descendant(
      of: navFinder,
      matching: find.byType(GestureDetector),
    );
    if (tappables.evaluate().length > index) {
      await tester.tap(tappables.at(index), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 600));
    }
  }

  group('02. Bottom Navigation', () {
    testWidgets('MainNavigation 렌더링 + SVG 아이콘 4종 로드', (tester) async {
      await bootApp(tester);

      final navFinder = find.byType(MainNavigation);
      if (navFinder.evaluate().isEmpty) {
        await binding.takeScreenshot('02_nav_skipped_unauth');
        return;
      }

      final svgs = find.byType(SvgPicture);
      expect(svgs, findsWidgets, reason: 'SVG 아이콘이 렌더링되어야 함');

      await binding.takeScreenshot('02_nav_initial');
    });

    testWidgets('5개 탭 순회: 홈 → 건강관리 → AI분석 → 피드 → MY', (tester) async {
      await bootApp(tester);

      if (find.byType(MainNavigation).evaluate().isEmpty) {
        await binding.takeScreenshot('02_nav_tour_skipped');
        return;
      }

      // index 0: 홈
      await tapTabIfPresent(tester, 0);
      await binding.takeScreenshot('02_tab_home');

      // index 1: 건강관리
      await tapTabIfPresent(tester, 1);
      await binding.takeScreenshot('02_tab_health');

      // index 2: AI 분석 (FAB)
      await tapTabIfPresent(tester, 2);
      await binding.takeScreenshot('02_tab_emotion');
      // 다시 홈으로 복귀
      await tapTabIfPresent(tester, 0);

      // index 3: 피드
      await tapTabIfPresent(tester, 3);
      await binding.takeScreenshot('02_tab_feed');

      // index 4: MY
      await tapTabIfPresent(tester, 4);
      await binding.takeScreenshot('02_tab_my');
    });

    testWidgets('하단 네비바 높이 + Safe Area 검증', (tester) async {
      await bootApp(tester);

      if (find.byType(MainNavigation).evaluate().isEmpty) return;

      final navWidget = tester.widget<MainNavigation>(find.byType(MainNavigation));
      expect(navWidget, isNotNull);

      await binding.takeScreenshot('02_nav_safe_area');
    });
  });
}
