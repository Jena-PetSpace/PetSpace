import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/emotion_analysis.dart';
import '../../theme/emotion_result_tokens.dart';

/// 수의사 상담 권장 카드 (조건부).
/// - 노출 조건: stressLevel >= 80  OR  (anxiety + sadness + fear + discomfort) >= 0.6
/// - 코랄 톤 (즉시 행동 키)
/// - "병원 찾기" 버튼 → KakaoMap 라우팅. 미구현시 SnackBar
class VetConsultCard extends StatelessWidget {
  final EmotionAnalysis analysis;
  final VoidCallback onFindVet;

  const VetConsultCard({
    super.key,
    required this.analysis,
    required this.onFindVet,
  });

  /// 외부에서 노출 여부 판별용. page 통합부에서 if (VetConsultCard.shouldShow(analysis)) ... 형태로 사용.
  static bool shouldShow(EmotionAnalysis analysis) {
    final e = analysis.emotions;
    final negSum = e.anxiety + e.sadness + e.fear + e.discomfort;
    return e.stressLevel >= 80 || negSum >= 0.6;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: EmotionResultTokens.coralLight,
        borderRadius: BorderRadius.circular(EmotionResultTokens.radiusCard.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36.r,
            height: 36.r,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: EmotionResultTokens.cardSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.medical_services_outlined,
              size: 20.r,
              color: EmotionResultTokens.coral,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      size: 12.r,
                      color: EmotionResultTokens.coral,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '수의사 상담 권장',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: EmotionResultTokens.coral,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  '지속되는 스트레스 신호가 감지됐어요.\n수의사와 상담해보시는 게 좋아요.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: EmotionResultTokens.textPrimary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: onFindVet,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: EmotionResultTokens.coral,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                '가까운 병원 찾기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
