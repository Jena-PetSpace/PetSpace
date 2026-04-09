import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../themes/app_theme.dart';

/// 네트워크 끊김 시 화면 상단에 표시되는 배너
class NetworkErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;
  final bool isRetrying;

  const NetworkErrorBanner({
    super.key,
    required this.onRetry,
    this.isRetrying = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF0F0),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 18.w, color: AppTheme.errorColor),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              '인터넷 연결이 끊겼습니다',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: isRetrying ? null : onRetry,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                isRetrying ? '연결 중...' : '재시도',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 네트워크 에러 전체 화면 (데이터가 아예 없을 때)
class NetworkErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;

  const NetworkErrorScreen({
    super.key,
    required this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: const BoxDecoration(
                color: AppTheme.subtleBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 40.w,
                color: AppTheme.secondaryTextColor,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              '인터넷 연결을 확인해주세요',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              message ?? '네트워크 연결 후 다시 시도해주세요',
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.secondaryTextColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded, size: 18.w),
              label: Text(
                '다시 시도',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
