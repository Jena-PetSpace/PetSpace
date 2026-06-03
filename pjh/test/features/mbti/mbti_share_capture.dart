import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/mbti/data/datasources/mbti_content_data_source.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/mbti_content.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/pet_mbti_result.dart';
import 'package:meong_nyang_diary/features/mbti/presentation/widgets/mbti_share_card.dart';

const _outDir = 'build/mbti_screenshots';

AxisScore _ax(String p, String n, int pc, int nc) => AxisScore(
      positivePole: p, negativePole: n, positiveCount: pc, negativeCount: nc,
    );

PetMbtiResult _enfp() => PetMbtiResult(
      id: 's', petId: 'p', species: MbtiSpecies.dog, typeCode: 'ENFP',
      axisScores: {
        'EI': _ax('E', 'I', 4, 1),
        'SN': _ax('S', 'N', 1, 4),
        'TF': _ax('T', 'F', 2, 3),
        'JP': _ax('J', 'P', 0, 5),
      },
      answers: const [], contentVersion: 1, createdAt: DateTime(2026, 6, 3),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MbtiContent content;

  setUpAll(() async {
    content = await MbtiContentDataSourceImpl().loadContent();
  });

  testWidgets('capture: 공유 카드 (사진 미포함 = 기본 발바닥)', (tester) async {
    tester.view.physicalSize = const Size(420 * 3, 720 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Pretendard'),
        home: Scaffold(
          backgroundColor: const Color(0xFFEAEAEA),
          body: Center(
            child: RepaintBoundary(
              child: MbtiShareCard(
                result: _enfp(),
                content: content,
                petName: '초코',
                includePhoto: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary),
    );
    final image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/10_share_card_default.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
