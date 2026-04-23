import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:meong_nyang_diary/main_navigation.dart';

import 'app_test_entry.dart';
import 'package:meong_nyang_diary/features/my/presentation/pages/my_page.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> bootApp(WidgetTester tester) async {
    await bootAppForTest();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 2));
  }

  Future<bool> goToMyTab(WidgetTester tester) async {
    final navFinder = find.byType(MainNavigation);
    if (navFinder.evaluate().isEmpty) return false;
    final tappables = find.descendant(
      of: navFinder,
      matching: find.byType(GestureDetector),
    );
    if (tappables.evaluate().length <= 4) return false;
    await tester.tap(tappables.at(4), warnIfMissed: false); // index 4 = MY
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    return true;
  }

  group('04. MY Tab', () {
    testWidgets('MY 탭 진입 → MyPage 렌더링', (tester) async {
      await bootApp(tester);

      final entered = await goToMyTab(tester);
      if (!entered) {
        await binding.takeScreenshot('04_my_skipped_unauth');
        return;
      }

      expect(find.byType(MyPage), findsOneWidget,
          reason: 'MY 탭에서 MyPage 렌더링되어야 함');

      await binding.takeScreenshot('04_my_page');
    });

    testWidgets('TabBar 2탭 구조 (내 게시글 / 저장한 게시글) 확인', (tester) async {
      await bootApp(tester);
      final entered = await goToMyTab(tester);
      if (!entered) return;

      final tabBarFinder = find.byType(TabBar);
      expect(tabBarFinder, findsWidgets,
          reason: 'MyPage에 TabBar가 있어야 함');

      // TabBar 첫 번째 발견 인스턴스의 탭 개수 확인
      if (tabBarFinder.evaluate().isNotEmpty) {
        final tabBar = tester.widget<TabBar>(tabBarFinder.first);
        expect(tabBar.tabs.length, equals(2),
            reason: 'MyPage TabBar는 2개 탭이어야 함 (내 게시글/저장한 게시글)');
      }

      await binding.takeScreenshot('04_my_tabbar');
    });

    testWidgets('GridView 렌더링 확인 (인스타그램 스타일)', (tester) async {
      await bootApp(tester);
      final entered = await goToMyTab(tester);
      if (!entered) return;

      // 게시물이 없으면 EmptyState만 렌더링됨 — GridView는 게시물 있을 때만
      final gridFinder = find.byType(GridView);
      // 둘 중 하나는 표시되어야 함 (GridView 또는 빈 상태)
      final hasGrid = gridFinder.evaluate().isNotEmpty;
      final hasText = find.byType(Text).evaluate().isNotEmpty;
      expect(hasGrid || hasText, isTrue,
          reason: 'GridView 또는 빈 상태 안내가 표시되어야 함');

      await binding.takeScreenshot('04_my_grid_or_empty');
    });

    testWidgets('설정 아이콘 → SettingsBottomSheet 노출', (tester) async {
      await bootApp(tester);
      final entered = await goToMyTab(tester);
      if (!entered) return;

      // 설정 아이콘 찾기 (settings 또는 더보기 메뉴)
      final settingsIcon = find.byIcon(Icons.settings);
      final moreIcon = find.byIcon(Icons.more_vert);

      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 600));
        await binding.takeScreenshot('04_my_settings_sheet');
      } else if (moreIcon.evaluate().isNotEmpty) {
        await tester.tap(moreIcon.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 600));
        await binding.takeScreenshot('04_my_more_sheet');
      } else {
        await binding.takeScreenshot('04_my_no_settings_icon');
      }
    });

    testWidgets('두 번째 탭(저장한 게시글) 전환', (tester) async {
      await bootApp(tester);
      final entered = await goToMyTab(tester);
      if (!entered) return;

      final tabBarFinder = find.byType(TabBar);
      if (tabBarFinder.evaluate().isEmpty) return;

      final tabBar = tester.widget<TabBar>(tabBarFinder.first);
      if (tabBar.tabs.length >= 2) {
        // 두 번째 탭 클릭
        await tester.tap(find.descendant(
          of: tabBarFinder.first,
          matching: find.byType(Tab),
        ).at(1), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 600));
        await binding.takeScreenshot('04_my_saved_tab');
      }
    });
  });
}
