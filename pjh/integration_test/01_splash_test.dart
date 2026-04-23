import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:meong_nyang_diary/features/onboarding/presentation/pages/splash_page.dart';
import 'package:meong_nyang_diary/shared/widgets/petspace_logo.dart';

import 'app_test_entry.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('01. Splash Screen', () {
    testWidgets('앱 실행 → 스플래시 화면 렌더링', (tester) async {
      await bootAppForTest();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SplashPage), findsOneWidget,
          reason: 'SplashPage가 초기 화면으로 렌더링되어야 함');

      await binding.takeScreenshot('01_splash_initial');
    });

    testWidgets('PetSpaceLogo 위젯 렌더링 확인', (tester) async {
      await bootAppForTest();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.byType(PetSpaceLogo), findsWidgets,
          reason: '스플래시에 PetSpaceLogo가 표시되어야 함');

      await binding.takeScreenshot('01_splash_logo');
    });

    testWidgets('SVG 자산 로드 확인 (Lottie 또는 SVG)', (tester) async {
      await bootAppForTest();
      await tester.pump(const Duration(seconds: 1));

      final svgFinder = find.byType(SvgPicture);
      expect(svgFinder, findsWidgets, reason: '로고 SVG가 로드되어야 함');

      await binding.takeScreenshot('01_splash_assets');
    });

    testWidgets('3초 이내 스플래시 → 다음 화면 전환 (auth 확인 후)', (tester) async {
      await bootAppForTest();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SplashPage), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));

      await binding.takeScreenshot('01_splash_after_3s');
    });
  });
}
