import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';

class EmotionTrendMiniChart extends StatelessWidget {
  const EmotionTrendMiniChart({super.key});

  @override
  Widget build(BuildContext context) {
    // 샘플 데이터 (향후 실제 데이터 연동)
    final weekDays = ['월', '화', '수', '목', '금', '토', '일'];
    final values = [0.6, 0.75, 0.5, 0.8, 0.65, 0.9, 0.7];

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          SizedBox(
            height: 120.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 바
                        Container(
                          height: (values[index] * 80).h,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppTheme.subColor,
                                AppTheme.accentColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        // 요일 라벨
                        Text(
                          weekDays[index],
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
