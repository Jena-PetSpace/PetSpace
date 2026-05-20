import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theme/emotion_result_tokens.dart';

/// 분석 요청 시 사용자가 입력한 추가 맥락을 보여주는 카드.
/// - contextNote가 null/빈 문자열이면 호출 측에서 빌드하지 않음 (page 통합부 가드)
/// - 단순 회색 박스 + 채팅 아이콘 + 라벨 + 따옴표 본문
class ContextCard extends StatelessWidget {
  final String contextNote;

  const ContextCard({super.key, required this.contextNote});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: EmotionResultTokens.cardSurface,
        borderRadius: BorderRadius.circular(EmotionResultTokens.radiusCard.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28.r,
            height: 28.r,
            decoration: BoxDecoration(
              color: EmotionResultTokens.grayBar,
              borderRadius: BorderRadius.circular(8.r),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.chat_bubble_outline,
              size: 16.r,
              color: EmotionResultTokens.grayText,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '입력하신 정보 · AI 분석에 반영됐어요',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: EmotionResultTokens.grayText,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '"$contextNote"',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: EmotionResultTokens.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
