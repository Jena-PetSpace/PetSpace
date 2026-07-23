import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';
import 'package:meong_nyang_diary/shared/widgets/petspace_page_scaffold.dart';

Widget _wrap(Widget child, {bool dark = false, double textScale = 1}) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, appChild) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: appChild!,
      ),
      home: child,
    ),
  );
}

void main() {
  testWidgets('uses warm canvas, white app bar, and a quiet divider', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const PetSpacePageScaffold(title: '설정', body: SizedBox())),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final border = appBar.shape! as Border;

    expect(scaffold.backgroundColor, AppTheme.backgroundColor);
    expect(appBar.backgroundColor, AppTheme.surfaceColor);
    expect(
      border.bottom.color,
      Theme.of(tester.element(find.text('설정'))).dividerColor,
    );
    expect(appBar.centerTitle, isTrue);
  });

  testWidgets('supports a left-aligned task title when explicitly requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const PetSpacePageScaffold(
          title: '기록 추가',
          centerTitle: false,
          body: SizedBox(),
        ),
      ),
    );

    expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isFalse);
  });

  testWidgets('seamless task mode connects the app bar to the page canvas', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const PetSpacePageScaffold(
          title: '프로필 편집',
          seamlessCanvas: true,
          body: SizedBox(),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, scaffold.backgroundColor);
    expect(appBar.shape, isNull);
  });

  testWidgets('seamless task mode stays continuous in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const PetSpacePageScaffold(
          title: '채팅방 정보',
          seamlessCanvas: true,
          body: SizedBox(),
        ),
        dark: true,
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, scaffold.backgroundColor);
    expect(appBar.shape, isNull);
  });

  testWidgets('has no overflow at 320x568 with 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        const PetSpacePageScaffold(
          title: '아주 긴 상세 작업 화면 제목입니다',
          body: SizedBox(),
        ),
        textScale: 2,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
