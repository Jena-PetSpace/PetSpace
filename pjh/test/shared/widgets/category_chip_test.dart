import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';
import 'package:meong_nyang_diary/shared/widgets/category_chip.dart';

Widget _wrap(Widget child, {bool dark = false}) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('selected chip exposes state, tap action, and a 44pt target', (
    tester,
  ) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(CategoryChip(label: '전체', selected: true, onTap: () => taps++)),
    );

    expect(
      tester.getSize(find.byType(CategoryChip)).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSemantics(find.byType(CategoryChip)),
      matchesSemantics(
        label: '전체',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(
      (container.decoration! as BoxDecoration).color,
      AppTheme.actionContainer,
    );

    await tester.tap(find.text('전체'));
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('unselected chip remains legible in dark mode', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CategoryChip(label: '커뮤니티', selected: false, onTap: () {}),
        dark: true,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('커뮤니티'), findsOneWidget);
    expect(
      tester.getSize(find.byType(CategoryChip)).height,
      greaterThanOrEqualTo(44),
    );
  });
}
