import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../themes/app_theme.dart';

class HapticFeedbackButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final HapticFeedbackType feedbackType;

  const HapticFeedbackButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style,
    this.feedbackType = HapticFeedbackType.lightImpact,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed != null
          ? () {
              _provideFeedback(feedbackType);
              onPressed!();
            }
          : null,
      style: style,
      child: child,
    );
  }

  void _provideFeedback(HapticFeedbackType type) {
    switch (type) {
      case HapticFeedbackType.lightImpact:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.mediumImpact:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavyImpact:
        HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.selectionClick:
        HapticFeedback.selectionClick();
        break;
    }
  }
}

enum HapticFeedbackType {
  lightImpact,
  mediumImpact,
  heavyImpact,
  selectionClick,
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Color? backgroundColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: backgroundColor ?? Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  if (message != null) ...[
                    SizedBox(height: 16.h),
                    Text(
                      message!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class CustomSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? action,
    String? actionLabel,
  }) {
    final colors = _getColors(type);
    final icon = _getIcon(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20.w),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
              ),
            ),
          ],
        ),
        backgroundColor: colors.backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        action: action != null && actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: action,
              )
            : null,
      ),
    );
  }

  static _SnackBarColors _getColors(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return _SnackBarColors(Colors.green, Colors.white);
      case SnackBarType.error:
        return _SnackBarColors(Colors.red, Colors.white);
      case SnackBarType.warning:
        return _SnackBarColors(Colors.orange, Colors.white);
      case SnackBarType.info:
        return _SnackBarColors(Colors.blue, Colors.white);
    }
  }

  static IconData _getIcon(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return Icons.check_circle;
      case SnackBarType.error:
        return Icons.error;
      case SnackBarType.warning:
        return Icons.warning;
      case SnackBarType.info:
        return Icons.info;
    }
  }
}

class _SnackBarColors {
  final Color backgroundColor;
  final Color textColor;

  _SnackBarColors(this.backgroundColor, this.textColor);
}

enum SnackBarType { success, error, warning, info }

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Color? confirmColor;
  final IconData? icon;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = '확인',
    this.cancelText = '취소',
    this.onConfirm,
    this.onCancel,
    this.confirmColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: confirmColor ?? AppTheme.primaryColor, size: 24.w),
            SizedBox(width: 12.w),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18.sp,
              ),
            ),
          ),
        ],
      ),
      content: Text(content, style: TextStyle(fontSize: 14.sp)),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCancel?.call();
          },
          child: Text(
            cancelText,
            style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm?.call();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor ?? AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          child: Text(confirmText, style: TextStyle(fontSize: 14.sp)),
        ),
      ],
    );
  }

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '확인',
    String cancelText = '취소',
    Color? confirmColor,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        icon: icon,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 80.w,
              color: iconColor ?? Colors.grey[400],
            ),
            SizedBox(height: 24.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: 8.h),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: 24.h),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatusIndicator extends StatelessWidget {
  final StatusType status;
  final String text;
  final double size;

  const StatusIndicator({
    super.key,
    required this.status,
    required this.text,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getStatusColors(status);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size.w,
          height: size.w,
          decoration: BoxDecoration(
            color: colors.backgroundColor,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          text,
          style: TextStyle(
            color: colors.textColor,
            fontSize: (size + 2).sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  _StatusColors _getStatusColors(StatusType status) {
    switch (status) {
      case StatusType.online:
        return _StatusColors(Colors.green, Colors.green);
      case StatusType.offline:
        return _StatusColors(Colors.grey, Colors.grey);
      case StatusType.away:
        return _StatusColors(Colors.yellow, Colors.orange);
      case StatusType.busy:
        return _StatusColors(Colors.red, Colors.red);
    }
  }
}

class _StatusColors {
  final Color backgroundColor;
  final Color textColor;

  _StatusColors(this.backgroundColor, this.textColor);
}

enum StatusType { online, offline, away, busy }

class ProgressSteps extends StatelessWidget {
  final List<String> steps;
  final int currentStep;
  final Color? activeColor;
  final Color? inactiveColor;

  const ProgressSteps({
    super.key,
    required this.steps,
    required this.currentStep,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? AppTheme.primaryColor;
    final inactive = inactiveColor ?? Colors.grey[300]!;

    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    color: i <= currentStep ? active : inactive,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: i < currentStep
                        ? Icon(Icons.check, color: Colors.white, size: 18.w)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i == currentStep ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  steps[i],
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: i <= currentStep ? active : inactive,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (i < steps.length - 1)
            Expanded(
              child: Container(
                height: 2.h,
                color: i < currentStep ? active : inactive,
              ),
            ),
        ],
      ],
    );
  }
}