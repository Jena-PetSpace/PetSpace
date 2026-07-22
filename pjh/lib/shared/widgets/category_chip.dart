import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../themes/app_theme.dart';

/// 카테고리 선택 칩 — 피드·커뮤니티·홈 이슈 콘텐츠 공용.
///
/// 비선택 = 뉴트럴(보더 + 회색 텍스트), 선택 = 연한 액션 배경.
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? theme.colorScheme.outlineVariant : AppTheme.border;
    final unselectedText = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppTheme.secondaryTextColor;

    return Semantics(
      label: label,
      button: true,
      selected: selected,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22.r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: selected
                    ? (isDark
                        ? theme.colorScheme.primaryContainer
                        : AppTheme.actionContainer)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(
                  color: selected ? AppTheme.actionBase : borderColor,
                  width: 1,
                ),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? (isDark
                          ? theme.colorScheme.onPrimaryContainer
                          : AppTheme.brandDeep)
                      : unselectedText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
