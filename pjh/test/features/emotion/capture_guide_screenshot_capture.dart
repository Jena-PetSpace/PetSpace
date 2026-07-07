import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/emotion/presentation/constants/capture_guide_content.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/pages/analysis_guide_page.dart';

/// 촬영가이드 7종 톤 검토용 스크린샷 캡처 (개발 도구 — CI 비포함).
///
/// 실행: flutter test test/features/emotion/capture_guide_screenshot_capture.dart
/// 결과: build/capture_guide_screenshots/*.png (종별 상단/하단 2컷)
///
/// ⚠️ 일부 헤드리스(Windows) 환경에서 RenderRepaintBoundary.toImage() 가
/// 반환되지 않아 타임아웃될 수 있다(기존 MBTI·운세 캡처와 동일 한계).
/// 정합성 검증은 presentation/pages/analysis_guide_page_test.dart 로 대신한다.
void main() {
  const outDir = 'build/capture_guide_screenshots';

  setUpAll(() async {
    // 실제 한글 렌더링을 위해 Pretendard 로드 (미로드 시 □ 로 표시됨)
    final loader = FontLoader('Pretendard');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final bytes = File('assets/fonts/Pretendard-$weight.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  });

  Future<void> saveBoundary(WidgetTester tester, String name) async {
    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary),
    );
    // toImage/toByteData는 실제 비동기(래스터) 작업이라 fake-async 존에서
    // 완료되지 않을 수 있음 → runAsync로 실행 (헤드리스 Windows 행 방지)
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    Directory(outDir).createSync(recursive: true);
    File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  Future<void> capture(
    WidgetTester tester,
    String name, {
    required bool isEmotion,
    String? area,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Pretendard'),
          home: RepaintBoundary(
            child: AnalysisGuidePage(
              isEmotion: isEmotion,
              area: area,
              onImagesSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 예시 사진을 실제 디코드해 PNG에 나오게 함 (테스트 기본 환경에선
    // 이미지 로드가 pending 상태로 남으므로 runAsync로 완료시킨다)
    final context = tester.element(find.byType(AnalysisGuidePage));
    final content = CaptureGuideContent.of(
      CaptureGuideType.fromArea(isEmotion: isEmotion, area: area),
    );
    await tester.runAsync(() async {
      for (final e in [...content.goodExamples, ...content.badExamples]) {
        await precacheImage(AssetImage(e.assetPath), context);
      }
    });
    await tester.pump();

    await saveBoundary(tester, '${name}_1_top');

    // 하단(체크리스트·면책 문구)까지 스크롤 후 한 컷 더
    await tester.scrollUntilVisible(
      find.textContaining('수의사의 진단'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await saveBoundary(tester, '${name}_2_bottom');

    await tester.pumpWidget(const SizedBox.shrink());
  }

  const targets = <String, ({bool isEmotion, String? area})>{
    '01_emotion': (isEmotion: true, area: null),
    '02_eye_ear': (isEmotion: false, area: '눈·귀'),
    '03_nose_mouth': (isEmotion: false, area: '코·입'),
    '04_skin_fur': (isEmotion: false, area: '피부·털'),
    '05_body_bcs': (isEmotion: false, area: '체형(BCS)'),
    '06_posture': (isEmotion: false, area: '자세·체형 대칭'),
    '07_full_body': (isEmotion: false, area: '종합(전체)'),
  };

  for (final entry in targets.entries) {
    testWidgets('capture: ${entry.key}', (tester) async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await capture(
        tester,
        entry.key,
        isEmotion: entry.value.isEmotion,
        area: entry.value.area,
      );
    });
  }
}
