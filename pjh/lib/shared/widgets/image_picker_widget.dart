import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../themes/app_theme.dart';
import 'image_source_picker.dart';

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

  Future<void> _showImagePickerOptions(BuildContext context) async {
    try {
      if (allowMultiple) {
        final pickedFiles = await ImageSourcePicker.pickMultiple(
          context,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );

        if (pickedFiles != null && pickedFiles.isNotEmpty) {
          final files = pickedFiles
              .take(maxImages)
              .map((xFile) => File(xFile.path))
              .toList();
          onImagesSelected(files);
        }
      } else {
        final pickedFile = await ImageSourcePicker.pickSingle(
          context,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          onImagesSelected([File(pickedFile.path)]);
        }
      }
    } catch (e) {
      developer.log('Error picking image: $e',
          name: 'ImagePickerWidget', error: e);
    }
  }
}
