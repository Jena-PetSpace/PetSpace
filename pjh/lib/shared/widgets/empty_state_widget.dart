import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../themes/app_theme.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  // 확장 파라미터
  final String? emoji;           // 이모지 일러스트 (있으면 icon 대신 사용)
  final String? badgeEmoji;      // 우상단 뱃지 이모지
  final String? secondaryLabel;  // 보조 버튼 레이블
  final VoidCallback? onSecondary;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.emoji,
    this.badgeEmoji,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 일러스트 영역
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 100.w,
                  height: 100.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.08),
                        AppTheme.subColor.withValues(alpha: 0.12),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: emoji != null
                      ? Center(
                          child: Text(emoji!, style: TextStyle(fontSize: 48.sp)),
                        )
                      : Icon(
                          icon,
                          size: 48.w,
                          color: isDark ? AppTheme.subColor : AppTheme.secondaryTextColor,
                        ),
                ),
                if (badgeEmoji != null)
                  Positioned(
                    top: -4.h,
                    right: -4.w,
                    child: Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: AppTheme.highlightColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.highlightColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(badgeEmoji!, style: TextStyle(fontSize: 16.sp)),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 24.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : AppTheme.primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13.sp,
                color: isDark ? Colors.white38 : AppTheme.secondaryTextColor,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            if (secondaryLabel != null || actionLabel != null) ...[
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (secondaryLabel != null && onSecondary != null) ...[
                    OutlinedButton(
                      onPressed: onSecondary,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                      ),
                      child: Text(secondaryLabel!, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(width: 10.w),
                  ],
                  if (actionLabel != null && onAction != null)
                    ElevatedButton(
                      onPressed: onAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(actionLabel!, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
