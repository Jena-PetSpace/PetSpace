// ignore_for_file: file_names
//
// 반려동물 MBTI 결과/플로우 화면 실기기(실폰트) 스크린샷 캡처.
//
// 실행 예:
//   flutter test integration_test/06_mbti_test.dart -d windows
//   flutter test integration_test/06_mbti_test.dart -d <emulator-id>
//
// DI 가 초기화된 상태에서 결과/검사 위젯을 직접 pump 해 실제 Pretendard·이모지·
// 색으로 렌더한 뒤 takeScreenshot 으로 캡처한다. (로그인/네비게이션 우회)

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:meong_nyang_diary/features/mbti/domain/entities/pet_mbti_result.dart';
import 'package:meong_nyang_diary/features/mbti/presentation/pages/mbti_result_page.dart';
import 'package:meong_nyang_diary/features/mbti/presentation/pages/mbti_test_page.dart';
import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

import 'app_test_entry.dart';

AxisScore _axis(String pos, String neg, int p, int n) => AxisScore(
      positivePole: pos,
      negativePole: neg,
      positiveCount: p,
      negativeCount: n,
    );

/// 샘플 결과(외교관 그룹 ENFP, 강아지) — 그룹색 coral 확인.
PetMbtiResult _enfpDog() => PetMbtiResult(
      id: 'sample-enfp',
      petId: 'pet-1',
      species: MbtiSpecies.dog,
      typeCode: 'ENFP',
      axisScores: {
        'EI': _axis('E', 'I', 4, 1),
        'SN': _axis('S', 'N', 1, 4),
        'TF': _axis('T', 'F', 2, 3),
        'JP': _axis('J', 'P', 0, 5),
      },
      answers: const [],
      contentVersion: 1,
      createdAt: DateTime(2026, 6, 3),
    );

/// 샘플 결과(관리자 그룹 ISTJ, etc) — 그룹색 navy + etc 칩 확인.
PetMbtiResult _istjEtc() => PetMbtiResult(
      id: 'sample-istj',
      petId: 'pet-2',
      species: MbtiSpecies.etc,
      typeCode: 'ISTJ',
      axisScores: {
        'EI': _axis('E', 'I', 1, 4),
        'SN': _axis('S', 'N', 5, 0),
        'TF': _axis('T', 'F', 3, 2),
        'JP': _axis('J', 'P', 4, 1),
      },
      answers: const [],
      contentVersion: 1,
      createdAt: DateTime(2026, 6, 3),
    );

Widget _host(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('06. MBTI 화면 스크린샷', () {
    testWidgets('결과 화면 — ENFP 강아지(외교관/coral)', (tester) async {
      await bootAppForTest();
      // 데스크톱/실기기 표면 캡처를 위해 필요(웹 외 플랫폼).
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpWidget(_host(
        MbtiResultPage(result: _enfpDog(), petName: '초코'),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await binding.takeScreenshot('06_result_enfp_dog');
    });

    testWidgets('결과 화면 — ISTJ etc(관리자/navy + etc 칩)', (tester) async {
      await bootAppForTest();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpWidget(_host(
        MbtiResultPage(result: _istjEtc()),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await binding.takeScreenshot('06_result_istj_etc');
    });

    testWidgets('검사 인트로 — etc 칩', (tester) async {
      await bootAppForTest();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpWidget(_host(
        const MbtiTestPage(
          petId: 'pet-x',
          species: MbtiSpecies.etc,
          petName: '나비',
        ),
      ));
      await tester.pump(const Duration(milliseconds: 800));
      await binding.takeScreenshot('06_intro_etc');
    });

    testWidgets('검사 문항 — 첫 문항(강아지)', (tester) async {
      await bootAppForTest();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpWidget(_host(
        const MbtiTestPage(
          petId: 'pet-y',
          species: MbtiSpecies.dog,
          petName: '초코',
        ),
      ));
      await tester.pump(const Duration(milliseconds: 800));
      // 인트로 "검사 시작하기" 탭 → 첫 문항 진입
      final startBtn = find.text('검사 시작하기');
      if (startBtn.evaluate().isNotEmpty) {
        await tester.tap(startBtn);
        await tester.pump(const Duration(milliseconds: 500));
      }
      await binding.takeScreenshot('06_question_first');
    });
  });
}
