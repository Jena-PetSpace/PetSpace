import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../shared/themes/app_theme.dart';

class GuideTipRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const GuideTipRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, color: color, size: 20.w),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
