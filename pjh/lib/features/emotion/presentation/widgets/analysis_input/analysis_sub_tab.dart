import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../shared/themes/app_theme.dart';

class AnalysisSubTab extends StatelessWidget {
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int index) onSelected;

  const AnalysisSubTab({
    super.key,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: 11.h),
          decoration: BoxDecoration(
            color: isOn ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(26.r),
            boxShadow: isOn
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: isOn ? FontWeight.w700 : FontWeight.w500,
              color: isOn ? Colors.white : AppTheme.secondaryTextColor,
            ),
          ),
        ),
      ),
    );
  }
}
