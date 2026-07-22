import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../themes/app_theme.dart';

/// PetSpace v2 공용 페이지 셸.
/// 배경·AppBar 스타일만 통일하며 라우팅이나 비즈니스 상태는 알지 않는다.
class PetSpacePageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;
  final bool centerTitle;

  const PetSpacePageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.leading,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    // 다크모드는 Theme의 surface/text를 우선하고,
    // 라이트모드는 기존 PetSpace v2 시각값을 유지한다.
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color background =
        isDark ? theme.scaffoldBackgroundColor : AppTheme.backgroundColor;
    final Color barSurface =
        isDark ? theme.colorScheme.surface : AppTheme.surfaceColor;
    final Color barContent =
        isDark ? theme.colorScheme.onSurface : AppTheme.primaryTextColor;
    final Color titleColor =
        isDark ? theme.colorScheme.onSurface : AppTheme.brandDeep;

    return Scaffold(
      backgroundColor: background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: AppBar(
        backgroundColor: barSurface,
        elevation: 0,
        centerTitle: centerTitle,
        scrolledUnderElevation: 0,
        surfaceTintColor: barSurface,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leading: leading,
        iconTheme: IconThemeData(color: barContent),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppTheme.fontHeading.sp,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        actions: actions,
      ),
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
