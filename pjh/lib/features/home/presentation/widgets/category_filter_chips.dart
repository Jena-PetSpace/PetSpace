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
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _categories = [
    {'emoji': '\uD83D\uDD25', 'label': '인기'},
    {'emoji': '\uD83D\uDCAC', 'label': '커뮤니티'},
    {'emoji': '\uD83C\uDFE5', 'label': '건강'},
    {'emoji': '\uD83C\uDFAF', 'label': '훈련'},
    {'emoji': '\uD83D\uDCF0', 'label': '매거진'},
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50.h,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        thickness: 2.5,
        radius: Radius.circular(2.r),
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 8.h),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => SizedBox(width: 8.w),
          itemBuilder: (context, index) {
            final isSelected = _selectedIndex == index;
            final cat = _categories[index];

            return GestureDetector(
              onTap: () {
                setState(() => _selectedIndex = index);
                widget.onSelected?.call(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
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
                  '${cat['emoji']} ${cat['label']}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.secondaryTextColor,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
