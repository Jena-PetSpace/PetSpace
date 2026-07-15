import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../themes/app_theme.dart';

/// 설정 계열 화면의 섹션 카드.
/// 선택적 라벨/설명과 구분선으로 나뉜 child 목록을 surface 카드로 감싼다.
class PetSpaceSettingsSection extends StatelessWidget {
  final String? title;
  final String? description;
  final List<Widget> children;

  const PetSpaceSettingsSection({
    super.key,
    this.title,
    this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    // 다크모드는 Theme의 surface/text/경계를 우선하고,
    // 라이트모드는 기존 PetSpace v2 시각값을 유지한다.
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color labelColor =
        isDark ? theme.colorScheme.onSurfaceVariant : AppTheme.textMuted;
    final Color cardSurface =
        isDark ? theme.colorScheme.surface : AppTheme.surfaceColor;
    final Color edgeColor =
        isDark ? theme.colorScheme.outlineVariant : AppTheme.border;
    final Color rowDivider =
        isDark ? theme.colorScheme.outlineVariant : AppTheme.dividerColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: AppTheme.fontMicro.sp,
                fontWeight: FontWeight.w700,
                color: labelColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
        if (description != null)
          Padding(
            padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
            child: Text(
              description!,
              style: TextStyle(
                fontSize: AppTheme.fontCaption.sp,
                color: labelColor,
                height: 1.4,
              ),
            ),
          ),
        Material(
          color: cardSurface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
            side: BorderSide(color: edgeColor, width: 1),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    indent: 20.w,
                    color: rowDivider,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 설정 목록의 행. 44px 이상 터치 영역과 하나로 묶인 semantics를 보장한다.
class PetSpaceSettingsTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool enabled;

  const PetSpaceSettingsTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // 다크모드는 Theme의 text/경계를 우선하고,
    // 라이트모드 시각값과 brand/action/error 의미 토큰은 유지한다.
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color bodyColor =
        isDark ? theme.colorScheme.onSurface : AppTheme.primaryTextColor;
    final Color mutedColor =
        isDark ? theme.colorScheme.onSurfaceVariant : AppTheme.textMuted;
    final Color disabledContent = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
        : AppTheme.disabledColor;
    final Color chevronColor =
        isDark ? theme.colorScheme.onSurfaceVariant : AppTheme.lightTextColor;
    final Color disabledIconBg =
        isDark ? theme.colorScheme.outlineVariant : AppTheme.dividerColor;

    final Color contentColor = !enabled
        ? disabledContent
        : destructive
            ? AppTheme.errorColor
            : bodyColor;
    final Widget? effectiveTrailing = trailing ??
        (onTap != null && !destructive
            ? Icon(Icons.chevron_right_rounded, color: chevronColor, size: 20.w)
            : null);

    return MergeSemantics(
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: !enabled
                          ? disabledIconBg
                          : destructive
                              ? AppTheme.errorColor.withValues(alpha: 0.10)
                              : AppTheme.actionContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
                    ),
                    child: Icon(
                      icon,
                      size: 18.w,
                      color: !enabled
                          ? disabledContent
                          : destructive
                              ? AppTheme.errorColor
                              : AppTheme.actionBase,
                    ),
                  ),
                  SizedBox(width: 14.w),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: AppTheme.fontBody.sp,
                          fontWeight: FontWeight.w500,
                          color: contentColor,
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: AppTheme.fontCaption.sp,
                            color: !enabled ? disabledContent : mutedColor,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (effectiveTrailing != null) ...[
                  SizedBox(width: 8.w),
                  effectiveTrailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
