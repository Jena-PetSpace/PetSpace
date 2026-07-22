import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';
import 'package:meong_nyang_diary/shared/widgets/petspace_settings_components.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('tile is a named 56pt button and invokes its action', (
    tester,
  ) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        PetSpaceSettingsTile(
          title: '알림 설정',
          subtitle: '푸시 알림을 관리해요',
          onTap: () => taps++,
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(PetSpaceSettingsTile)).height,
      greaterThanOrEqualTo(56),
    );
    expect(
      tester.getSemantics(find.byType(PetSpaceSettingsTile)),
      matchesSemantics(
        label: '알림 설정, 푸시 알림을 관리해요',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.text('알림 설정'));
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('disabled tile announces disabled and blocks taps', (
    tester,
  ) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        PetSpaceSettingsTile(
          title: '준비 중',
          enabled: false,
          onTap: () => taps++,
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(PetSpaceSettingsTile)),
      matchesSemantics(label: '준비 중', isButton: true, hasEnabledState: true),
    );
    await tester.tap(find.text('준비 중'));
    expect(taps, 0);
    semantics.dispose();
  });

  testWidgets('section uses one bordered surface instead of stacked cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const PetSpaceSettingsSection(
          title: '계정',
          children: [
            PetSpaceSettingsTile(title: '프로필'),
            PetSpaceSettingsTile(title: '로그아웃'),
          ],
        ),
      ),
    );

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(PetSpaceSettingsSection),
            matching: find.byType(Material),
          )
          .first,
    );
    final shape = material.shape! as RoundedRectangleBorder;
    expect(material.color, AppTheme.surfaceColor);
    expect(shape.side.color, AppTheme.border);
    expect(find.byType(Divider), findsOneWidget);
  });
}
