import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/emotion/presentation/constants/capture_guide_content.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/pages/analysis_guide_page.dart';

/// 촬영가이드 7종(감정 1 + 건강 6) 렌더링 스모크 테스트.
/// 레이아웃 예외(오버플로우 포함)와 필수 섹션 표시를 검증한다.
void main() {
  Widget wrap(Widget child) => ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(home: child),
      );

  Future<void> pumpGuide(
    WidgetTester tester, {
    required bool isEmotion,
    String? area,
  }) async {
    await tester.pumpWidget(
      wrap(AnalysisGuidePage(
        isEmotion: isEmotion,
        area: area,
        onImagesSelected: (_) {},
      )),
    );
    await tester.pump();
  }

  const healthAreas = [
    '눈·귀',
    '코·입',
    '피부·털',
    '체형(BCS)',
    '자세·체형 대칭',
    '종합(전체)',
  ];

  Future<void> verifySections(
    WidgetTester tester,
    CaptureGuideContent content,
  ) async {
    expect(find.text(content.title), findsOneWidget);
    expect(find.text(content.subtitle), findsOneWidget);
    expect(find.text('이렇게 촬영해주세요'), findsOneWidget);
    expect(find.text('카메라'), findsOneWidget);
    expect(find.text('갤러리'), findsOneWidget);
    // 아래 섹션들은 화면 밖(ListView lazy build)이라 스크롤하며 순차 확인
    final scrollable = find.byType(Scrollable).first;
    for (final label in ['이런 촬영은 피해주세요', '촬영 전 체크리스트']) {
      await tester.scrollUntilVisible(find.text(label), 150,
          scrollable: scrollable);
      expect(find.text(label), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.textContaining('수의사의 진단'), 150,
        scrollable: scrollable);
    expect(find.textContaining('수의사의 진단'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets('감정 분석 가이드 렌더링', (tester) async {
    await pumpGuide(tester, isEmotion: true);
    await verifySections(
      tester,
      CaptureGuideContent.of(CaptureGuideType.emotion),
    );
  });

  for (final area in healthAreas) {
    testWidgets('건강 가이드 렌더링: $area', (tester) async {
      await pumpGuide(tester, isEmotion: false, area: area);
      final type = CaptureGuideType.fromArea(isEmotion: false, area: area);
      await verifySections(tester, CaptureGuideContent.of(type));
    });
  }
}
