import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/permission_helper.dart';

class ImageSourcePicker {
  /// Shows a BottomSheet to select camera or gallery, then picks image(s)
  /// Returns null if cancelled
  static Future<XFile?> pickSingle(
    BuildContext context, {
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    final source = await _showSourceSheet(context);
    if (source == null) return null;

    if (!context.mounted) return null;
    final granted = await _ensurePermission(context, source);
    if (!granted) return null;

    final picker = ImagePicker();
    return picker.pickImage(
      source: source,
      maxWidth: maxWidth ?? 1024,
      maxHeight: maxHeight ?? 1024,
      imageQuality: imageQuality ?? 85,
    );
  }

  /// Pick multiple images from gallery (with camera option for single)
  static Future<List<XFile>?> pickMultiple(
    BuildContext context, {
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
  }) async {
    final source = await _showSourceSheet(context);
    if (source == null) return null;

    if (!context.mounted) return null;
    final granted = await _ensurePermission(context, source);
    if (!granted) return null;

    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth ?? 1920,
        maxHeight: maxHeight ?? 1920,
        imageQuality: imageQuality ?? 85,
      );
      return file != null ? [file] : null;
    }

    final files = await picker.pickMultiImage(
      maxWidth: maxWidth ?? 1920,
      maxHeight: maxHeight ?? 1920,
      imageQuality: imageQuality ?? 85,
      limit: limit,
    );
    return files.isNotEmpty ? files : null;
  }

  /// 카메라/사진 권한을 사전 체크. 영구 거부 시 시스템 설정 진입 BottomSheet 노출.
  static Future<bool> _ensurePermission(
    BuildContext context,
    ImageSource source,
  ) async {
    if (source == ImageSource.camera) {
      return PermissionHelper.ensureGranted(
        context,
        permission: Permission.camera,
        permissionName: '카메라',
        reason: '반려동물 사진을 촬영하려면 카메라 권한이 필요합니다.',
      );
    }
    // gallery
    return PermissionHelper.ensureGranted(
      context,
      permission: Permission.photos,
      permissionName: '사진',
      reason: '갤러리에서 사진을 가져오려면 사진 접근 권한이 필요합니다.',
    );
  }

  static Future<ImageSource?> _showSourceSheet(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 8.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 8.h),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('카메라로 촬영하기', style: TextStyle(fontSize: 15.sp)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: Text('갤러리에서 선택하기', style: TextStyle(fontSize: 15.sp)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}
