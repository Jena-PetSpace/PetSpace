import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/shared/themes/app_theme.dart';
import 'package:meong_nyang_diary/shared/widgets/petspace_bottom_action_bar.dart';

void main() {
  testWidgets('uses the page canvas and owns the bottom safe area once', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            bottomNavigationBar: PetSpaceBottomActionBar(
              key: Key('action_bar'),
              child: SizedBox(height: 52),
            ),
          ),
        ),
      ),
    );

    final bar = find.byKey(const Key('action_bar'));
    final material = tester.widget<Material>(
      find.descendant(of: bar, matching: find.byType(Material)),
    );
    final safeArea = tester.widget<SafeArea>(
      find.descendant(of: bar, matching: find.byType(SafeArea)),
    );

    expect(material.color, AppTheme.backgroundColor);
    expect(safeArea.top, isFalse);
    expect(safeArea.bottom, isTrue);
  });

  testWidgets('uses the dark page canvas without introducing a light band', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            bottomNavigationBar: PetSpaceBottomActionBar(
              key: Key('dark_action_bar'),
              child: SizedBox(height: 52),
            ),
          ),
        ),
      ),
    );

    final context = tester.element(find.byKey(const Key('dark_action_bar')));
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byKey(const Key('dark_action_bar')),
        matching: find.byType(Material),
      ),
    );

    expect(material.color, Theme.of(context).scaffoldBackgroundColor);
  });
}
