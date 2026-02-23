import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/error/error_messages.dart';

/// 에러 심각도에 따른 색상과 아이콘 정의
class ErrorSnackbarConfig {
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;
  final Duration duration;

  const ErrorSnackbarConfig({
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.duration,
  });

  static ErrorSnackbarConfig fromSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return const ErrorSnackbarConfig(
          backgroundColor: Color(0xFF2196F3), // Blue
          textColor: Colors.white,
          icon: Icons.info_outline,
          duration: Duration(seconds: 3),
        );
      case ErrorSeverity.warning:
        return const ErrorSnackbarConfig(
          backgroundColor: Color(0xFFFF9800), // Orange
          textColor: Colors.white,
          icon: Icons.warning_amber_outlined,
          duration: Duration(seconds: 4),
        );
      case ErrorSeverity.error:
        return const ErrorSnackbarConfig(
          backgroundColor: Color(0xFFF44336), // Red
          textColor: Colors.white,
          icon: Icons.error_outline,
          duration: Duration(seconds: 5),
        );
      case ErrorSeverity.critical:
        return const ErrorSnackbarConfig(
          backgroundColor: Color(0xFF9C27B0), // Purple (critical)
          textColor: Colors.white,
          icon: Icons.dangerous_outlined,
          duration: Duration(seconds: 8),
        );
    }
  }
}

/// 공통 에러 스낵바 표시 함수
void showErrorSnackbar(
  BuildContext context, {
  required String message,
  ErrorSeverity severity = ErrorSeverity.error,
  String? actionLabel,
  VoidCallback? onAction,
  VoidCallback? onRetry,
}) {
  final config = ErrorSnackbarConfig.fromSeverity(severity);

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(config.icon, color: config.textColor, size: 20.w),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: config.textColor,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: config.backgroundColor,
      duration: config.duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
      ),
      margin: EdgeInsets.all(16.w),
      action: onRetry != null
          ? SnackBarAction(
              label: '재시도',
              textColor: config.textColor,
              onPressed: onRetry,
            )
          : actionLabel != null && onAction != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: config.textColor,
                  onPressed: onAction,
                )
              : null,
    ),
  );
}

/// 성공 메시지 스낵바
void showSuccessSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.white, size: 20.w),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF4CAF50), // Green
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
      ),
      margin: EdgeInsets.all(16.w),
    ),
  );
}

/// ErrorInfo 기반 스낵바 표시
void showErrorInfoSnackbar(
  BuildContext context, {
  required ErrorInfo errorInfo,
  VoidCallback? onRetry,
}) {
  showErrorSnackbar(
    context,
    message: errorInfo.message,
    severity: errorInfo.severity,
    onRetry: errorInfo.canRetry ? onRetry : null,
    actionLabel: errorInfo.suggestedAction,
  );
}
