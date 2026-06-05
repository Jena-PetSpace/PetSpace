import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/config/injection_container.dart' show sl;
import 'package:meong_nyang_diary/features/fortune/data/datasources/fortune_content_data_source.dart';
import 'package:meong_nyang_diary/features/fortune/domain/services/fortune_generator.dart';
import 'package:meong_nyang_diary/features/fortune/presentation/pages/fortune_detail_page.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/pet_mbti_result.dart';

/// 운세 상세 화면 톤 검토용 스크린샷 캡처 (개발 도구 — CI 비포함).
///
/// 실행: flutter test test/features/fortune/fortune_screenshot_capture.dart
/// 결과: build/fortune_screenshots/*.png
///
/// ⚠️ 일부 헤드리스(Windows) 환경에서 RenderRepaintBoundary.toImage() 가
/// 반환되지 않아 테스트가 타임아웃될 수 있다(기존 MBTI 캡처와 동일 한계).
/// PNG 는 toImage 직후 기록되므로 산출물 확인용으로만 쓰고, 정합성 검증은
/// presentation/fortune_detail_page_test.dart(위젯 테스트)로 대신한다.
void main() {
  const outDir = 'build/fortune_screenshots';

  void registerDeps() {
    if (!sl.isRegistered<FortuneContentDataSource>()) {
      sl.registerLazySingleton<FortuneContentDataSource>(
          () => FortuneContentDataSourceImpl());
    }
    if (!sl.isRegistered<FortuneGenerator>()) {
      sl.registerLazySingleton(() => const FortuneGenerator());
    }
  }

  Future<void> capture(
    WidgetTester tester,
    String name, {
    required String petId,
    required MbtiSpecies species,
    required String dateKey,
    String? petName,
    String? mbtiTypeCode,
  }) async {
    registerDeps();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Pretendard'),
          home: RepaintBoundary(
            child: FortuneDetailPage(
              petId: petId,
              species: species,
              dateKey: dateKey,
              petName: petName,
              mbtiTypeCode: mbtiTypeCode,
            ),
          ),
        ),
      ),
    );
    // FutureBuilder(콘텐츠 로드+생성) 완료 대기.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary),
    );
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(outDir).createSync(recursive: true);
    File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());

    // 로딩 인디케이터(무한 애니메이션)의 pending ticker 를 제거해 테스트가
    // teardown 에서 타임아웃되지 않게 빈 트리로 교체. (캡처는 이미 끝남)
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('capture: 강아지(외교관 그룹, 이름 초코)', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await capture(
      tester,
      '01_dog_diplomat',
      petId: 'dog-pet-1',
      species: MbtiSpecies.dog,
      dateKey: '20260604',
      petName: '초코',
      mbtiTypeCode: 'ENFP', // 외교관(coral 톤 그룹) 종합운
    );
  });

  testWidgets('capture: 고양이(MBTI 없음 → default 종합운)', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await capture(
      tester,
      '02_cat_default',
      petId: 'cat-pet-1',
      species: MbtiSpecies.cat,
      dateKey: '20260604',
      petName: '나비',
      // mbtiTypeCode 없음 → default 폴백
    );
  });

  testWidgets('capture: 기타 etc(범용 운세 칩, 이름 없음 → 우리 아이)', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await capture(
      tester,
      '03_etc_generic_noname',
      petId: 'etc-pet-1',
      species: MbtiSpecies.etc,
      dateKey: '20260604',
      // petName 없음 → "우리 아이"
    );
  });
}
