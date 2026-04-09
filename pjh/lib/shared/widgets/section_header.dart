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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryTextColor,
            ),
          ),
          if (onMore != null)
            GestureDetector(
              onTap: onMore,
              child: Padding(
                padding: EdgeInsets.only(left: 8.w),
                child: Text(
                  '$moreLabel >',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
