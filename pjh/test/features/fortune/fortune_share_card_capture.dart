import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/fortune/data/datasources/fortune_content_data_source.dart';
import 'package:meong_nyang_diary/features/fortune/domain/services/fortune_generator.dart';
import 'package:meong_nyang_diary/features/fortune/presentation/widgets/fortune_share_card.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/pet_mbti_result.dart';

/// 운세 공유 카드 톤 검토용 캡처 (개발 도구 — CI 비포함).
///
/// 실행: flutter test test/features/fortune/fortune_share_card_capture.dart
/// 결과: build/fortune_screenshots/share_*.png
/// (toImage 헤드리스 한계로 teardown 타임아웃 가능 — PNG 는 기록됨)
void main() {
  const outDir = 'build/fortune_screenshots';

  /// 단색 PNG 한 장을 즉석에서 만들어 "사진 포함" 케이스 대용으로 쓴다.
  Future<Uint8List> solidPng(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 200, 200), paint);
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 200);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> captureCard(
    WidgetTester tester,
    String name,
    Widget card,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Pretendard'),
        home: Scaffold(
          backgroundColor: const Color(0xFFEFEFEF),
          body: Center(
            child: RepaintBoundary(child: card),
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

  testWidgets('capture: 공유 카드 (사진 OFF — 기본 🐾)', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final content = await FortuneContentDataSourceImpl().loadContent();
    final fortune = const FortuneGenerator().generate(
      petId: 'share-pet',
      species: MbtiSpecies.dog,
      dateKey: '20260604',
      content: content,
      mbtiTypeCode: 'ENFP',
      petName: '초코',
    );

    await captureCard(
      tester,
      'share_01_no_photo',
      FortuneShareCard(fortune: fortune, petName: '초코'),
    );
  });

  testWidgets('capture: 공유 카드 (사진 ON)', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final content = await FortuneContentDataSourceImpl().loadContent();
    final fortune = const FortuneGenerator().generate(
      petId: 'share-pet',
      species: MbtiSpecies.cat,
      dateKey: '20260604',
      content: content,
      petName: '나비',
    );
    final photo = await solidPng(const Color(0xFFB8C7E0));

    await captureCard(
      tester,
      'share_02_with_photo',
      FortuneShareCard(
        fortune: fortune,
        petName: '나비',
        photoBytes: photo,
        includePhoto: true,
      ),
    );
  });

  testWidgets('capture: 공유 카드 (etc, 이름 없음 → 우리 아이)', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final content = await FortuneContentDataSourceImpl().loadContent();
    final fortune = const FortuneGenerator().generate(
      petId: 'share-etc',
      species: MbtiSpecies.etc,
      dateKey: '20260604',
      content: content,
    );

    await captureCard(
      tester,
      'share_03_etc_noname',
      FortuneShareCard(fortune: fortune),
    );
  });
}
