import 'package:flutter/material.dart';
import '../../../../shared/themes/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 감정분석 결과 페이지에 노출하는 면책(Disclaimer) 배너.
///
/// App Store 심사관 우려: AI 가 의료/심리 진단처럼 보이지 않도록 명시.
/// Google Play UGC 정책: 잘못된 의료 정보로 오인되지 않도록 안내.
///
/// 한국 동물보호법 / 수의사법: 수의학적 진단은 수의사만 가능 → 본 결과는 참고용임을 명시.
class EmotionDisclaimerBanner extends StatelessWidget {
  const EmotionDisclaimerBanner({
    super.key,
    this.compact = false,
  });

  /// `true` 면 간결한 한 줄 형태로 표시 (피드 카드, 작은 영역용).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: AppTheme.neutral500.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                size: 14.sp, color: AppTheme.neutral600),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                '본 분석은 참고용이며 수의학적 진단을 대체하지 않습니다.',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppTheme.neutral700,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWarm, // v2-review: FFF8E1 근사
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.warningColor, width: 1), // v2-review: FFD54F 근사
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 20.sp, color: AppTheme.warningColor), // v2-review: B7791F 근사
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '참고용 결과 안내',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textBody, // v2-review: 7A4500 근사
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '본 분석은 AI 가 사진을 기반으로 추정한 결과로, 수의학적 진단을 '
                  '대체하지 않습니다. 반려동물의 건강에 대한 의사결정은 반드시 '
                  '수의사 등 전문가와 상의해주세요.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textBody, // v2-review: 7A4500 근사
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
