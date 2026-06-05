import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/config/injection_container.dart' show sl;
import 'package:meong_nyang_diary/features/fortune/data/datasources/fortune_content_data_source.dart';
import 'package:meong_nyang_diary/features/fortune/domain/services/fortune_generator.dart';
import 'package:meong_nyang_diary/features/fortune/presentation/pages/fortune_detail_page.dart';
import 'package:meong_nyang_diary/features/fortune/presentation/widgets/fortune_stars.dart';
import 'package:meong_nyang_diary/features/mbti/domain/entities/pet_mbti_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    if (!sl.isRegistered<FortuneContentDataSource>()) {
      sl.registerLazySingleton<FortuneContentDataSource>(
          () => FortuneContentDataSourceImpl());
    }
    if (!sl.isRegistered<FortuneGenerator>()) {
      sl.registerLazySingleton(() => const FortuneGenerator());
    }
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required String petId,
    required MbtiSpecies species,
    String? petName,
    String? mbtiTypeCode,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          home: FortuneDetailPage(
            petId: petId,
            species: species,
            dateKey: '20260604',
            petName: petName,
            mbtiTypeCode: mbtiTypeCode,
          ),
        ),
      ),
    );
    // FutureBuilder(콘텐츠 로드+생성) 완료까지 프레임 진행.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('헤더·날짜·면책·공유버튼·세부 3개·럭키 2개 렌더', (tester) async {
    await pumpPage(tester, petId: 'dog-1', species: MbtiSpecies.dog, petName: '초코');

    // 앱바 + 날짜
    expect(find.text('오늘의 운세'), findsOneWidget);
    expect(find.text('2026년 6월 4일'), findsOneWidget);

    // 세부 운세 섹션 + 강아지 항목 라벨 3개
    expect(find.text('오늘의 세부 운세'), findsOneWidget);
    expect(find.text('인싸력'), findsOneWidget);
    expect(find.text('사고력'), findsOneWidget);
    expect(find.text('득템운'), findsOneWidget);

    // 럭키 2개 + 면책 + 공유 버튼 자리
    expect(find.text('🍖 오늘의 럭키 간식'), findsOneWidget);
    expect(find.text('📍 오늘의 럭키 플레이스'), findsOneWidget);
    expect(find.textContaining('재미로 보는 콘텐츠'), findsOneWidget);
    expect(find.text('운세 공유하기'), findsOneWidget);

    // 별점 위젯: 종합 1 + 세부 3 = 최소 4개
    expect(find.byType(FortuneStars), findsNWidgets(4));
  });

  testWidgets('etc 종일 때만 범용 운세 칩 노출', (tester) async {
    await pumpPage(tester, petId: 'etc-1', species: MbtiSpecies.etc);
    expect(find.text('범용 운세예요'), findsOneWidget);
    // etc 항목 라벨
    expect(find.text('간드미'), findsOneWidget);
    expect(find.text('꿀잠운'), findsOneWidget);
  });

  testWidgets('강아지엔 범용 칩 미노출', (tester) async {
    await pumpPage(tester, petId: 'dog-2', species: MbtiSpecies.dog);
    expect(find.text('범용 운세예요'), findsNothing);
  });

  testWidgets('고양이엔 범용 칩 미노출 + 고양이 항목 라벨', (tester) async {
    await pumpPage(tester, petId: 'cat-2', species: MbtiSpecies.cat);
    expect(find.text('범용 운세예요'), findsNothing);
    expect(find.text('간택운'), findsOneWidget); // 고양이 항목(chosen)
    expect(find.text('냥아치력'), findsOneWidget); // rascal
  });

  testWidgets('이름 없으면 "우리 아이"로 치환(토큰 잔존 없음)', (tester) async {
    await pumpPage(tester, petId: 'etc-noname', species: MbtiSpecies.etc);
    // 종합운에 토큰이 남아있지 않아야 함
    expect(find.textContaining('{petName}'), findsNothing);
  });
}
