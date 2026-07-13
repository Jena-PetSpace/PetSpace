import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/constants/community_categories.dart';
import '../../../../shared/widgets/category_chip.dart';

/// 홈 이슈 콘텐츠 필터 칩 — 매거진/케어가이드/교육/정책/이벤트.
///
/// 목록·라벨은 shared 단일 소스(CommunityCategories.issueContents)를 참조하고
/// 선택 결과는 category 값으로 전달한다 (인덱스 결합 금지).
class CategoryFilterChips extends StatefulWidget {
  final ValueChanged<String>? onSelected;

  const CategoryFilterChips({super.key, this.onSelected});

  @override
  State<CategoryFilterChips> createState() => _CategoryFilterChipsState();
}

class _CategoryFilterChipsState extends State<CategoryFilterChips> {
  String _selectedValue = CommunityCategories.issueContents.first.value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: CommunityCategories.issueContents.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (_, index) {
          final category = CommunityCategories.issueContents[index];
          return CategoryChip(
            label: category.label,
            selected: _selectedValue == category.value,
            onTap: () {
              if (_selectedValue == category.value) return;
              setState(() => _selectedValue = category.value);
              widget.onSelected?.call(category.value);
            },
          );
        },
      ),
    );
  }
}
