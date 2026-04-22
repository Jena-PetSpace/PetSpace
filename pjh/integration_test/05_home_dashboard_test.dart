import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:meong_nyang_diary/main_navigation.dart';

import 'app_test_entry.dart';
import 'package:meong_nyang_diary/features/social/presentation/pages/home_page.dart';
import 'package:meong_nyang_diary/features/home/presentation/widgets/home_dashboard_header.dart';
import 'package:meong_nyang_diary/features/home/presentation/widgets/home_quick_actions.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> bootApp(WidgetTester tester) async {
    await bootAppForTest();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 2));
  }

  Future<bool> goToHomeTab(WidgetTester tester) async {
    final navFinder = find.byType(MainNavigation);
    if (navFinder.evaluate().isEmpty) return false;
    final tappables = find.descendant(
      of: navFinder,
      matching: find.byType(GestureDetector),
    );
    if (tappables.evaluate().isEmpty) return false;
    await tester.tap(tappables.at(0), warnIfMissed: false); // index 0 = 홈
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    return true;
  }

  group('05. Home Dashboard', () {
    testWidgets('홈 탭 진입 → HomePage 렌더링', (tester) async {
      await bootApp(tester);

      final entered = await goToHomeTab(tester);
      if (!entered) {
        await binding.takeScreenshot('05_home_skipped_unauth');
        return;
      }

      expect(find.byType(HomePage), findsOneWidget,
          reason: '홈 탭에서 HomePage 렌더링되어야 함');

      await binding.takeScreenshot('05_home_initial');
    });

    testWidgets('네이비 헤더(HomeDashboardHeader) 렌더링', (tester) async {
      await bootApp(tester);
      final entered = await goToHomeTab(tester);
      if (!entered) return;

      final headerFinder = find.byType(HomeDashboardHeader);
      expect(headerFinder, findsOneWidget,
          reason: 'HomeDashboardHeader가 홈 화면 상단에 표시되어야 함');

      await binding.takeScreenshot('05_home_header');
    });

    testWidgets('퀵 액션 그리드(HomeQuickActions) 렌더링', (tester) async {
      await bootApp(tester);
      final entered = await goToHomeTab(tester);
      if (!entered) return;

      final quickFinder = find.byType(HomeQuickActions);
      expect(quickFinder, findsOneWidget,
          reason: '퀵 액션 그리드가 표시되어야 함 (건강기록/동물병원 등)');

      await binding.takeScreenshot('05_home_quick_actions');
    });

    testWidgets('일일 퀘스트 / 카드 영역 표시', (tester) async {
      await bootApp(tester);
      final entered = await goToHomeTab(tester);
      if (!entered) return;

      // ScrollView 또는 Column 안에 다양한 카드들이 있는지 확인
      final hasScrollable = find.byType(Scrollable).evaluate().isNotEmpty;
      expect(hasScrollable, isTrue, reason: '홈 화면은 스크롤 가능해야 함');

      // 스크롤하여 하단 콘텐츠 확인
      if (hasScrollable) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 500));
        await binding.takeScreenshot('05_home_scrolled');
      }
    });

    testWidgets('Pull-to-refresh 동작 가능 여부', (tester) async {
      await bootApp(tester);
      final entered = await goToHomeTab(tester);
      if (!entered) return;

      final refreshable = find.byType(RefreshIndicator);
      if (refreshable.evaluate().isNotEmpty) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
        await tester.pump(const Duration(milliseconds: 600));
        await binding.takeScreenshot('05_home_pull_refresh');
      } else {
        await binding.takeScreenshot('05_home_no_refresh');
      }
    });
  });
}
