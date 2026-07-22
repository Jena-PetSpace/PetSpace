import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_app_bar.dart';
import '../../../../shared/widgets/image_source_picker.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../config/injection_container.dart' as di;

class OnboardingProfileSetupPage extends StatefulWidget {
  const OnboardingProfileSetupPage({super.key});

  @override
  State<OnboardingProfileSetupPage> createState() =>
      _OnboardingProfileSetupPageState();
}

class _OnboardingProfileSetupPageState
    extends State<OnboardingProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _profileService = di.sl<ProfileService>();

  String? _avatarUrl;
  File? _selectedImageFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: PetSpaceAppBar.steps(
        title: '프로필 설정',
        step: 2,
        totalSteps: 3,
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/onboarding/login');
          }
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildAvatarSection(),
                  const SizedBox(height: 32),
                  _buildFormFields(),
                  const SizedBox(height: 24),
                  _buildContinueButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '어떻게 불러드릴까요?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '커뮤니티에서 사용할 이름과 사진만 먼저 설정해주세요.',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.neutral600,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Semantics(
        label: '프로필 사진 선택',
        button: true,
        child: GestureDetector(
          onTap: _pickProfileImage,
          child: Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: _selectedImageFile != null
                    ? ClipOval(
                        child: Image.file(
                          _selectedImageFile!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      )
                    : _avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              _avatarUrl!,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildAvatarPlaceholder();
                              },
                            ),
                          )
                        : _buildAvatarPlaceholder(),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  padding: const EdgeInsets.all(7),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    // 원형(120px) 안에 텍스트를 넣으면 곡면 가장자리/카메라 배지와 겹쳐 잘리므로
    // 아이콘만 중앙 배치한다. '사진 추가' 의도는 우하단 카메라 배지로 전달.
    return const Center(
      child: Icon(
        Icons.add_a_photo,
        size: 40,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        TextFormField(
          controller: _displayNameController,
          decoration: const InputDecoration(
            labelText: '닉네임 *',
            hintText: '사용하실 닉네임을 입력해주세요',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person, color: AppTheme.secondaryTextColor),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '닉네임을 입력해주세요';
            }
            if (value.trim().length < 2) {
              return '닉네임은 최소 2자 이상이어야 합니다';
            }
            if (value.trim().length > 20) {
              return '닉네임은 최대 20자까지 가능합니다';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.actionContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.accentColor),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '닉네임과 프로필 사진은 다른 사용자에게 공개됩니다. 이메일과 로그인 정보는 공개되지 않아요.',
                  style: TextStyle(
                    color: AppTheme.secondaryColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _continue,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                '다음',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      final image = await ImageSourcePicker.pickSingle(context);

      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
          _avatarUrl = null; // 기존 URL 제거
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지를 선택하지 못했어요. 다시 시도해주세요.')),
        );
      }
    }
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? uploadedImageUrl;

      // 이미지가 선택되었으면 업로드
      if (_selectedImageFile != null) {
        uploadedImageUrl =
            await _profileService.updateProfileImage(_selectedImageFile!);
      }

      // 프로필 정보 저장
      final displayName = _displayNameController.text.trim();
      // 사진이 없으면 빈 문자열로 기존 카카오/구글 사진 제거
      final finalPhotoUrl = uploadedImageUrl ?? _avatarUrl ?? '';
      await _profileService.updateProfile(
        displayName: displayName,
        photoUrl: finalPhotoUrl,
      );

      if (mounted) {
        context.go('/onboarding/pet-registration');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필을 저장하지 못했어요. 입력 내용은 유지되니 다시 시도해주세요.'),
            backgroundColor: AppTheme.errorColor,
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
}
