import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_app_bar.dart';
import '../../../../shared/widgets/image_source_picker.dart';
import '../../../../shared/widgets/info_box.dart';
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 28.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      SizedBox(height: 32.h),
                      _buildAvatarSection(),
                      SizedBox(height: 28.h),
                      _buildFormFields(),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '어떻게 불러드릴까요?',
          style: TextStyle(
            fontSize: AppTheme.fontTitle.sp,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          '커뮤니티에서 사용할 이름과 사진만 먼저 설정해주세요.',
          style: TextStyle(
            fontSize: AppTheme.fontBody.sp,
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? theme.colorScheme.primary : AppTheme.actionBase;
    return Center(
      child: Column(
        children: [
          Semantics(
            label: '프로필 사진 선택',
            button: true,
            enabled: !_isLoading,
            child: InkWell(
              key: const Key('onboarding_profile_photo'),
              onTap: _isLoading ? null : _pickProfileImage,
              customBorder: const CircleBorder(),
              child: Stack(
                children: [
                  Container(
                    width: 104.w,
                    height: 104.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? theme.colorScheme.surfaceContainerHighest
                          : AppTheme.actionContainer,
                      border: Border.all(
                        color: isDark
                            ? theme.colorScheme.outlineVariant
                            : AppTheme.border,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _selectedImageFile != null
                        ? Image.file(_selectedImageFile!, fit: BoxFit.cover)
                        : _avatarUrl != null
                            ? Image.network(
                                _avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildAvatarPlaceholder(accent),
                              )
                            : _buildAvatarPlaceholder(accent),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 36.w,
                      height: 36.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 18.w,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            '프로필 사진 · 선택',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: AppTheme.fontCaption.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(Color accent) {
    return Center(
      child: Icon(Icons.person_outline_rounded, size: 40.w, color: accent),
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('onboarding_profile_name'),
          controller: _displayNameController,
          enabled: !_isLoading,
          textInputAction: TextInputAction.done,
          maxLength: 20,
          decoration: const InputDecoration(
            labelText: '닉네임 *',
            hintText: '예: 보리 보호자',
            helperText: '필수 · 2~20자',
            prefixIcon: Icon(Icons.person_outline_rounded),
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
        SizedBox(height: 20.h),
        const InfoBox(
          title: '공개 정보 안내',
          items: [
            '닉네임과 프로필 사진은 다른 사용자에게 공개됩니다.',
            '이메일과 로그인 정보는 공개되지 않아요.',
          ],
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      key: const Key('onboarding_profile_bottom_action'),
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 12.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? theme.colorScheme.outlineVariant : AppTheme.border,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          key: const Key('onboarding_profile_continue'),
          onPressed: _isLoading ? null : _continue,
          child: _isLoading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('다음'),
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
