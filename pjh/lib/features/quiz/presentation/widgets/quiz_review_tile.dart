import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/entities/quiz_result_snapshot.dart';
import '../theme/quiz_theme.dart';

/// 결과 복기용 문항 1개 타일.
///
/// 모든 문항 **동일 레이아웃**(틀린 문항만 키우거나 배경 강조하지 않음). 맞고 틀림은
/// 아이콘(check/cancel)+텍스트("정답"/"오답")로만 식별 — 색에만 의존하지 않고
/// 빨강도 쓰지 않는다(오답=코랄, 정답=틸).
class QuizReviewTile extends StatelessWidget {
  final int index; // 1부터
  final QuizAnswerSnapshot answer;

  const QuizReviewTile({super.key, required this.index, required this.answer});

  @override
  Widget build(BuildContext context) {
    final correct = answer.isCorrect;
    final color = correct ? QuizTheme.correct : QuizTheme.incorrect;
    final icon = correct ? Icons.check_circle : Icons.cancel;
    final label = correct ? '정답' : '오답';

    return Semantics(
      label: '$index번 $label. ${answer.statement}',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: QuizTheme.surface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: QuizTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 번호 + 정오(아이콘+텍스트)
            Row(
              children: [
                Text('$index',
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: QuizTheme.textSecondary)),
                SizedBox(width: 8.w),
                Icon(icon, size: 18.sp, color: color),
                SizedBox(width: 4.w),
                Text(label,
                    style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: color)),
                const Spacer(),
                // 내 답 vs 정답 칩
                _answerChip('내 답', answer.chosen, isMine: true, correct: correct),
                SizedBox(width: 6.w),
                _answerChip('정답', answer.answer, isMine: false, correct: true),
              ],
            ),
            SizedBox(height: 10.h),
            Text(answer.statement,
                style: TextStyle(
                    fontSize: 14.sp,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: QuizTheme.textPrimary)),
            SizedBox(height: 8.h),
            Text(answer.explain,
                style: TextStyle(
                    fontSize: 12.5.sp,
                    height: 1.4,
                    color: QuizTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  /// 'O'/'X' 작은 칩. [isMine] 내 답이면 정오에 따라 색, 정답 칩은 항상 틸.
  Widget _answerChip(String tag, String value,
      {required bool isMine, required bool correct}) {
    final chipColor = isMine
        ? (correct ? QuizTheme.correct : QuizTheme.incorrect)
        : QuizTheme.correct;
    final display = value.isEmpty ? '-' : value;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: chipColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$tag $display',
        style: TextStyle(
            fontSize: 11.sp, fontWeight: FontWeight.w700, color: chipColor),
      ),
    );
  }
}
