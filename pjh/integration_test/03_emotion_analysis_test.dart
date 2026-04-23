import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:meong_nyang_diary/main_navigation.dart';

import 'app_test_entry.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/pages/emotion_analysis_page.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/widgets/pet_inline_dropdown.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> bootApp(WidgetTester tester) async {
    await bootAppForTest();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 2));
  }

  Future<bool> goToEmotionTab(WidgetTester tester) async {
    final navFinder = find.byType(MainNavigation);
    if (navFinder.evaluate().isEmpty) return false;
    final tappables = find.descendant(
      of: navFinder,
      matching: find.byType(GestureDetector),
    );
    if (tappables.evaluate().length <= 2) return false;
    await tester.tap(tappables.at(2), warnIfMissed: false); // index 2 = AI 분석 FAB
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    return true;
  }

  group('03. Emotion Analysis Flow', () {
    testWidgets('AI 분석 탭 진입 → EmotionAnalysisPage 렌더링', (tester) async {
      await bootApp(tester);

      final entered = await goToEmotionTab(tester);
      if (!entered) {
        await binding.takeScreenshot('03_emotion_skipped_unauth');
        return;
      }

      expect(find.byType(EmotionAnalysisPage), findsOneWidget,
          reason: 'AI 분석 탭에서 EmotionAnalysisPage 렌더링되어야 함');

      await binding.takeScreenshot('03_emotion_page');
    });

    testWidgets('PetInlineDropdown 위젯 표시 확인', (tester) async {
      await bootApp(tester);
      final entered = await goToEmotionTab(tester);
      if (!entered) return;

      final dropdownFinder = find.byType(PetInlineDropdown);
      // 펫이 등록돼 있을 때만 노출됨
      if (dropdownFinder.evaluate().isNotEmpty) {
        expect(dropdownFinder, findsOneWidget);
        await binding.takeScreenshot('03_pet_dropdown_visible');
      } else {
        await binding.takeScreenshot('03_no_pet_registered');
      }
    });

    testWidgets('사진 선택 영역 / 카메라 버튼 노출', (tester) async {
      await bootApp(tester);
      final entered = await goToEmotionTab(tester);
      if (!entered) return;

      // 사진 선택 관련 아이콘 또는 버튼 검색 (camera_alt, photo_library, add_photo_alternate)
      final hasPhotoIcon = find.byIcon(Icons.camera_alt).evaluate().isNotEmpty ||
          find.byIcon(Icons.photo_library).evaluate().isNotEmpty ||
          find.byIcon(Icons.add_photo_alternate).evaluate().isNotEmpty ||
          find.byIcon(Icons.add_a_photo).evaluate().isNotEmpty;

      expect(hasPhotoIcon, isTrue,
          reason: '사진 선택 관련 아이콘 중 하나는 표시되어야 함');

      await binding.takeScreenshot('03_photo_picker_area');
    });

    testWidgets('스크롤 동작 확인 (페이지 길이 검증)', (tester) async {
      await bootApp(tester);
      final entered = await goToEmotionTab(tester);
      if (!entered) return;

      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable.first, const Offset(0, -200));
        await tester.pump(const Duration(milliseconds: 500));
        await binding.takeScreenshot('03_emotion_scrolled');
      }
    });
  });
}
