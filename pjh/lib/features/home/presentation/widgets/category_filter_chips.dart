import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';

class CategoryFilterChips extends StatefulWidget {
  final ValueChanged<int>? onSelected;

  const CategoryFilterChips({super.key, this.onSelected});

  @override
  State<CategoryFilterChips> createState() => _CategoryFilterChipsState();
}

class _CategoryFilterChipsState extends State<CategoryFilterChips> {
  int _selectedIndex = 0;

  // 피드 Q&A 항목과 동일한 카테고리 체계
  final List<Map<String, String>> _categories = [
    {'emoji': '✨', 'label': '전체'},
    {'emoji': '🏥', 'label': '건강'},
    {'emoji': '🎯', 'label': '훈련'},
    {'emoji': '🍖', 'label': '먹거리'},
    {'emoji': '🏡', 'label': '생활'},
  ];

  @override
  Widget build(BuildContext context) {
    // 5개 칩을 가로 폭에 균등하게 채워 스크롤 없이 한눈에 보이도록 배치
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: List.generate(_categories.length, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == _categories.length - 1 ? 0 : 6.w,
              ),
              child: _buildChip(index),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildChip(int index) {
    final isSelected = _selectedIndex == index;
    final cat = _categories[index];

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        widget.onSelected?.call(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: 9.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.28), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          cat['label']!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.secondaryTextColor,
          ),
        ),
      ),
    );
  }
}
