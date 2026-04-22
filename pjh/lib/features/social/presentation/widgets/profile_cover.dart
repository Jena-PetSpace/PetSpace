import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/themes/app_theme.dart';

class ProfileCover extends StatelessWidget {
  final String? coverImageUrl;
  final bool canEdit;
  final ValueChanged<File>? onImagePicked;

  const ProfileCover({
    super.key,
    this.coverImageUrl,
    this.canEdit = false,
    this.onImagePicked,
  });

  Future<void> _pick(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (file != null) onImagePicked?.call(File(file.path));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 140.h,
          width: double.infinity,
          child: coverImageUrl != null && coverImageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: coverImageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
        if (canEdit)
          Positioned(
            right: 10.w,
            bottom: 10.h,
            child: GestureDetector(
              onTap: () => _pick(context),
              child: Container(
                padding: EdgeInsets.all(7.w),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt, size: 18.w, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.6),
          ],
        ),
      ),
    );
  }
}
