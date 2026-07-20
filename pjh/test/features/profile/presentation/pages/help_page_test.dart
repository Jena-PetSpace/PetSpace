import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/core/services/app_package_info.dart';
import 'package:meong_nyang_diary/features/profile/presentation/pages/help_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    double textScale = 1,
    Future<AppPackageInfo> Function()? loader,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: HelpPage(
            packageInfoLoader:
                loader ??
                () async =>
                    const AppPackageInfo(version: '3.2.0', buildNumber: '19'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('도움말 하단은 실제 앱 버전과 빌드 번호를 표시한다', (tester) async {
    await pumpPage(tester, textScale: 1.5);
    await tester.scrollUntilVisible(
      find.byKey(const Key('help_app_version')),
      300,
    );

    expect(find.text('앱 버전: 3.2.0 (19)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('플랫폼 버전 조회 실패를 내부 오류 없이 안내한다', (tester) async {
    await pumpPage(
      tester,
      loader: () async => throw StateError('platform-private'),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('help_app_version')),
      300,
    );

    expect(find.text('앱 버전: 확인할 수 없음'), findsOneWidget);
    expect(find.textContaining('platform-private'), findsNothing);
  });
}
