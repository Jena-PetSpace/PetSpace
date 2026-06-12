import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/emotion_analysis.dart';
import '../../theme/emotion_result_tokens.dart';

/// "다음에 해볼 것" 카드.
/// - 3개 액션: 10분 후 재분석 (코랄, 조건부), 건강 분석 (네이비), 기록 남기기 (그레이)
/// - 콜백은 페이지에서 라우팅과 연결
class NextActionCard extends StatelessWidget {
  final EmotionAnalysis analysis;
  final VoidCallback? onReanalyze;       // 10분 후 재분석
  final VoidCallback onHealthCheck;       // 건강 분석
  final VoidCallback onMemo;              // 기록 남기기

  const NextActionCard({
    super.key,
    required this.analysis,
    required this.onHealthCheck,
    required this.onMemo,
    this.onReanalyze,
  });

  /// 재분석 노출 조건: 콜백 연결 + (부정 감정 60% 이상 또는 스트레스 70+)
  bool get _showReanalyze {
    if (onReanalyze == null) return false; // TODO(재분석): prefill 구현 후 콜백 연결 시 자동 복원
    final e = analysis.emotions;
    final negSum = e.anxiety + e.sadness + e.fear + e.discomfort;
    return negSum >= 0.6 || e.stressLevel >= 70;
  }

  Widget _buildHeader() {
    return Text(
      '다음에 해볼 것',
      style: TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w500,
        color: EmotionResultTokens.textPrimary,
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required String label,
    required String hint,
    required VoidCallback? onTap,
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
          _buildHeader(),
          SizedBox(height: 8.h),
          if (_showReanalyze)
            _buildItem(
              icon: Icons.refresh,
              bgColor: EmotionResultTokens.coralLight,
              iconColor: EmotionResultTokens.coral,
              label: '10분 뒤 다시 분석하기',
              hint: '안정된 모습인지 확인해보세요',
              onTap: onReanalyze,
            ),
          _buildItem(
            icon: Icons.medical_services_outlined,
            bgColor: EmotionResultTokens.navyLight,
            iconColor: EmotionResultTokens.navy,
            label: '건강 분석도 해보기',
            hint: '눈·귀·코·입 부위별로 살펴봐요',
            onTap: onHealthCheck,
          ),
          _buildItem(
            icon: Icons.edit_outlined,
            bgColor: const Color(0xFFF1EFE8),
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
