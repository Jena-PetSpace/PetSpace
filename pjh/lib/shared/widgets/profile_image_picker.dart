import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'image_source_picker.dart';

/// 프로필 이미지 선택 위젯
/// 카메라 또는 갤러리에서 이미지를 선택할 수 있습니다.
class ProfileImagePicker extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  final VoidCallback onImageSelected;
  final Function(File) onImagePicked;
  final double radius;

  const ProfileImagePicker({
    super.key,
    this.imageFile,
    this.imageUrl,
    required this.onImageSelected,
    required this.onImagePicked,
    this.radius = 50,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showImageSourceDialog(context),
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey[300],
            backgroundImage: _getImageProvider(),
            child: _getImageProvider() == null
                ? Icon(Icons.person, size: radius, color: Colors.grey[600])
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2.w,
                ),
              ),
              padding: EdgeInsets.all(8.w),
              child: Icon(
                Icons.camera_alt,
                size: 20.w,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _getImageProvider() {
    if (imageFile != null) {
      return FileImage(imageFile!);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      return NetworkImage(imageUrl!);
    }
    return null;
  }

  Future<void> _showImageSourceDialog(BuildContext context) async {
    try {
      final image = await ImageSourcePicker.pickSingle(context);

      if (image != null) {
        onImagePicked(File(image.path));
        onImageSelected();
      }
    } catch (e) {
      developer.log('이미지 선택 오류: $e', name: 'ProfileImagePicker', error: e);
    }
  }
}
