import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../themes/app_theme.dart';

class ImagePickerWidget extends StatelessWidget {
  final Function(List<File>) onImagesSelected;
  final int maxImages;
  final bool allowMultiple;
  final String buttonText;
  final IconData buttonIcon;

  const ImagePickerWidget({
    super.key,
    required this.onImagesSelected,
    this.maxImages = 5,
    this.allowMultiple = true,
    this.buttonText = '이미지 선택',
    this.buttonIcon = Icons.photo_camera,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showImagePickerOptions(context),
      icon: Icon(buttonIcon, size: 20.w),
      label: Text(buttonText, style: TextStyle(fontSize: 14.sp)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      ),
    );
  }

  void _showImagePickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  '이미지 선택',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PickerOption(
                      icon: Icons.photo_camera,
                      label: '카메라',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                    _PickerOption(
                      icon: Icons.photo_library,
                      label: '갤러리',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Request permissions
      final hasPermission = await _requestPermission(source);
      if (!hasPermission) {
        return;
      }

      final picker = ImagePicker();

      if (allowMultiple && source == ImageSource.gallery) {
        final pickedFiles = await picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );

        if (pickedFiles.isNotEmpty) {
          final files = pickedFiles
              .take(maxImages)
              .map((xFile) => File(xFile.path))
              .toList();
          onImagesSelected(files);
        }
      } else {
        final pickedFile = await picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          onImagesSelected([File(pickedFile.path)]);
        }
      }
    } catch (e) {
      // Handle error
      debugPrint('Error picking image: $e');
    }
  }

  Future<bool> _requestPermission(ImageSource source) async {
    Permission permission;

    if (source == ImageSource.camera) {
      permission = Permission.camera;
    } else {
      permission = Permission.photos;
    }

    final status = await permission.request();

    if (status.isDenied) {
      return false;
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    return status.isGranted;
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32.w,
              color: AppTheme.primaryColor,
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}