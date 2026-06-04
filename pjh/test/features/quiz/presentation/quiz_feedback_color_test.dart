import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/quiz/presentation/theme/quiz_theme.dart';
import 'package:meong_nyang_diary/features/quiz/presentation/widgets/quiz_feedback_banner.dart';
import 'package:meong_nyang_diary/features/quiz/presentation/widgets/quiz_ox_button.dart';

/// "빨강 금지" 규칙을 코드로 고정 — 오답 피드백이 순수 빨강 계열을 쓰지 않고,
/// 색 외 단서(아이콘+텍스트)를 항상 병기하는지 검증. 스크린샷보다 강한 보장.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 순수 빨강 계열인지(빨강 우세 + 초록/파랑 낮음) 판정. 코랄(FF6F61)은
  /// R 높지만 G(0x6F)·B(0x61)가 충분히 있어 "순수 빨강"이 아니다.
  bool isPlainRed(Color c) {
    final r = (c.r * 255).round();
    final g = (c.g * 255).round();
    final b = (c.b * 255).round();
    return r > 180 && g < 80 && b < 80;
  }

  Widget wrap(Widget child) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('오답 배너: 코랄(빨강 아님) + cancel 아이콘 + "오답" 텍스트', (tester) async {
    await tester.pumpWidget(wrap(
      const QuizFeedbackBanner(isCorrect: false, explain: '해설 텍스트'),
    ));
    await tester.pump();

    // 아이콘 + 텍스트(색 외 단서) 병기.
    expect(find.byIcon(Icons.cancel), findsOneWidget);
    expect(find.text('오답'), findsOneWidget);
    expect(find.text('해설 텍스트'), findsOneWidget);

    // 사용 색이 코랄이며 순수 빨강이 아님.
    expect(QuizTheme.incorrect, const Color(0xFFFF6F61));
    expect(isPlainRed(QuizTheme.incorrect), isFalse);
  });

  testWidgets('정답 배너: 틸(초록 계열) + check 아이콘 + "정답" 텍스트', (tester) async {
    await tester.pumpWidget(wrap(
      const QuizFeedbackBanner(isCorrect: true, explain: '정답 해설'),
    ));
    await tester.pump();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('정답'), findsOneWidget);
    expect(isPlainRed(QuizTheme.correct), isFalse);
  });

  testWidgets('오답 선택 버튼: cancel 아이콘으로 색 외 단서 제공', (tester) async {
    await tester.pumpWidget(wrap(
      const Row(children: [
        QuizOxButton(
            value: 'O',
            locked: true,
            isSelected: true,
            isCorrectAnswer: false), // 내가 고른 오답
        QuizOxButton(
            value: 'X',
            locked: true,
            isSelected: false,
            isCorrectAnswer: true), // 실제 정답
      ]),
    ));
    await tester.pump();

    // 오답 칸엔 cancel, 정답 칸엔 check_circle_outline(색 외 단서).
    expect(find.byIcon(Icons.cancel), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  test('테마 색 상수: 오답=코랄, 정답=틸, 둘 다 순수 빨강 아님', () {
    expect(QuizTheme.incorrect, const Color(0xFFFF6F61));
    expect(QuizTheme.correct, const Color(0xFF2E7D6B));
    expect(isPlainRed(QuizTheme.incorrect), isFalse);
    expect(isPlainRed(QuizTheme.correct), isFalse);
  });
}
