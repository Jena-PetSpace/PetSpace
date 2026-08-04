import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:meong_nyang_diary/main_navigation.dart';
import 'package:meong_nyang_diary/shared/models/navigation_item.dart';

void main() {
  group('root navigation contract', () {
    test('uses the approved five equal-priority destinations', () {
      expect(rootNavigationItems.map((item) => item.label), <String>[
        '홈',
        '건강',
        'AI 분석',
        '피드',
        'MY',
      ]);
      expect(
        rootNavigationItems.map((item) => item.route),
        rootNavigationPaths,
      );
      expect(rootNavigationItems[2].icon, Icons.pets_outlined);
      expect(rootNavigationItems[2].selectedIcon, Icons.pets);
    });

    test('shows the root bar only on the five exact root routes', () {
      for (final path in rootNavigationPaths) {
        expect(shouldShowRootNavigation(path), isTrue, reason: path);
        expect(shouldShowRootNavigation('$path/'), isTrue, reason: '$path/');
      }

      const taskAndDetailPaths = <String>[
        '/create-post',
        '/chat',
        '/settings/my',
        '/health/alert-settings',
        '/health/weight/add',
        '/emotion/result',
        '/feed/post-1',
        '/my/posts',
        '/my/pets/edit',
      ];
      for (final path in taskAndDetailPaths) {
        expect(shouldShowRootNavigation(path), isFalse, reason: path);
      }
    });

    test('maps root descendants to the owning tab without showing the bar', () {
      expect(navigationIndexForLocation('/home/news'), 0);
      expect(navigationIndexForLocation('/health/weight/add'), 1);
      expect(navigationIndexForLocation('/emotion/result'), 2);
      expect(navigationIndexForLocation('/feed/post-1'), 3);
      expect(navigationIndexForLocation('/my/posts'), 4);
      expect(navigationIndexForLocation('/outside', fallback: 3), 3);
    });

    test('nav subtree만 1.3배로 제한하고 접근성 위치·tooltip·48px을 제공한다', () {
      final source = File('lib/main_navigation.dart').readAsStringSync();

      expect(source, contains("hint: '\${index + 1}/\$itemCount'"));
      expect(source, contains('itemCount: _navigationItems.length'));
      expect(source, contains('selected: isSelected'));
      expect(source, contains('Tooltip('));
      expect(source, contains('message: item.label'));
      expect(source, contains('MediaQuery.withClampedTextScaling('));
      expect(source, contains('maxScaleFactor: 1.3'));
      expect(
          source, contains('constraints: const BoxConstraints(minHeight: 52)'));
      expect(source, isNot(contains('MediaQueryData(textScaler:')));
      expect(source, isNot(contains('MediaQuery.of(context).copyWith')));
    });

    testWidgets('실제 destination은 200%에서도 시맨틱스·탭·tooltip을 유지한다', (tester) async {
      var tapCount = 0;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                bottomNavigationBar: SizedBox(
                  height: 64,
                  child: RootNavigationDestination(
                    item: rootNavigationItems[2],
                    index: 2,
                    itemCount: rootNavigationItems.length,
                    isSelected: true,
                    icon: const Icon(Icons.pets),
                    selectedColor: Colors.blue,
                    unselectedColor: Colors.grey,
                    onTap: () => tapCount += 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final destination = find.bySemanticsLabel('AI 분석');
      expect(
        tester.getSemantics(destination),
        matchesSemantics(
          label: 'AI 분석',
          hint: '3/5',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      final target = find.descendant(
        of: find.byType(RootNavigationDestination),
        matching: find.byType(ConstrainedBox),
      );
      expect(tester.getSize(target).height, greaterThanOrEqualTo(52));
      expect(
        MediaQuery.textScalerOf(tester.element(find.text('AI 분석'))).scale(10),
        13,
      );
      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, 'AI 분석');

      await tester.tap(destination);
      await tester.pump();
      expect(tapCount, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });
}
