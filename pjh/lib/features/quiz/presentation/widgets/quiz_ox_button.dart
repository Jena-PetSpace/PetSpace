import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/quiz_theme.dart';

/// O 또는 X 큰 선택 버튼 1개.
///
/// 상태(잠금 전/후)에 따라 시각이 달라진다. **색에만 의존하지 않도록** 채점 후
/// 선택지에는 항상 결과 아이콘(check/close)을 함께 띄우고, Semantics 라벨로
/// 스크린리더에도 정답/오답을 전달한다.
class QuizOxButton extends StatelessWidget {
  /// 'O' 또는 'X'.
  final String value;

  /// 아직 답을 안 골랐는지(=탭 가능).
  final bool locked;

  /// 이 버튼이 사용자가 고른 선택지인지.
  final bool isSelected;

  /// 이 버튼이 정답인지(잠금 후 정답 강조용).
  final bool isCorrectAnswer;

  final VoidCallback? onTap;

  const QuizOxButton({
    super.key,
    required this.value,
    required this.locked,
    required this.isSelected,
    required this.isCorrectAnswer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isO = value == 'O';

    // ── 잠금 후 시각 결정 ──
    // 1) 사용자가 고른 게 정답: 틸(정답)
    // 2) 사용자가 고른 게 오답: 코랄(오답)
    // 3) 사용자가 안 골랐지만 정답인 칸: 틸 외곽선(정답 위치 안내)
    // 4) 그 외(안 고른 오답): 흐리게
    Color borderColor;
    Color fillColor;
    Color glyphColor;
    double borderWidth = 1.5;
    IconData? resultIcon;
    String semantic = isO ? 'O' : 'X';

    if (!locked) {
      borderColor = QuizTheme.navy;
      fillColor = QuizTheme.surface;
      glyphColor = QuizTheme.navy;
    } else if (isSelected && isCorrectAnswer) {
      borderColor = QuizTheme.correct;
      fillColor = QuizTheme.correct.withValues(alpha: 0.10);
      glyphColor = QuizTheme.correct;
      borderWidth = 2.5;
      resultIcon = Icons.check_circle;
      semantic = '${isO ? 'O' : 'X'}, 내가 고른 정답';
    } else if (isSelected && !isCorrectAnswer) {
      borderColor = QuizTheme.incorrect;
      fillColor = QuizTheme.incorrect.withValues(alpha: 0.10);
      glyphColor = QuizTheme.incorrect;
      borderWidth = 2.5;
      resultIcon = Icons.cancel;
      semantic = '${isO ? 'O' : 'X'}, 내가 고른 오답';
    } else if (!isSelected && isCorrectAnswer) {
      borderColor = QuizTheme.correct;
      fillColor = QuizTheme.surface;
      glyphColor = QuizTheme.correct;
      borderWidth = 2.0;
      resultIcon = Icons.check_circle_outline;
      semantic = '${isO ? 'O' : 'X'}, 실제 정답';
    } else {
      borderColor = QuizTheme.divider;
      fillColor = QuizTheme.surface;
      glyphColor = QuizTheme.textSecondary.withValues(alpha: 0.5);
    }

    return Expanded(
      child: Semantics(
        button: !locked,
        label: semantic,
        child: GestureDetector(
          onTap: locked ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 120.h,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: Stack(
              children: [
                // 가운데 큰 O/X 글리프
                Center(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 56.sp,
                      fontWeight: FontWeight.w800,
                      color: glyphColor,
                      height: 1,
                    ),
                  ),
                ),
                // 우상단 결과 아이콘(색각 보조 — 색 외 단서)
                if (resultIcon != null)
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: Icon(resultIcon, size: 22.sp, color: glyphColor),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
