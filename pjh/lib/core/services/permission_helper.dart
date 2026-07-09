import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../shared/themes/app_theme.dart';

/// 권한 요청 / 거부 시 폴백 UX 공통 헬퍼.
///
/// - 권한이 `permanentlyDenied` 또는 (Android) `denied` 상태에서 재요청이 막힌 경우
///   사용자에게 시스템 설정으로 안내하는 BottomSheet를 띄운다.
/// - 알림(Notification), 카메라(Camera), 사진(Photos / Storage) 등 공통 사용.
class PermissionHelper {
  PermissionHelper._();

  /// 알림 권한 상태 확인.
  /// iOS: `Permission.notification`, Android 13+: `POST_NOTIFICATIONS`
  static Future<bool> isNotificationGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted || status.isProvisional;
  }

  /// 알림 권한 요청. 이미 허용 시 즉시 true 반환.
  /// permanentlyDenied 면 false 반환 — 호출 측에서 BottomSheet 안내 필요.
  static Future<bool> requestNotification() async {
    final status = await Permission.notification.status;
    if (status.isGranted || status.isProvisional) return true;
    if (status.isPermanentlyDenied) return false;

    final result = await Permission.notification.request();
    return result.isGranted || result.isProvisional;
  }

  /// 카메라 권한 요청.
  static Future<PermissionStatus> requestCamera() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return status;
    return await Permission.camera.request();
  }

  /// 사진 권한 요청.
  /// iOS: `Permission.photos`, Android 13+: `READ_MEDIA_IMAGES`, Android 12-: `READ_EXTERNAL_STORAGE`
  static Future<PermissionStatus> requestPhotos() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      if (status.isGranted || status.isLimited) return status;
      return await Permission.photos.request();
    }
    // Android
    final status = await Permission.photos.status;
    if (status.isGranted || status.isLimited) return status;
    final requested = await Permission.photos.request();
    if (requested.isGranted || requested.isLimited) return requested;
    // Android 12 이하 폴백: 외부 저장소
    final storage = await Permission.storage.status;
    if (storage.isGranted) return storage;
    return await Permission.storage.request();
  }

  /// 위치 권한 요청 (when in use).
  static Future<PermissionStatus> requestLocationWhenInUse() async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) return status;
    return await Permission.locationWhenInUse.request();
  }

  /// 권한 거부(특히 영구 거부) 시 사용자에게 시스템 설정 진입을 유도하는 BottomSheet.
  ///
  /// [permissionName] : "알림", "카메라", "사진" 등 사용자에게 보여줄 권한 이름
  /// [reason]         : 왜 필요한지 한 줄 설명
  static Future<void> showSettingsBottomSheet(
    BuildContext context, {
    required String permissionName,
    required String reason,
  }) async {
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Icon(Icons.lock_outline,
                    size: 48.sp, color: AppTheme.primaryColor),
                SizedBox(height: 12.h),
                Text(
                  '$permissionName 권한이 꺼져 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '설정 → 펫페이스 → $permissionName 을 켜주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                  ),
                ),
                SizedBox(height: 20.h),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.actionBase,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await openAppSettings();
                  },
                  child: Text(
                    '설정으로 이동',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    '나중에',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 권한 요청 후 거부됐을 때 호출하는 통합 흐름.
  /// 거부 시 [showSettingsBottomSheet] 를 자동 노출하고 false 반환.
  static Future<bool> ensureGranted(
    BuildContext context, {
    required Permission permission,
    required String permissionName,
    required String reason,
  }) async {
    final status = await permission.status;
    if (status.isGranted || status.isLimited || status.isProvisional) {
      return true;
    }
    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await showSettingsBottomSheet(context,
          permissionName: permissionName, reason: reason);
      return false;
    }

    final result = await permission.request();
    if (result.isGranted || result.isLimited || result.isProvisional) {
      return true;
    }
    if (result.isPermanentlyDenied || result.isDenied) {
      if (context.mounted) {
        await showSettingsBottomSheet(context,
            permissionName: permissionName, reason: reason);
      }
      return false;
    }
    return false;
  }
}
