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
    {'emoji': '\uD83D\uDCF0', 'label': '매거진'},
    {'emoji': '\uD83D\uDCAC', 'label': '커뮤니티'},
    {'emoji': '\uD83C\uDFE5', 'label': '건강'},
    {'emoji': '\uD83C\uDFAF', 'label': '훈련'},
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46.h,
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
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  border: isSelected
                      ? null
                      : Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Text(
                  '${cat['emoji']} ${cat['label']}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
