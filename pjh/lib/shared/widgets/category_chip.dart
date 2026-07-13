import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../themes/app_theme.dart';

/// 카테고리 선택 칩 — 피드 라운지·홈 이슈 콘텐츠 공용.
///
/// 비선택 = 뉴트럴(보더 + 회색 텍스트), 선택 = 단일 브랜드 블루 채움.
/// 카테고리별 컬러·아이콘 배리에이션 금지 (색이 아닌 상태가 의미를 갖는다).
class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            // 비선택 보더는 border 토큰 (v2: divider는 구분선 전용)
            color: selected ? AppTheme.primaryColor : AppTheme.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppTheme.secondaryTextColor,
          ),
        ),
      ),
    );
  }
}
