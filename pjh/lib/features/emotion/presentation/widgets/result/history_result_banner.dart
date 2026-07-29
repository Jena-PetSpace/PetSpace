import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../shared/themes/app_theme.dart';

class HistoryResultBanner extends StatelessWidget {
  final String label;
  final String? petName;

  const HistoryResultBanner({super.key, required this.label, this.petName});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, 기록에서 열었어요',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.history_rounded,
              size: 20.sp,
              color: AppTheme.primaryColor,
            ),
            SizedBox(width: 9.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    [
                      if (petName != null && petName!.trim().isNotEmpty)
                        petName!.trim(),
                      '기록에서 열었어요',
                    ].join(' · '),
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
      ),
    );
  }
}
