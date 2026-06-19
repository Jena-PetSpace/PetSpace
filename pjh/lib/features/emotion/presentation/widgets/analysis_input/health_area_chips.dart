import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../shared/themes/app_theme.dart';

class HealthAreaChips extends StatelessWidget {
  static const List<String> healthAreas = [
    '종합(전체)', '눈·귀', '코·입', '피부·털', '체형(BCS)', '자세·체형 대칭',
  ];

  final String selectedArea;
  final void Function(String area) onSelected;

  const HealthAreaChips({
    super.key,
    required this.selectedArea,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '분석 부위 선택',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.secondaryTextColor,
          ),
        ),
        SizedBox(height: 10.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: healthAreas.map((area) {
            final isOn = selectedArea == area;
            return GestureDetector(
              onTap: () => onSelected(area),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isOn ? AppTheme.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: isOn ? AppTheme.primaryColor : AppTheme.neutral300,
                  ),
                ),
                child: Text(
                  area,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: isOn ? FontWeight.w600 : FontWeight.w400,
                    color: isOn ? Colors.white : AppTheme.primaryTextColor,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
