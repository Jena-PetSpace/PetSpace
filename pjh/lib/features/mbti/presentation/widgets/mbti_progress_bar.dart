import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/mbti_theme.dart';

/// 상단 진행 표시: "5 / 20" 위치 + 진행 바 + 후반부 격려 문구.
class MbtiProgressBar extends StatelessWidget {
  final int current; // 1-based 현재 문항 번호
  final int total;

  const MbtiProgressBar({
    super.key,
    required this.current,
    required this.total,
  });

  /// 후반부(70% 이상) 진입 시 가벼운 격려. 이탈 감소 목적.
  String? get _encouragement {
    if (total == 0) return null;
    final ratio = current / total;
    if (current >= total) return '마지막 문항이에요! 🎉';
    if (ratio >= 0.7) return '거의 다 왔어요. 조금만 더! 💪';
    if (ratio >= 0.5) return '절반을 넘었어요 👏';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : current / total;
    final encouragement = _encouragement;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '성향 알아보기',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: MbtiTheme.textSecondary,
              ),
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$current',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: MbtiTheme.navy,
                    ),
                  ),
                  TextSpan(
                    text: ' / $total',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: MbtiTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(100.r),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 8.h,
              backgroundColor: MbtiTheme.navy.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(MbtiTheme.navy),
            ),
          ),
        ),
        if (encouragement != null) ...[
          SizedBox(height: 8.h),
          Text(
            encouragement,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: MbtiTheme.coral,
            ),
          ),
        ],
      ],
    );
  }
}
