import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/config/app_config.dart';
import 'package:meong_nyang_diary/core/services/app_package_info.dart';
import 'package:meong_nyang_diary/features/profile/presentation/pages/help_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    double textScale = 1,
    ThemeData? theme,
    Future<AppPackageInfo> Function()? loader,
    Future<bool> Function(Uri uri)? emailLauncher,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: theme ?? AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: HelpPage(
            packageInfoLoader: loader ??
                () async =>
                    const AppPackageInfo(version: '3.2.0', buildNumber: '19'),
            emailLauncher: emailLauncher ?? (_) async => true,
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
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

    expect(find.text('앱 버전: 확인할 수 없음'), findsOneWidget);
    expect(find.textContaining('platform-private'), findsNothing);
  });

  testWidgets('검증된 지원 이메일을 표시하고 동일한 mailto 주소를 연다', (tester) async {
    Uri? launchedUri;
    await pumpPage(
      tester,
      emailLauncher: (uri) async {
        launchedUri = uri;
        return true;
      },
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('help_support_email')),
      300,
    );
    await tester.ensureVisible(find.text(AppConfig.supportEmail).first);
    await tester.pumpAndSettle();

    expect(find.text(AppConfig.supportEmail), findsOneWidget);
    await tester.tap(find.text(AppConfig.supportEmail).first);
    await tester.pump();

    expect(
      launchedUri,
      Uri(
        scheme: 'mailto',
        path: AppConfig.supportEmail,
        queryParameters: const {'subject': 'PetSpace 앱 문의'},
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 다크 화면과 200% 글자에서도 FAQ와 문의 영역이 유지된다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpPage(
      tester,
      textScale: 2,
      theme: AppTheme.darkTheme,
    );
    expect(find.byKey(const Key('help_overview')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('help_faq_0')),
      250,
    );
    await tester.tap(find.byKey(const Key('help_faq_0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('사진 중심의 반려동물 근황'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('help_support_email')),
      300,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
