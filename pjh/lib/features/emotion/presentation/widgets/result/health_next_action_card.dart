import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theme/emotion_result_tokens.dart';
import '../../../../../shared/themes/app_theme.dart';

/// 건강 결과 페이지의 "다음에 해볼 것" 카드.
/// - 슬롯 1: 감정 분석 해보기 (네이비, 항상 표시)
/// - 슬롯 2: 다른 부위도 분석하기 (그린, `showOtherArea=true` 일 때만 표시)
///   - 부분 분석(area != overall) 케이스에서 다음 행동 유도
///   - 종합 분석(area == overall)에서는 슬롯 자체 hide → 카드 안에 2개 액션만
/// - 슬롯 3: 이 순간 기록하기 (그레이, 항상 표시)
class HealthNextActionCard extends StatelessWidget {
  final VoidCallback onEmotionAnalysis;
  final VoidCallback onOtherArea;
  final VoidCallback onMemo;

  /// false면 "다른 부위도 분석하기" 슬롯이 숨겨진다.
  /// 종합(overall) 분석을 이미 한 경우 false로 두는 게 자연스럽다.
  final bool showOtherArea;

  const HealthNextActionCard({
    super.key,
    required this.onEmotionAnalysis,
    required this.onOtherArea,
    required this.onMemo,
    this.showOtherArea = true,
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
            label: '감정 분석도 해보기',
            hint: '오늘의 마음 상태도 함께 살펴봐요',
            onTap: onEmotionAnalysis,
          ),
          if (showOtherArea)
            _buildItem(
              icon: Icons.dashboard_customize_outlined,
              bgColor: EmotionResultTokens.greenLight,
              iconColor: EmotionResultTokens.green,
              label: '다른 부위도 분석하기',
              hint: '눈·귀, 피부·털 등 다른 부위도 점검해요',
              onTap: onOtherArea,
            ),
          _buildItem(
            icon: Icons.edit_outlined,
            bgColor: AppTheme.tilePastelSand,
            iconColor: EmotionResultTokens.grayDark,
            label: '이 순간 기록하기',
            hint: '한 줄 메모로 남겨두세요',
            onTap: onMemo,
          ),
        ],
      ),
    );
  }
}
