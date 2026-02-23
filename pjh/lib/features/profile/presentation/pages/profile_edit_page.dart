import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../shared/widgets/profile_image_picker.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../config/injection_container.dart' as di;

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _profileService = di.sl<ProfileService>();

  File? _selectedImage;
  String? _currentImageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    try {
      final profile = await _profileService.getProfile();
      if (profile != null && mounted) {
        setState(() {
          _nameController.text = profile['display_name'] ?? '';
          _bioController.text = profile['bio'] ?? '';
          _currentImageUrl = profile['photo_url'];
        });
      }
    } catch (e) {
      debugPrint('프로필 로드 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 편집'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('저장', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            // 프로필 이미지 선택
            Center(
              child: ProfileImagePicker(
                imageFile: _selectedImage,
                imageUrl: _currentImageUrl,
                radius: 60.r,
                onImageSelected: () {
                  setState(() {
                    // 이미지 변경 감지
                  });
                },
                onImagePicked: (File image) {
                  setState(() {
                    _selectedImage = image;
                  });
                },
              ),
            ),
            SizedBox(height: 8.h),
            Center(
              child: Text(
                '프로필 사진을 변경하려면 탭하세요',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
              ),
            ),
            SizedBox(height: 32.h),

            // 이름 입력
            TextFormField(
              controller: _nameController,
              style: TextStyle(fontSize: 14.sp),
              decoration: InputDecoration(
                labelText: '이름',
                labelStyle: TextStyle(fontSize: 14.sp),
                hintText: '이름을 입력하세요',
                hintStyle: TextStyle(fontSize: 14.sp),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '이름을 입력해주세요';
                }
                if (value.trim().length < 2) {
                  return '이름은 2자 이상이어야 합니다';
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),

            // 소개 입력
            TextFormField(
              controller: _bioController,
              style: TextStyle(fontSize: 14.sp),
              decoration: InputDecoration(
                labelText: '소개',
                labelStyle: TextStyle(fontSize: 14.sp),
                hintText: '자기소개를 입력하세요',
                hintStyle: TextStyle(fontSize: 14.sp),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.edit_note),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: 150,
              validator: (value) {
                if (value != null && value.length > 150) {
                  return '소개는 150자 이내로 입력해주세요';
                }
                return null;
              },
            ),
            SizedBox(height: 24.h),

            // 정보 카드
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24.w),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        '프로필 정보는 다른 사용자에게 공개됩니다.',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? newImageUrl;

      // 이미지가 선택되었으면 업로드
      if (_selectedImage != null) {
        newImageUrl = await _profileService.updateProfileImage(_selectedImage!);
        debugPrint('프로필 이미지 업로드 완료: $newImageUrl');
      }

      // 프로필 정보 저장
      final displayName = _nameController.text.trim();
      final bio = _bioController.text.trim();

      await _profileService.updateProfile(
        displayName: displayName,
        bio: bio,
        photoUrl: newImageUrl, // 새 이미지가 없으면 null (기존 유지)
      );

      debugPrint('프로필 저장 완료 - 이름: $displayName, 소개: $bio');

      // 성공 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필이 저장되었습니다'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true); // true를 반환하여 업데이트 알림
      }
    } catch (e) {
      debugPrint('프로필 저장 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('프로필 저장 실패: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}