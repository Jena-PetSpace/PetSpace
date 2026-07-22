import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../core/services/profile_service.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../../../shared/widgets/petspace_state_view.dart';
import '../../../../shared/widgets/profile_image_picker.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  static const double _navigationOverlapClearance = 64;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _profileService = di.sl<ProfileService>();

  File? _selectedImage;
  String? _currentImageUrl;
  String _initialName = '';
  String _initialBio = '';
  bool _isInitialLoading = true;
  bool _hasLoadError = false;
  bool _isSaving = false;
  bool _imageUploadFailed = false;
  bool _allowPop = false;
  bool _trackingChanges = true;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _loadCurrentProfile();
  }

  bool get _hasUnsavedChanges =>
      _selectedImage != null ||
      _nameController.text.trim() != _initialName ||
      _bioController.text.trim() != _initialBio;

  void _onFieldChanged() {
    if (!mounted || !_trackingChanges) return;
    setState(() {
      _allowPop = false;
    });
  }

  Future<void> _loadCurrentProfile() async {
    setState(() {
      _isInitialLoading = true;
      _hasLoadError = false;
    });
    try {
      final profile = await _profileService.getProfile();
      if (!mounted) return;
      final name = profile?['display_name'] as String? ?? '';
      final bio = profile?['bio'] as String? ?? '';
      _trackingChanges = false;
      _nameController.text = name;
      _bioController.text = bio;
      _trackingChanges = true;
      setState(() {
        _initialName = name.trim();
        _initialBio = bio.trim();
        _currentImageUrl = profile?['photo_url'] as String?;
        _isInitialLoading = false;
        _imageUploadFailed = false;
        _allowPop = false;
      });
    } catch (_) {
      developer.log('프로필 로드 오류', name: 'ProfileEditPage');
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _hasLoadError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _isSaving) return;
        final discard = await _confirmDiscardChanges();
        if (!discard || !context.mounted) return;
        setState(() => _allowPop = true);
        Navigator.of(context).pop();
      },
      child: PetSpacePageScaffold(
        title: '프로필 편집',
        body: _buildBody(),
        bottomNavigationBar:
            _isInitialLoading || _hasLoadError ? null : _buildSaveBar(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const PetSpaceStateView.loading(key: Key('profile_edit_loading'));
    }
    if (_hasLoadError) {
      return PetSpaceStateView.error(
        key: const Key('profile_edit_error'),
        icon: Icons.cloud_off_outlined,
        title: '프로필을 불러오지 못했어요',
        message: '인터넷 연결을 확인하고 다시 시도해주세요.',
        actionLabel: '다시 시도',
        onAction: _loadCurrentProfile,
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : AppTheme.actionContainer;
    final bodyColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppTheme.secondaryTextColor;

    return SafeArea(
      bottom: false,
      child: Form(
        key: _formKey,
        child: ListView(
          key: const Key('profile_edit_form'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
          children: [
            if (_imageUploadFailed) ...[
              _buildImageFailureBanner(),
              SizedBox(height: 20.h),
            ],
            Text(
              '프로필 사진',
              style: TextStyle(
                fontSize: AppTheme.fontHeading.sp,
                fontWeight: FontWeight.w700,
                color:
                    isDark ? theme.colorScheme.onSurface : AppTheme.brandDeep,
              ),
            ),
            SizedBox(height: 14.h),
            Row(
              children: [
                SizedBox(
                  key: const Key('profile_edit_image_picker'),
                  width: 104.w,
                  height: 104.w,
                  child: Center(
                    child: ProfileImagePicker(
                      imageFile: _selectedImage,
                      imageUrl: _currentImageUrl,
                      radius: 46.r,
                      onImageSelected: () {},
                      onImagePicked: (File image) {
                        setState(() {
                          _selectedImage = image;
                          _imageUploadFailed = false;
                          _allowPop = false;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '사진 변경',
                        style: TextStyle(
                          fontSize: AppTheme.fontBody.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.actionBase,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        '사진 영역을 눌러 카메라나 앨범에서 선택할 수 있어요.',
                        style: TextStyle(
                          fontSize: AppTheme.fontCaption.sp,
                          height: 1.45,
                          color: bodyColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 28.h),
            Text(
              '기본 정보',
              style: TextStyle(
                fontSize: AppTheme.fontHeading.sp,
                fontWeight: FontWeight.w700,
                color:
                    isDark ? theme.colorScheme.onSurface : AppTheme.brandDeep,
              ),
            ),
            SizedBox(height: 14.h),
            TextFormField(
              key: const Key('profile_edit_name_field'),
              controller: _nameController,
              maxLength: 50,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '닉네임 *',
                hintText: '닉네임을 입력하세요',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '닉네임을 입력해주세요';
                }
                if (value.trim().length < 2) {
                  return '닉네임은 2자 이상이어야 합니다';
                }
                return null;
              },
            ),
            SizedBox(height: 14.h),
            TextFormField(
              key: const Key('profile_edit_bio_field'),
              controller: _bioController,
              maxLines: 4,
              maxLength: 150,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: '한 줄 소개',
                hintText: '반려동물과 나를 소개해보세요',
                prefixIcon: Icon(Icons.edit_note_outlined),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value != null && value.length > 150) {
                  return '소개는 150자 이내로 입력해주세요';
                }
                return null;
              },
            ),
            SizedBox(height: 18.h),
            Container(
              key: const Key('profile_edit_public_notice'),
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.actionBase,
                    size: 20.w,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      '이름, 소개, 프로필 사진은 다른 사용자에게 공개될 수 있어요.',
                      style: TextStyle(
                        fontSize: AppTheme.fontCaption.sp,
                        height: 1.45,
                        color: bodyColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageFailureBanner() {
    final theme = Theme.of(context);
    return Container(
      key: const Key('profile_edit_image_failure'),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            color: AppTheme.warningColor,
            size: 22.w,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '기본 정보는 저장됐어요',
                  style: TextStyle(
                    fontSize: AppTheme.fontBody.sp,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '프로필 사진만 업로드하지 못했습니다. 선택한 사진을 유지하고 있어요.',
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    height: 1.45,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 8.h),
                TextButton.icon(
                  key: const Key('profile_edit_image_retry'),
                  onPressed: _isSaving ? null : _retryProfileImage,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('사진만 다시 저장'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: isDark ? theme.colorScheme.surface : AppTheme.surfaceColor,
      elevation: 8,
      child: SafeArea(
        key: const Key('profile_edit_save_safe_area'),
        top: false,
        minimum: EdgeInsets.fromLTRB(
          20.w,
          12.h,
          20.w,
          _navigationOverlapClearance.h,
        ),
        child: SizedBox(
          height: 52.h,
          child: ElevatedButton(
            key: const Key('profile_edit_save_button'),
            onPressed: _isSaving ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.actionBase,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.actionBase.withValues(
                alpha: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
              ),
            ),
            child: _isSaving
                ? SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    '변경사항 저장',
                    style: TextStyle(
                      fontSize: AppTheme.fontBody.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final displayName = _nameController.text.trim();
    final bio = _bioController.text.trim();

    try {
      await _profileService.updateProfile(displayName: displayName, bio: bio);
      developer.log('프로필 텍스트 저장 완료', name: 'ProfileEditPage');
    } catch (e) {
      developer.log('프로필 텍스트 저장 오류', name: 'ProfileEditPage');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_userFacingError(e, '프로필 저장')),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    var imageFailed = false;
    if (_selectedImage != null) {
      try {
        await _profileService.updateProfileImage(_selectedImage!);
        developer.log('프로필 이미지 업로드 완료', name: 'ProfileEditPage');
      } catch (_) {
        developer.log('프로필 이미지 업로드 실패', name: 'ProfileEditPage');
        imageFailed = true;
      }
    }

    if (!mounted) return;
    context.read<AuthBloc>().add(AuthProfileRefreshRequested());
    if (imageFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필은 저장됐지만 이미지 업로드에 실패했습니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: AppTheme.warningColor,
          duration: Duration(seconds: 3),
        ),
      );
      setState(() {
        _initialName = displayName;
        _initialBio = bio;
        _imageUploadFailed = true;
        _isSaving = false;
      });
      return;
    }

    setState(() {
      _initialName = displayName;
      _initialBio = bio;
      _selectedImage = null;
      _allowPop = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('프로필이 저장되었습니다'),
        backgroundColor: AppTheme.successColor,
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.pop(context, true);
  }

  Future<void> _retryProfileImage() async {
    final image = _selectedImage;
    if (_isSaving || image == null) return;
    setState(() => _isSaving = true);
    try {
      await _profileService.updateProfileImage(image);
      if (!mounted) return;
      context.read<AuthBloc>().add(AuthProfileRefreshRequested());
      setState(() {
        _selectedImage = null;
        _imageUploadFailed = false;
        _isSaving = false;
        _allowPop = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필 사진이 저장되었습니다'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      developer.log('프로필 이미지 재업로드 실패', name: 'ProfileEditPage');
      if (!mounted) return;
      setState(() {
        _imageUploadFailed = true;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_userFacingError(e, '프로필 사진 저장')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    final hasOnlyPendingImage = _selectedImage != null &&
        _nameController.text.trim() == _initialName &&
        _bioController.text.trim() == _initialBio;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            key: const Key('profile_edit_discard_dialog'),
            title: Text(
              hasOnlyPendingImage ? '사진 저장을 중단할까요?' : '변경사항을 저장하지 않을까요?',
            ),
            content: Text(
              hasOnlyPendingImage
                  ? '선택한 프로필 사진이 아직 업로드되지 않았어요. 이 화면을 나가면 선택한 사진이 사라집니다.'
                  : '이 화면에서 나가면 아직 저장하지 않은 내용이 사라집니다.',
            ),
            actions: [
              TextButton(
                key: const Key('profile_edit_keep_editing'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('계속 편집'),
              ),
              TextButton(
                key: const Key('profile_edit_discard'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  '나가기',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _userFacingError(Object e, String operation) {
    final msg = e.toString().toLowerCase();
    final isNetwork = msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('clientexception') ||
        msg.contains('connection') ||
        msg.contains('network') ||
        msg.contains('timeout');
    if (isNetwork) {
      return '인터넷 연결을 확인해주세요.\n네트워크 상태를 확인하고 다시 시도해주세요.';
    }
    return '$operation에 실패했습니다. 잠시 후 다시 시도해주세요.';
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _bioController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
