import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/health/presentation/widgets/health_record_card.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

Widget _wrap({
  required VoidCallback onTap,
  double textScale = 1,
}) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: HealthRecordCard(
              icon: Icons.monitor_weight_outlined,
              iconColor: AppTheme.actionBase,
              title: '체중기록',
              subtitle: '5.4kg · 신체충실도 5/9',
              date: '오늘',
              status: '완료',
              statusColor: AppTheme.actionBase,
              semanticsLabel: '체중기록, 5.4kg, 오늘, 완료, 편집',
              onTap: onTap,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('record card is a 72dp semantic button and invokes edit',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(onTap: () => taps++));

    expect(
      tester.getSize(find.byType(HealthRecordCard)).height,
      greaterThanOrEqualTo(72),
    );
    expect(
      tester.getSemantics(find.byType(HealthRecordCard)),
      matchesSemantics(
        label: '체중기록, 5.4kg, 오늘, 완료, 편집',
        isButton: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byType(HealthRecordCard));
    expect(taps, 1);
  });

  testWidgets('record card has no overflow at 320x568 and 200 percent text',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(onTap: () {}, textScale: 2),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('체중기록'), findsOneWidget);
    expect(find.text('완료'), findsOneWidget);
  });
}
