import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../themes/app_theme.dart';

/// 홈 화면 섹션 공통 헤더
/// 제목(14sp Bold) + 더보기(11sp accentColor) 우측 고정
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  final String moreLabel;

  const SectionHeader({
    super.key,
    required this.title,
    this.onMore,
    this.moreLabel = '더보기',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? theme.colorScheme.onSurface
                    : AppTheme.primaryTextColor,
              ),
            ),
          ),
          if (onMore != null)
            TextButton(
              onPressed: onMore,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.only(left: 12.w),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    moreLabel,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.actionBase,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16.w,
                    color: AppTheme.actionBase,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
