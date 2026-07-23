import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/emotion/presentation/theme/emotion_result_tokens.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/widgets/result/bottom_action_bar.dart';

void main() {
  testWidgets('분석 결과 하단 액션은 결과 캔버스와 이어지고 구분선이 없다', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            backgroundColor: EmotionResultTokens.background,
            bottomNavigationBar: BottomActionBar(
              onShare: () {},
              onSave: () {},
              onHistory: () {},
            ),
          ),
        ),
      ),
    );

    final actionBar = find.byType(BottomActionBar);
    final container = tester.widget<Container>(
      find.descendant(of: actionBar, matching: find.byType(Container)).first,
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, EmotionResultTokens.background);
    expect(decoration.border, isNull);
  });
}
