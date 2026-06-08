import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/home/presentation/widgets/pet_passport_card.dart';
import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';

/// 펫 여권 카드 워터마크 위 가독성 검토용 캡처 (개발 도구 — CI 비포함).
///
/// 실행: flutter test test/features/pets/pet_passport_card_capture.dart
/// 결과: build/passport_screenshots/passport_*.png
void main() {
  const outDir = 'build/passport_screenshots';

  Pet pet({
    String? mbti,
    String? avatarUrl,
    String? passportNo = 'PAB12345',
    String? surname = 'KIM',
    String? given = 'MONGE',
    String? hanguel = '몽이',
    String country = 'KOR',
  }) =>
      Pet(
        id: 'pet-1',
        userId: 'u1',
        name: '몽이',
        type: PetType.dog,
        gender: PetGender.male,
        birthDate: DateTime(2022, 3, 14),
        avatarUrl: avatarUrl,
        currentMbtiType: mbti,
        passportNo: passportNo,
        passportSurname: surname,
        passportGivenName: given,
        nameHanguel: hanguel,
        countryCode: country,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  Future<void> capture(
    WidgetTester tester,
    String name,
    Widget card,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Pretendard'),
          home: Scaffold(
            // 네이비 헤더 배경 위에 얹히므로 동일 배경으로 캡처.
            backgroundColor: const Color(0xFF1E3A5F),
            body: Center(
              child: RepaintBoundary(
                child: SizedBox(
                  width: 390,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: card,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary),
    );
    final image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(outDir).createSync(recursive: true);
    File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());

    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('capture: 여권카드 — 기분 있음(분포 90%)', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tester.view.physicalSize = const Size(390 * 3, 420 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await capture(
      tester,
      'passport_01_with_mood',
      PetPassportCard(
        pet: pet(mbti: 'ENFP'),
        mood: const PassportMood(label: '편안함', percent: 90, emoji: '😌'),
      ),
    );
  });

  testWidgets('capture: 여권카드 — 미분석(오늘 분석하기 유도)', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tester.view.physicalSize = const Size(390 * 3, 420 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await capture(
      tester,
      'passport_02_no_mood',
      PetPassportCard(pet: pet(mbti: 'ENFP')),
    );
  });

  testWidgets('capture: 여권카드 — MBTI 미검사·사진 없음·미발급', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tester.view.physicalSize = const Size(390 * 3, 420 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await capture(
      tester,
      'passport_03_minimal',
      PetPassportCard(
        pet: pet(
          mbti: null,
          passportNo: null,
          surname: null,
          given: null,
          hanguel: null,
        ),
      ),
    );
  });
}
