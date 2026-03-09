import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';

class HealthAlertCard extends StatelessWidget {
  const HealthAlertCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.highlightColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.highlightColor.withValues(alpha: 0.3),
        ),
      ),
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active,
            color: AppTheme.highlightColor,
            size: 28.w,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '예방접종 D-37',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.highlightColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '광견병 예방접종 예정일: 2026.04.15',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.secondaryTextColor,
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
