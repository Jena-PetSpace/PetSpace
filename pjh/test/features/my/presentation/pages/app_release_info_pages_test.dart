import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/core/services/app_package_info.dart';
import 'package:meong_nyang_diary/features/my/presentation/pages/app_info_page.dart';
import 'package:meong_nyang_diary/features/my/presentation/pages/open_source_licenses_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
          home: page,
        ),
      ),
    );
  }

  testWidgets('앱 정보는 런타임 버전과 브랜드 설명을 표시한다', (tester) async {
    await pump(
      tester,
      AppInfoPage(
        packageInfoLoader: () async =>
            const AppPackageInfo(version: '1.0.0', buildNumber: '4'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('펫페이스'), findsOneWidget);
    expect(find.text('1.0.0 (4)'), findsOneWidget);
    expect(find.text('반려동물의 일상과 AI 참고 분석을 한곳에서'), findsOneWidget);
  });

  testWidgets('라이선스 로딩 실패는 다시 시도해 복구한다', (tester) async {
    var calls = 0;
    await pump(
      tester,
      OpenSourceLicensesPage(
        licenseLoader: () async {
          calls += 1;
          if (calls == 1) throw StateError('private loader detail');
          return const [
            AppLicenseEntry(
              packageName: 'recovered_package',
              licenseText: 'Recovered license',
            ),
          ];
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('라이선스를 불러오지 못했어요.'), findsOneWidget);
    expect(find.textContaining('private loader detail'), findsNothing);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('recovered_package'), findsOneWidget);
  });

  testWidgets('긴 패키지명과 라이선스 원문은 작은 화면과 200% 글자에서도 안전하다', (
    tester,
  ) async {
    const longPackage =
        'very_long_flutter_package_name_that_must_wrap_without_clipping';
    await pump(
      tester,
      OpenSourceLicensesPage(
        licenseLoader: () async => const [
          AppLicenseEntry(
            packageName: longPackage,
            licenseText:
                'Copyright 2026 Example Authors\n\nPermission is granted to '
                'use, copy, modify, and distribute this software under the '
                'terms printed in this complete license text.',
          ),
        ],
      ),
      size: const Size(320, 568),
      textScale: 2,
    );
    await tester.pumpAndSettle();

    expect(find.text(longPackage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(longPackage));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open_source_license_detail')), findsOneWidget);
    expect(find.textContaining('Permission is granted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('라이선스 로딩 중에는 목록을 먼저 노출하지 않는다', (tester) async {
    final completer = Completer<List<AppLicenseEntry>>();
    await pump(
      tester,
      OpenSourceLicensesPage(licenseLoader: () => completer.future),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('open_source_license_list')), findsNothing);

    completer.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('표시할 오픈소스 라이선스가 없어요.'), findsOneWidget);
  });
}
