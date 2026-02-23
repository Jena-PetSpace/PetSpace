import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ScreenUtil Extension 사용법
///
/// 1. 너비 (Width): 100.w - 화면 너비에 비례
/// 2. 높이 (Height): 100.h - 화면 높이에 비례
/// 3. 폰트 크기 (Font): 16.sp - 텍스트 크기 자동 조절
/// 4. 반지름 (Radius): 8.r - 둥근 모서리에 사용
///
/// 예시:
/// ```dart
/// Container(
///   width: 100.w,
///   height: 50.h,
///   padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
///   decoration: BoxDecoration(
///     borderRadius: BorderRadius.circular(8.r),
///   ),
///   child: Text(
///     '안녕하세요',
///     style: TextStyle(fontSize: 16.sp),
///   ),
/// )
/// ```

/// 공통으로 사용되는 반응형 값들
class AppSizes {
  // Padding & Margin
  static double get paddingXS => 4.w;
  static double get paddingS => 8.w;
  static double get paddingM => 16.w;
  static double get paddingL => 24.w;
  static double get paddingXL => 32.w;

  // Font Sizes
  static double get fontXS => 10.sp;
  static double get fontS => 12.sp;
  static double get fontM => 14.sp;
  static double get fontL => 16.sp;
  static double get fontXL => 18.sp;
  static double get fontXXL => 24.sp;
  static double get fontTitle => 32.sp;

  // Icon Sizes
  static double get iconS => 16.w;
  static double get iconM => 24.w;
  static double get iconL => 32.w;
  static double get iconXL => 48.w;

  // Border Radius
  static double get radiusS => 4.r;
  static double get radiusM => 8.r;
  static double get radiusL => 12.r;
  static double get radiusXL => 16.r;
  static double get radiusXXL => 24.r;
  static double get radiusCircle => 100.r;

  // Button Heights
  static double get buttonHeightS => 36.h;
  static double get buttonHeightM => 48.h;
  static double get buttonHeightL => 56.h;

  // Avatar Sizes
  static double get avatarS => 32.w;
  static double get avatarM => 48.w;
  static double get avatarL => 64.w;
  static double get avatarXL => 100.w;

  // Card
  static double get cardElevation => 2.w;

  // AppBar
  static double get appBarHeight => 56.h;

  // Bottom Navigation
  static double get bottomNavHeight => 60.h;
}
