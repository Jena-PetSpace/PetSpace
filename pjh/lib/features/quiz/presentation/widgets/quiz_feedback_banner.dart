import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/quiz_theme.dart';

/// 채점 후 정오 + 한 줄 해설 배너.
///
/// 접근성: **색에만 의존 금지**. 아이콘(check/close) + "정답"/"오답" 텍스트를
/// 항상 함께 노출하고 Semantics 로 묶어 스크린리더에 한 번에 읽힌다.
/// 색은 보조 단서일 뿐(정답=틸, 오답=코랄, 빨강 미사용).
class QuizFeedbackBanner extends StatelessWidget {
  final bool isCorrect;
  final String explain;

  const QuizFeedbackBanner({
    super.key,
    required this.isCorrect,
    required this.explain,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? QuizTheme.correct : QuizTheme.incorrect;
    final icon = isCorrect ? Icons.check_circle : Icons.cancel;
    final label = isCorrect ? '정답' : '오답';

    return Semantics(
      liveRegion: true, // 등장 시 스크린리더가 즉시 읽음
      label: '$label. $explain',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20.sp, color: color),
                SizedBox(width: 6.w),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              explain,
              style: TextStyle(
                fontSize: 14.sp,
                height: 1.45,
                color: QuizTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
