import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/error/failures.dart';
import '../themes/app_theme.dart';

/// 에러 다이얼로그 위젯
///
/// Failure 객체를 받아서 사용자 친화적인 에러 다이얼로그를 표시합니다.
class ErrorDialog extends StatelessWidget {
  final Failure failure;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const ErrorDialog({
    super.key,
    required this.failure,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 에러 아이콘
            _buildErrorIcon(),
            SizedBox(height: 16.h),

            // 에러 제목
            Text(
              _getTitle(),
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),

            // 에러 메시지
            Text(
              failure.message,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),

            // 액션 버튼들
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorIcon() {
    IconData icon;
    Color color;

    if (failure is NetworkFailure) {
      icon = Icons.wifi_off;
      color = Colors.orange;
    } else if (failure is UnauthorizedFailure || failure is AuthFailure) {
      icon = Icons.lock_outline;
      color = Colors.red;
    } else if (failure is NotFoundFailure) {
      icon = Icons.search_off;
      color = Colors.grey;
    } else if (failure is ValidationFailure) {
      icon = Icons.warning_amber;
      color = Colors.amber;
    } else if (failure is TimeoutFailure) {
      icon = Icons.timer_off;
      color = Colors.orange;
    } else {
      icon = Icons.error_outline;
      color = Colors.red;
    }

    return Container(
      width: 80.w,
      height: 80.w,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 40.w,
        color: color,
      ),
    );
  }

  String _getTitle() {
    if (failure is NetworkFailure) {
      return '네트워크 연결 오류';
    } else if (failure is UnauthorizedFailure) {
      return '권한 오류';
    } else if (failure is AuthFailure) {
      return '인증 오류';
    } else if (failure is NotFoundFailure) {
      return '정보를 찾을 수 없음';
    } else if (failure is ValidationFailure) {
      return '입력 오류';
    } else if (failure is TimeoutFailure) {
      return '시간 초과';
    } else if (failure is DatabaseFailure) {
      return '데이터베이스 오류';
    } else if (failure is ServerFailure) {
      return '서버 오류';
    } else {
      return '오류 발생';
    }
  }

  Widget _buildActions(BuildContext context) {
    final showRetry = onRetry != null &&
        (failure is NetworkFailure ||
            failure is TimeoutFailure ||
            failure is ServerFailure);

    if (showRetry) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDismiss?.call();
              },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              child: Text('닫기', style: TextStyle(fontSize: 14.sp)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              child: Text('다시 시도', style: TextStyle(fontSize: 14.sp)),
            ),
          ),
        ],
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDismiss?.call();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 12.h),
          ),
          child: Text('확인', style: TextStyle(fontSize: 14.sp)),
        ),
      );
    }
  }
}

/// 에러 바텀시트 (덜 침습적인 에러 표시)
class ErrorBottomSheet extends StatelessWidget {
  final Failure failure;
  final VoidCallback? onRetry;

  const ErrorBottomSheet({
    super.key,
    required this.failure,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 20.h),

          // 에러 메시지
          Row(
            children: [
              Icon(
                _getIcon(),
                color: _getColor(),
                size: 24.w,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  failure.message,
                  style: TextStyle(
                    fontSize: 16.sp,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          if (onRetry != null) ...[
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                child: Text('다시 시도', style: TextStyle(fontSize: 14.sp)),
              ),
            ),
          ],

          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  IconData _getIcon() {
    if (failure is NetworkFailure) return Icons.wifi_off;
    if (failure is ValidationFailure) return Icons.warning_amber;
    if (failure is TimeoutFailure) return Icons.timer_off;
    return Icons.error_outline;
  }

  Color _getColor() {
    if (failure is NetworkFailure) return Colors.orange;
    if (failure is ValidationFailure) return Colors.amber;
    if (failure is TimeoutFailure) return Colors.orange;
    return Colors.red;
  }
}

/// 에러 표시 헬퍼 함수들
class ErrorDialogHelper {
  /// 에러 다이얼로그 표시
  static Future<void> show(
    BuildContext context,
    Failure failure, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ErrorDialog(
        failure: failure,
        onRetry: onRetry,
        onDismiss: onDismiss,
      ),
    );
  }

  /// 에러 바텀시트 표시 (덜 침습적)
  static Future<void> showBottomSheet(
    BuildContext context,
    Failure failure, {
    VoidCallback? onRetry,
  }) {
    return showModalBottomSheet(
      context: context,
      builder: (context) => ErrorBottomSheet(
        failure: failure,
        onRetry: onRetry,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  /// 에러 스낵바 표시 (가장 덜 침습적)
  static void showSnackBar(
    BuildContext context,
    Failure failure, {
    VoidCallback? onRetry,
  }) {
    final color = _getSnackBarColor(failure);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getSnackBarIcon(failure),
              color: Colors.white,
              size: 20.w,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                failure.message,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: '재시도',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  static Color _getSnackBarColor(Failure failure) {
    if (failure is NetworkFailure || failure is TimeoutFailure) {
      return Colors.orange;
    } else if (failure is ValidationFailure) {
      return Colors.amber[700]!;
    } else {
      return Colors.red;
    }
  }

  static IconData _getSnackBarIcon(Failure failure) {
    if (failure is NetworkFailure) return Icons.wifi_off;
    if (failure is ValidationFailure) return Icons.warning_amber;
    if (failure is TimeoutFailure) return Icons.timer_off;
    return Icons.error_outline;
  }
}
