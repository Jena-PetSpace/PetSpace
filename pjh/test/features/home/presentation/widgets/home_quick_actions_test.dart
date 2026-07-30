import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:meong_nyang_diary/shared/models/petspace_icon_asset.dart';
import 'package:meong_nyang_diary/shared/widgets/petspace_icon.dart';

void main() {
  Widget buildSubject() {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) =>
          const MaterialApp(home: Scaffold(body: HomeQuickActions())),
    );
  }

  testWidgets('홈 바로가기 5종을 컬러 자산으로 노출한다', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    for (final label in const [
      '플레이스',
      'MBTI 검사',
      '산책 기록',
      '오늘의 운세',
      'O/X 퀴즈',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    final icons = tester
        .widgetList<PetSpaceIcon>(find.byType(PetSpaceIcon))
        .map((widget) => widget.asset)
        .toList();

    expect(icons, const [
      PetSpaceIconAsset.quickPlace,
      PetSpaceIconAsset.quickMbti,
      PetSpaceIconAsset.quickWalk,
      PetSpaceIconAsset.quickFortune,
      PetSpaceIconAsset.quickQuiz,
    ]);
    expect(find.byType(Image), findsNWidgets(5));
  });

  testWidgets('각 바로가기는 중복 없는 버튼 접근성 라벨을 가진다', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    for (final label in const [
      '플레이스',
      'MBTI 검사',
      '산책 기록',
      '오늘의 운세',
      'O/X 퀴즈',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    semantics.dispose();
  });
}
