import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../themes/app_theme.dart';
import 'icon_badge_circle.dart' show BadgeTone;

/// 화면마다 제각각이던 '안내' 박스(둥근 컨테이너 + 불릿 목록)를 수렴한 공용 컴포넌트.
///
/// 색 계열은 [tone]으로 맥락에 맞춤(기본 feature). 본문 색·간격·테두리를 1규칙으로.
class InfoBox extends StatelessWidget {
  /// 상단 제목(예: '안내', '비밀번호 안내'). null이면 제목 줄 생략.
  final String? title;

  /// 불릿 항목들.
  final List<String> items;

  /// 박스 색 계열.
  final BadgeTone tone;

  const InfoBox({
    super.key,
    this.title,
    required this.items,
    this.tone = BadgeTone.feature,
  });

  Color get _accent {
    switch (tone) {
      case BadgeTone.neutral:
        return AppTheme.secondaryTextColor;
      case BadgeTone.success:
        return AppTheme.successColor;
      case BadgeTone.feature:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = _accent;
    final bodyColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppTheme.secondaryTextColor;
    final background = isDark
        ? Color.alphaBlend(
            accent.withValues(alpha: 0.10),
            theme.colorScheme.surface,
          )
        : accent.withValues(alpha: 0.07);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18.w, color: accent),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
          ],
          ...items.map(
            (t) => Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 7.h),
                    child: Container(
                      width: 5.w,
                      height: 5.w,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 13.sp,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
