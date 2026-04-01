import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../themes/app_theme.dart';

/// 프리미엄 전용 콘텐츠 잠금 위젯
/// 비구독 유저에게 블러 + 잠금 오버레이 표시
class PremiumGateWidget extends StatelessWidget {
  final Widget child;
  final String title;
  final String desc;
  final VoidCallback? onUnlock;

  const PremiumGateWidget({
    super.key,
    required this.child,
    this.title = '프리미엄 기능',
    this.desc = '더 자세한 분석 결과를 확인하려면\n프리미엄을 이용해보세요',
    this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 블러 처리된 콘텐츠
        ImageFiltered(
          imageFilter: ColorFilter.mode(
            Colors.white.withValues(alpha: 0.85),
            BlendMode.srcOver,
          ),
          child: child,
        ),

        // 잠금 오버레이
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 26.w,
                    color: AppTheme.primaryColor,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppTheme.secondaryTextColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 14.h),
                GestureDetector(
                  onTap: onUnlock ?? () => _showPremiumSheet(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.accentColor],
                      ),
                      borderRadius: BorderRadius.circular(22.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('⭐', style: TextStyle(fontSize: 14.sp)),
                        SizedBox(width: 6.w),
                        Text(
                          '프리미엄 해제하기',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPremiumSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: EdgeInsets.all(16.w),
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⭐', style: TextStyle(fontSize: 48.sp)),
            SizedBox(height: 12.h),
            Text('PetSpace 프리미엄',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
            SizedBox(height: 8.h),
            Text('반려동물의 감정을 더 깊이 이해하세요',
              style: TextStyle(fontSize: 13.sp, color: AppTheme.secondaryTextColor)),
            SizedBox(height: 20.h),
            ...[ 
              ('📊', '상세 감정 분포 차트'),
              ('🐾', '멀티펫 비교 분석'),
              ('🌍', '커뮤니티 벤치마크'),
              ('📈', '감정 안정성 지수'),
              ('📅', '주간 감정 리포트'),
            ].map((item) => Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(children: [
                Text(item.$1, style: TextStyle(fontSize: 18.sp)),
                SizedBox(width: 12.w),
                Text(item.$2, style: TextStyle(fontSize: 13.sp, color: AppTheme.primaryTextColor)),
                const Spacer(),
                Icon(Icons.check_circle, size: 18.w, color: AppTheme.successColor),
              ]),
            )),
            SizedBox(height: 16.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.accentColor]),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(children: [
                Text('월 3,900원', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('7일 무료 체험 후 결제', style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.8))),
              ]),
            ),
            SizedBox(height: 10.h),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('나중에', style: TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor)),
            ),
          ],
        ),
      ),
    );
  }
}
