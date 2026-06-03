import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/mbti/data/datasources/mbti_content_data_source.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/mbti_content.dart';
import 'package:meong_nyang_diary/features/mbti/presentation/theme/mbti_theme.dart';
import 'package:meong_nyang_diary/features/mbti/presentation/widgets/mbti_choice_card.dart';
import 'package:meong_nyang_diary/features/mbti/presentation/widgets/mbti_progress_bar.dart';
import 'package:meong_nyang_diary/features/mbti/presentation/widgets/mbti_scoring_view.dart';

/// 검사 플로우 화면 톤 검토용 스크린샷 캡처.
///
/// 실행: flutter test test/features/mbti/mbti_screenshot_capture.dart
/// 결과: build/mbti_screenshots/*.png
///
/// 실제 라우팅/BLoC 없이 위젯을 직접 렌더해 톤·정합성만 확인한다.
void main() {
  const outDir = 'build/mbti_screenshots';

  Future<void> capture(WidgetTester tester, String name) async {
    // pumpAndSettle 은 진행 바 애니메이션 등으로 행될 수 있어 고정 pump 로 대체.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary),
    );
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(outDir).createSync(recursive: true);
    File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  // child 를 빌더로 받아 ScreenUtilInit 내부(=ScreenUtil 초기화 후)에서
  // 빌드되게 한다. (.w/.h/.sp 를 인자 평가 시점에 호출하면 LateInitError 발생)
  Widget frame(WidgetBuilder childBuilder) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Pretendard'),
        home: Center(
          child: RepaintBoundary(
            child: SizedBox(
              width: 390,
              height: 844,
              child: Builder(
                builder: (context) => Container(
                  color: MbtiTheme.bg,
                  child: childBuilder(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('capture: 문항 화면(선택 전)', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(frame((context) =>
      SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: const MbtiProgressBar(current: 5, total: 20),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.h),
                    Text('Q5.',
                        style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: MbtiTheme.coral)),
                    SizedBox(height: 8.h),
                    Text('낯선 사람이 집에 오면?',
                        style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: MbtiTheme.textPrimary)),
                    SizedBox(height: 28.h),
                    MbtiChoiceCard(
                        badge: 'A',
                        label: '반갑게 다가가 인사한다',
                        selected: false,
                        onTap: () {}),
                    SizedBox(height: 14.h),
                    MbtiChoiceCard(
                        badge: 'B',
                        label: '멀찌이 지켜보거나 숨는다',
                        selected: false,
                        onTap: () {}),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ));
    await capture(tester, '02_question_unselected');
  });

  testWidgets('capture: 문항 화면(선택 후, 후반부 격려)', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(frame((context) =>
      SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: const MbtiProgressBar(current: 16, total: 20),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.h),
                    Text('Q16.',
                        style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: MbtiTheme.coral)),
                    SizedBox(height: 8.h),
                    Text('하루 일과는?',
                        style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: MbtiTheme.textPrimary)),
                    SizedBox(height: 28.h),
                    MbtiChoiceCard(
                        badge: 'A',
                        label: '밥·산책 시간이 규칙적이다',
                        selected: true,
                        onTap: () {}),
                    SizedBox(height: 14.h),
                    MbtiChoiceCard(
                        badge: 'B',
                        label: '그날그날 들쭉날쭉하다',
                        selected: false,
                        onTap: () {}),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ));
    await capture(tester, '03_question_selected');
  });

  testWidgets('capture: 계산 연출', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(frame((context) =>
      SizedBox.expand(child: MbtiScoringView(onComplete: () {})),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    // pumpAndSettle 은 무한 애니메이션 때문에 타임아웃되므로 단발 pump 후 캡처.
    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary),
    );
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(outDir).createSync(recursive: true);
    File('$outDir/04_scoring.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });

  testWidgets('capture: 인트로(etc 칩 포함)', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    // 실제 면책 문구를 번들에서 로드해 인트로 톤을 그대로 캡처.
    MbtiContent content;
    try {
      content = await MbtiContentDataSourceImpl().loadContent();
    } catch (_) {
      return; // 에셋 미탑재 환경이면 스킵.
    }

    await tester.pumpWidget(frame((context) =>
      SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text('🐾', style: TextStyle(fontSize: 56.sp))),
              SizedBox(height: 20.h),
              Text('우리 아이의\n성격 유형을 알아볼까요?',
                  style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: MbtiTheme.textPrimary)),
              SizedBox(height: 12.h),
              Text('평소 모습을 떠올리며 20개 질문에 답해 주세요.\n2~3분이면 충분해요.',
                  style: TextStyle(
                      fontSize: 14.sp,
                      height: 1.5,
                      color: MbtiTheme.textSecondary)),
              SizedBox(height: 20.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: MbtiTheme.navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(100.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline,
                        size: 15.w, color: MbtiTheme.navy),
                    SizedBox(width: 6.w),
                    Text('범용 문항 기반 결과예요',
                        style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: MbtiTheme.navy)),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: MbtiTheme.bg,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(content.disclaimer,
                    style: TextStyle(
                        fontSize: 11.sp,
                        height: 1.5,
                        color: MbtiTheme.textSecondary)),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MbtiTheme.navy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: Text('검사 시작하기',
                      style: TextStyle(
                          fontSize: 16.sp, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await capture(tester, '01_intro');
  });
}
