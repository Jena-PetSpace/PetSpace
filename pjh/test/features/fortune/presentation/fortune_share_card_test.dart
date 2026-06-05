import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/fortune/data/datasources/fortune_content_data_source.dart';
import 'package:meong_nyang_diary/features/fortune/domain/entities/daily_fortune.dart';
import 'package:meong_nyang_diary/features/fortune/domain/services/fortune_generator.dart';
import 'package:meong_nyang_diary/features/fortune/presentation/widgets/fortune_share_card.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/pet_mbti_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FortuneContentDataSourceImpl ds;

  setUpAll(() {
    ds = FortuneContentDataSourceImpl();
  });

  Future<DailyFortune> make(MbtiSpecies species, {String? name}) async {
    final content = await ds.loadContent();
    return const FortuneGenerator().generate(
      petId: 'p-$species',
      species: species,
      dateKey: '20260604',
      content: content,
      petName: name,
      mbtiTypeCode: 'ENFP',
    );
  }

  // 1×1 투명 PNG (toImage 헤드리스 한계를 피해 미리 만든 바이트 상수).
  Uint8List tinyPng() => base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMCAQDXh1Q0AAAAAElFTkSuQmCC',
      );

  Future<void> pump(WidgetTester tester, Widget card) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('구성요소: 날짜·종합운·세부 라벨 3개·럭키·워터마크', (tester) async {
    final f = await make(MbtiSpecies.dog, name: '초코');
    await pump(tester, FortuneShareCard(fortune: f, petName: '초코'));

    expect(find.text('초코 의 오늘의 운세'), findsOneWidget);
    expect(find.text('2026년 6월 4일'), findsOneWidget);
    expect(find.text(f.overall), findsOneWidget);
    // 강아지 세부 라벨
    expect(find.text('인싸력'), findsOneWidget);
    expect(find.text('사고력'), findsOneWidget);
    expect(find.text('득템운'), findsOneWidget);
    // 럭키 + 워터마크
    expect(find.text('🍖 럭키 간식'), findsOneWidget);
    expect(find.text('📍 럭키 플레이스'), findsOneWidget);
    expect(find.textContaining('petspace'), findsOneWidget);
  });

  testWidgets('사진 OFF → 기본 🐾, 사진 ON → Image.memory', (tester) async {
    final f = await make(MbtiSpecies.cat, name: '나비');

    // OFF: photoBytes 없음 → 기본 일러스트, Image.memory 없음
    await pump(tester, FortuneShareCard(fortune: f, petName: '나비'));
    expect(find.byType(Image), findsNothing);
    expect(find.text('🐾'), findsWidgets); // 아바타+워터마크 발바닥

    // ON: photoBytes + includePhoto → Image.memory 1개
    final photo = tinyPng();
    await pump(
      tester,
      FortuneShareCard(
        fortune: f,
        petName: '나비',
        photoBytes: photo,
        includePhoto: true,
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('includePhoto=false 면 photoBytes 있어도 기본 일러스트', (tester) async {
    final f = await make(MbtiSpecies.dog, name: '초코');
    final photo = tinyPng();
    await pump(
      tester,
      FortuneShareCard(
        fortune: f,
        petName: '초코',
        photoBytes: photo,
        includePhoto: false, // 기본 OFF
      ),
    );
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('이름 없으면 "우리 아이"', (tester) async {
    final f = await make(MbtiSpecies.etc);
    await pump(tester, FortuneShareCard(fortune: f));
    expect(find.text('우리 아이 의 오늘의 운세'), findsOneWidget);
  });
}
