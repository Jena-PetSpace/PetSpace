import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theme/emotion_result_tokens.dart';

/// 건강 결과 페이지 AI 안내 (책임 회피용).
/// 앰버 톤. 작은 정보 아이콘 + 한 줄 설명.
class HealthDisclaimerCard extends StatelessWidget {
  const HealthDisclaimerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: EmotionResultTokens.signalAmberLight,
        borderRadius: BorderRadius.circular(EmotionResultTokens.radiusInner.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 14.r,
            color: EmotionResultTokens.signalAmberDark,
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              'AI 분석 결과는 참고용이에요.\n정확한 진단은 수의사 상담을 권장합니다.',
              style: TextStyle(
                fontSize: 11.sp,
                height: 1.4,
                color: EmotionResultTokens.signalAmberDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
