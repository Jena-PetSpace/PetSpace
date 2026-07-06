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

  // 피드 Q&A 항목과 동일한 카테고리 체계 (피그마 매거진 시안 기준)
  static const List<String> _categories = [
    '전체',
    'O/X 퀴즈',
    '케어가이드',
    '교육',
    '정책',
    '이벤트',
  ];

  @override
  Widget build(BuildContext context) {
    // 6개 칩 — 콘텐츠 폭 기반 가로 스크롤 (피그마 시안 레이아웃)
    return SizedBox(
      height: 34.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (_, index) => _buildChip(index),
      ),
    );
  }

  Widget _buildChip(int index) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        widget.onSelected?.call(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // 선택: 브랜드 딥블루 채움 / 비선택: 무채색 채움 (테두리·그림자 없음)
          color: isSelected ? AppTheme.primaryColor : const Color(0xFFEFF1F4),
          borderRadius: BorderRadius.circular(17.r),
        ),
        child: Text(
          _categories[index],
          maxLines: 1,
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
