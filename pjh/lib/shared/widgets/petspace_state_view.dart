import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../themes/app_theme.dart';

enum _PetSpaceStateKind { loading, empty, error }

/// loading / empty / error 상태의 공용 표현.
/// 비즈니스 상태나 라우팅은 알지 않으며, 문구·동작은 호출부가 주입한다.
class PetSpaceStateView extends StatelessWidget {
  final _PetSpaceStateKind _kind;
  final IconData? icon;
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PetSpaceStateView.loading({super.key})
      : _kind = _PetSpaceStateKind.loading,
        icon = null,
        title = null,
        message = null,
        actionLabel = null,
        onAction = null;

  const PetSpaceStateView.empty({
    super.key,
    this.icon,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  }) : _kind = _PetSpaceStateKind.empty;

  const PetSpaceStateView.error({
    super.key,
    this.icon = Icons.error_outline,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  }) : _kind = _PetSpaceStateKind.error;

  bool get _isError => _kind == _PetSpaceStateKind.error;

  @override
  Widget build(BuildContext context) {
    // 다크모드는 Theme의 text를 우선하고,
    // 라이트모드 시각값과 action/error 의미 토큰은 유지한다.
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color titleColor =
        isDark ? theme.colorScheme.onSurface : AppTheme.primaryTextColor;
    final Color messageColor =
        isDark ? theme.colorScheme.onSurfaceVariant : AppTheme.textMuted;

    if (_kind == _PetSpaceStateKind.loading) {
      return Semantics(
        label: '불러오는 중',
        liveRegion: true,
        child: ExcludeSemantics(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
              child: const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.actionBase,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      liveRegion: _isError,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isError && icon != null) ...[
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: _isError
                        ? AppTheme.errorColor.withValues(alpha: 0.08)
                        : (isDark
                            ? theme.colorScheme.primaryContainer
                            : AppTheme.actionContainer),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
                  ),
                  child: Icon(
                    icon,
                    size: 26.w,
                    color: _isError ? AppTheme.errorColor : AppTheme.actionBase,
                  ),
                ),
                SizedBox(height: 16.h),
              ],
              if (title != null) ...[
                Text(
                  title!,
                  style: TextStyle(
                    fontSize: AppTheme.fontHeading.sp,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
              ],
              if (message != null)
                Text(
                  message!,
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    color: messageColor,
                    height: 1.55,
                  ),
                  textAlign: TextAlign.center,
                ),
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: 24.h),
                ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.actionBase,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 44),
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
                    ),
                  ),
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: AppTheme.fontBody.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
