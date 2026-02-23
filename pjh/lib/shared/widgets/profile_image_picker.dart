import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

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
    return showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.blue),
                  title: const Text('카메라로 촬영'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.green),
                  title: const Text('갤러리에서 선택'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (imageFile != null || imageUrl != null)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('사진 삭제'),
                    onTap: () {
                      Navigator.pop(context);
                      _removeImage();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.cancel, color: Colors.grey),
                  title: const Text('취소'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        onImagePicked(File(image.path));
        onImageSelected();
      }
    } catch (e) {
      debugPrint('이미지 선택 오류: $e');
    }
  }

  void _removeImage() {
    // 이미지 삭제는 부모 위젯에서 처리
    onImageSelected();
  }
}
