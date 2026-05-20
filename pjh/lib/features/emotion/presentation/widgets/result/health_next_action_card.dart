import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theme/emotion_result_tokens.dart';

/// 건강 결과 페이지의 "다음에 해볼 것" 카드.
/// - 3액션: 감정 분석 해보기 (네이비) / 한 달 뒤 재검사 (그린) / 기록 남기기 (그레이)
/// - 모든 콜백 외부 주입
class HealthNextActionCard extends StatelessWidget {
  final VoidCallback onEmotionAnalysis;
  final VoidCallback onMonthlyRecheck;
  final VoidCallback onMemo;

  const HealthNextActionCard({
    super.key,
    required this.onEmotionAnalysis,
    required this.onMonthlyRecheck,
    required this.onMemo,
  });

  Widget _buildItem({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required String label,
    required String hint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 10.h),
        child: Row(
          children: [
            Container(
              width: 32.r,
              height: 32.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18.r, color: iconColor),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: EmotionResultTokens.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: EmotionResultTokens.grayText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20.r,
              color: EmotionResultTokens.grayText,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: EmotionResultTokens.cardSurface,
        borderRadius: BorderRadius.circular(EmotionResultTokens.radiusCard.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // TODO(copy): HealthNextActionCard 헤더
            '다음에 해볼 것',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: EmotionResultTokens.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          _buildItem(
            icon: Icons.psychology_outlined,
            bgColor: EmotionResultTokens.navyLight,
            iconColor: EmotionResultTokens.navy,
            // TODO(copy): 감정 분석 액션 라벨/힌트
            label: '감정 분석도 해보기',
            hint: '오늘 컨디션의 마음 상태도 확인해요',
            onTap: onEmotionAnalysis,
          ),
          _buildItem(
            icon: Icons.event_repeat,
            bgColor: EmotionResultTokens.greenLight,
            iconColor: EmotionResultTokens.green,
            // TODO(copy): 한 달 뒤 재검사 라벨/힌트
            label: '한 달 뒤 재검사',
            hint: '정기적인 관찰이 큰 변화를 막아요',
            onTap: onMonthlyRecheck,
          ),
          _buildItem(
            icon: Icons.edit_outlined,
            bgColor: const Color(0xFFF1EFE8),
            iconColor: EmotionResultTokens.grayDark,
            // TODO(copy): 기록 남기기 라벨/힌트
            label: '이 순간 기록하기',
            hint: '한 줄 메모로 남겨두세요',
            onTap: onMemo,
          ),
        ],
      ),
    );
  }
}
