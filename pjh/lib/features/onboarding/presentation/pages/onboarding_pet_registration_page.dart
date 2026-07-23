import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../core/services/image_upload_service.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/image_source_picker.dart';
import '../../../../shared/widgets/petspace_bottom_action_bar.dart';
import '../../../../shared/widgets/petspace_app_bar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../pets/domain/entities/pet.dart' as pets;
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_event.dart';
import '../../../pets/presentation/bloc/pet_state.dart';

/// 첫 반려동물은 이름·종류만으로 시작할 수 있는 최소 등록 단계다.
class OnboardingPetRegistrationPage extends StatefulWidget {
  const OnboardingPetRegistrationPage({super.key});

  @override
  State<OnboardingPetRegistrationPage> createState() =>
      _OnboardingPetRegistrationPageState();
}

class _OnboardingPetRegistrationPageState
    extends State<OnboardingPetRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  pets.PetType? _selectedType;
  DateTime? _birthDate;
  File? _selectedImageFile;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<PetBloc>(),
      child: Builder(builder: _buildPage),
    );
  }

  Widget _buildPage(BuildContext pageContext) {
    final theme = Theme.of(pageContext);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PetSpaceAppBar.steps(
        title: '반려동물 등록',
        step: 3,
        totalSteps: 3,
        backgroundColor: theme.scaffoldBackgroundColor,
        onBack: () {
          if (_isSaving) return;
          if (pageContext.canPop()) {
            pageContext.pop();
          } else {
            pageContext.go('/onboarding/profile');
          }
        },
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const ValueKey('skip-first-pet'),
                          onPressed:
                              _isSaving ? null : () => _skip(pageContext),
                          child: const Text('나중에'),
                        ),
                      ),
                      _buildHeader(),
                      SizedBox(height: 28.h),
                      _buildPetPhoto(),
                      SizedBox(height: 28.h),
                      TextFormField(
                        key: const ValueKey('first-pet-name'),
                        controller: _nameController,
                        enabled: !_isSaving,
                        maxLength: 50,
                        decoration: const InputDecoration(
                          labelText: '이름',
                          hintText: '예: 보리',
                          helperText: '필수',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? '이름을 입력해주세요.'
                                : null,
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        '종류',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: AppTheme.fontBody.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTypeOption(
                              type: pets.PetType.dog,
                              label: '강아지',
                              icon: Icons.pets_outlined,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildTypeOption(
                              type: pets.PetType.cat,
                              label: '고양이',
                              icon: Icons.cruelty_free_outlined,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        '생년월일',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: AppTheme.fontBody.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _buildBirthDate(),
                      SizedBox(height: 12.h),
                      Text(
                        '품종, 성별, 중성화 여부 같은 자세한 정보는 MY에서 나중에 추가할 수 있어요.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: AppTheme.fontCaption.sp,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PetSpaceBottomActionBar(
              key: const Key('first_pet_bottom_action'),
              minimum: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 12.h),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const ValueKey('save-first-pet'),
                  onPressed: _isSaving ? null : () => _savePet(pageContext),
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('PetSpace 시작하기'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '가장 먼저 누구를 기록할까요?',
          style: TextStyle(
            color: isDark ? theme.colorScheme.onSurface : AppTheme.brandDeep,
            fontSize: AppTheme.fontTitle.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          '이름과 종류만 등록해도 시작할 수 있어요. 자세한 정보는 나중에 추가할 수 있습니다.',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: AppTheme.fontBody.sp,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPetPhoto() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? theme.colorScheme.primary : AppTheme.actionBase;
    return Center(
      child: Semantics(
        label: '반려동물 사진 선택',
        button: true,
        child: InkWell(
          onTap: _isSaving ? null : _pickPetPhoto,
          borderRadius: BorderRadius.circular(48.r),
          child: Container(
            width: 96.w,
            height: 96.w,
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerHighest
                  : AppTheme.actionContainer,
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    isDark ? theme.colorScheme.outlineVariant : AppTheme.border,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _selectedImageFile == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: accent,
                        size: 26.w,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '사진 추가',
                        style: TextStyle(
                          color: accent,
                          fontSize: AppTheme.fontMicro.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Image.file(_selectedImageFile!, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption({
    required pets.PetType type,
    required String label,
    required IconData icon,
  }) {
    final selected = _selectedType == type;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? theme.colorScheme.primary : AppTheme.actionBase;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? (isDark
                ? theme.colorScheme.primaryContainer
                : AppTheme.actionContainer)
            : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
          side: BorderSide(
            color: selected
                ? accent
                : (isDark ? theme.colorScheme.outlineVariant : AppTheme.border),
          ),
        ),
        child: InkWell(
          key: ValueKey('first-pet-type-${type.name}'),
          onTap: _isSaving ? null : () => setState(() => _selectedType = type),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: selected
                      ? (isDark
                          ? theme.colorScheme.onPrimaryContainer
                          : AppTheme.brandDeep)
                      : theme.colorScheme.onSurfaceVariant,
                  size: 26.w,
                ),
                SizedBox(height: 6.h),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? (isDark
                            ? theme.colorScheme.onPrimaryContainer
                            : AppTheme.brandDeep)
                        : theme.colorScheme.onSurface,
                    fontSize: AppTheme.fontBody.sp,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBirthDate() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
        side: BorderSide(
          color: isDark ? theme.colorScheme.outlineVariant : AppTheme.border,
        ),
      ),
      child: InkWell(
        key: const ValueKey('first-pet-birth-date'),
        onTap: _isSaving ? null : _selectBirthDate,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 20.w,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    _birthDate == null
                        ? '날짜 선택 (선택)'
                        : '${_birthDate!.year}.${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: _birthDate == null
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                      fontSize: AppTheme.fontBody.sp,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20.w,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickPetPhoto() async {
    try {
      final image = await ImageSourcePicker.pickSingle(
        context,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        setState(() => _selectedImageFile = File(image.path));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진을 선택하지 못했어요. 다시 시도해주세요.')),
        );
      }
    }
  }

  Future<void> _selectBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  Future<void> _savePet(BuildContext pageContext) async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (_selectedType == null) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('강아지 또는 고양이를 선택해주세요.')),
      );
      return;
    }
    if (!valid) return;

    final authState = pageContext.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('로그인 상태를 확인한 뒤 다시 시도해주세요.')),
      );
      return;
    }
    final petBloc = pageContext.read<PetBloc>();

    setState(() => _isSaving = true);
    try {
      String? avatarUrl;
      if (_selectedImageFile != null) {
        avatarUrl = await di.sl<ImageUploadService>().uploadPetAvatar(
              _selectedImageFile!,
              DateTime.now().millisecondsSinceEpoch.toString(),
            );
      }

      final pet = pets.Pet(
        id: '',
        userId: authState.user.id,
        name: _nameController.text.trim(),
        type: _selectedType!,
        birthDate: _birthDate,
        avatarUrl: avatarUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = petBloc.stream
          .firstWhere(
            (state) => state is PetOperationSuccess || state is PetError,
          )
          .timeout(const Duration(seconds: 10));
      petBloc.add(AddPetEvent(pet));

      final state = await result;
      if (!mounted) return;
      if (state is PetOperationSuccess) {
        context.go('/onboarding/tutorial');
      } else {
        _showSaveFailure(context);
      }
    } catch (_) {
      if (mounted) _showSaveFailure(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSaveFailure(BuildContext pageContext) {
    ScaffoldMessenger.of(pageContext).showSnackBar(
      const SnackBar(
        content: Text('반려동물을 등록하지 못했어요. 입력 내용은 유지되니 다시 시도해주세요.'),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  void _skip(BuildContext pageContext) {
    pageContext.go('/onboarding/tutorial');
  }
}
