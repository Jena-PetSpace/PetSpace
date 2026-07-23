import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../core/services/image_upload_service.dart';
import '../../../../shared/constants/pet_constants.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/image_source_picker.dart';
import '../../../../shared/widgets/petspace_bottom_action_bar.dart';
import '../../domain/entities/pet.dart';
import '../bloc/pet_bloc.dart';
import '../bloc/pet_event.dart';
import '../bloc/pet_state.dart';
import '../widgets/pet_editor_form_widgets.dart';

class PetEditorRoutes {
  PetEditorRoutes._();

  static const createName = 'pet-create';
  static const createPath = '/pets/new';
  static const editName = 'pet-edit';
  static const editPath = '/pets/:petId/edit';
}

class PetEditorRouteData {
  const PetEditorRouteData({required this.petBloc, this.pet});

  final PetBloc petBloc;
  final Pet? pet;

  bool matchesEdit({required String? petId, required String userId}) {
    return pet != null && pet!.id == petId && pet!.userId == userId;
  }
}

class PetEditorRouteErrorPage extends StatelessWidget {
  const PetEditorRouteErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pets_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              const Text(
                '반려동물 정보를 열 수 없습니다.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  final navigator = Navigator.of(context);
                  if (navigator.canPop()) {
                    navigator.pop();
                  } else {
                    context.go('/pets');
                  }
                },
                child: const Text('돌아가기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PetEditorPage extends StatefulWidget {
  const PetEditorPage({
    super.key,
    required this.userId,
    this.pet,
    this.imagePicker,
    this.imageUploadService,
    this.selectedImageBuilder,
  });

  final String userId;
  final Pet? pet;
  final Future<File?> Function(BuildContext context)? imagePicker;
  final ImageUploadService? imageUploadService;
  final Widget Function(File imageFile)? selectedImageBuilder;

  @override
  State<PetEditorPage> createState() => _PetEditorPageState();
}

class _PetEditorPageState extends State<PetEditorPage> {
  final _stepOneFormKey = GlobalKey<FormState>();
  final _stepTwoFormKey = GlobalKey<FormState>();
  final _editFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _passportSurnameController = TextEditingController();
  final _passportGivenNameController = TextEditingController();
  final _nameHanguelController = TextEditingController();

  PetType _selectedType = PetType.dog;
  PetGender? _selectedGender;
  DateTime? _selectedBirthDate;
  String? _selectedBreed;
  bool _isCustomBreed = false;
  String? _avatarUrl;
  File? _selectedImageFile;
  String _countryCode = 'KOR';
  int _registrationStep = 0;
  bool _isSubmitting = false;
  bool _resubmitAfterReload = false;
  bool _didComplete = false;
  String? _draftPetId;
  String? _cachedUploadedAvatarUrl;
  String? _cachedUploadedAvatarSourcePath;

  static const List<({String code, String label})> _countryOptions = [
    (code: 'KOR', label: '🇰🇷 대한민국 (KOR)'),
    (code: 'USA', label: '🇺🇸 미국 (USA)'),
    (code: 'JPN', label: '🇯🇵 일본 (JPN)'),
    (code: 'CHN', label: '🇨🇳 중국 (CHN)'),
    (code: 'GBR', label: '🇬🇧 영국 (GBR)'),
    (code: 'DEU', label: '🇩🇪 독일 (DEU)'),
    (code: 'FRA', label: '🇫🇷 프랑스 (FRA)'),
    (code: 'CAN', label: '🇨🇦 캐나다 (CAN)'),
    (code: 'AUS', label: '🇦🇺 호주 (AUS)'),
  ];

  bool get _isEditing => widget.pet != null;

  @override
  void initState() {
    super.initState();
    final pet = widget.pet;
    if (pet != null) _initializeWithPet(pet);
  }

  void _initializeWithPet(Pet pet) {
    _nameController.text = pet.name;
    _descriptionController.text = pet.description ?? '';
    _selectedType = pet.type;
    _selectedGender = pet.gender;
    _selectedBirthDate = pet.birthDate;
    _avatarUrl = pet.avatarUrl;
    _passportSurnameController.text = pet.passportSurname ?? '';
    _passportGivenNameController.text = pet.passportGivenName ?? '';
    _nameHanguelController.text = pet.nameHanguel ?? '';

    final code = pet.countryCode;
    if (code != null && _countryOptions.any((option) => option.code == code)) {
      _countryCode = code;
    }

    final breed = pet.breed;
    if (breed != null && breed.isNotEmpty) {
      final breeds = petBreeds[pet.type] ?? const <String>[];
      if (breeds.contains(breed)) {
        _selectedBreed = breed;
        _isCustomBreed = breed == '기타';
      } else {
        _selectedBreed = '기타';
        _isCustomBreed = true;
        _breedController.text = breed;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _descriptionController.dispose();
    _passportSurnameController.dispose();
    _passportGivenNameController.dispose();
    _nameHanguelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PetBloc, PetState>(
      listener: _onPetStateChanged,
      child: PopScope<Object?>(
        canPop: !_isSubmitting && (_isEditing || _registrationStep == 0),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop &&
              !_isSubmitting &&
              !_isEditing &&
              _registrationStep == 1) {
            setState(() => _registrationStep = 0);
          }
        },
        child: Scaffold(
          key: const Key('pet_editor_page'),
          resizeToAvoidBottomInset: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: _buildAppBar(),
          body: _isEditing
              ? _buildEditBody()
              : _registrationStep == 0
                  ? _buildRegistrationStepOne()
                  : _buildRegistrationStepTwo(),
          bottomNavigationBar: _buildBottomActions(),
        ),
      ),
    );
  }

  void _onPetStateChanged(BuildContext context, PetState state) {
    if (_didComplete) return;

    if (_resubmitAfterReload) {
      if (state is PetLoaded) {
        _resubmitAfterReload = false;
        setState(() => _isSubmitting = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _submit();
        });
      } else if (state is PetError) {
        _resubmitAfterReload = false;
        setState(() => _isSubmitting = false);
        _showMessage('${state.message} 잠시 후 저장을 다시 시도해주세요.');
      }
      return;
    }

    if (!_isSubmitting) return;

    if (state is PetOperationSuccess) {
      _didComplete = true;
      Navigator.of(context).pop(true);
    } else if (state is PetError) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      // PetBloc은 작업 오류 시 PetLoaded 목록 상태를 보존하지 않으므로,
      // 입력 화면은 유지한 채 목록 상태만 다시 준비해 재시도를 가능하게 한다.
      context.read<PetBloc>().add(LoadUserPets());
    }
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headingColor =
        isDark ? theme.colorScheme.onSurface : AppTheme.brandDeep;
    final isSecondStep = !_isEditing && _registrationStep == 1;

    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      leadingWidth: 56,
      leading: IconButton(
        key: Key(isSecondStep
            ? 'pet_editor_previous_button'
            : 'pet_editor_close_button'),
        constraints: const BoxConstraints(
          minWidth: kPetEditorMinTouchTarget,
          minHeight: kPetEditorMinTouchTarget,
        ),
        onPressed: _isSubmitting
            ? null
            : isSecondStep
                ? () => setState(() => _registrationStep = 0)
                : () => Navigator.of(context).maybePop(),
        icon: Icon(isSecondStep ? Icons.arrow_back : Icons.close),
        tooltip: isSecondStep ? '이전 단계' : '닫기',
      ),
      title: Text(
        _isEditing ? '반려동물 정보' : '반려동물 등록',
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: headingColor,
        ),
      ),
    );
  }

  Widget _buildRegistrationStepOne() {
    return Form(
      key: _stepOneFormKey,
      child: _buildScrollableBody(
        key: const Key('pet_editor_step_one'),
        children: [
          _buildProgress(step: 1),
          SizedBox(height: 24.h),
          _buildIntro(
            title: '먼저 꼭 필요한 것만 알려주세요',
            description: '나머지 정보는 다음 화면이나 등록 후에 추가할 수 있어요.',
          ),
          SizedBox(height: 20.h),
          _buildAvatarSection(),
          SizedBox(height: 24.h),
          _buildSection(
            children: [
              _buildNameField(),
              _buildTypeSelector(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationStepTwo() {
    return Form(
      key: _stepTwoFormKey,
      child: _buildScrollableBody(
        key: const Key('pet_editor_step_two'),
        children: [
          _buildProgress(step: 2),
          SizedBox(height: 24.h),
          _buildIntro(
            title: '조금 더 알려주시면 기록이 정확해져요',
            description: '모든 항목은 선택이며 언제든 수정할 수 있어요.',
          ),
          SizedBox(height: 24.h),
          _buildSection(
            children: [
              _buildBreedField(),
              _buildGenderSelector(),
              _buildBirthDateField(),
              _buildDescriptionField(),
            ],
          ),
          SizedBox(height: 24.h),
          _buildPassportNotice(),
        ],
      ),
    );
  }

  Widget _buildEditBody() {
    return Form(
      key: _editFormKey,
      child: _buildScrollableBody(
        key: const Key('pet_editor_edit_body'),
        children: [
          _buildAvatarSection(isEditing: true),
          SizedBox(height: 24.h),
          _buildSection(
            title: '기본 정보',
            children: [
              _buildNameField(),
              _buildTypeSelector(),
              _buildBreedField(),
              _buildBirthDateField(),
              _buildGenderSelector(),
              _buildDescriptionField(),
            ],
          ),
          SizedBox(height: 24.h),
          _buildPassportRow(),
        ],
      ),
    );
  }

  Widget _buildScrollableBody(
      {required Key key, required List<Widget> children}) {
    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        key: key,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 28.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _buildProgress({required int step}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '반려동물 등록 $step단계, 총 2단계',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                step == 1 ? '기본 정보' : '추가 정보',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.actionBase,
                ),
              ),
              const Spacer(),
              Text(
                '$step / 2',
                key: const Key('pet_editor_step_label'),
                style: TextStyle(
                  fontSize: 13.sp,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: step / 2,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation(AppTheme.actionBase),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro({required String title, required String description}) {
    final theme = Theme.of(context);
    final headingColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurface
        : AppTheme.brandDeep;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            height: 1.35,
            color: headingColor,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          description,
          style: TextStyle(
            fontSize: 14.sp,
            height: 1.45,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSection({String? title, required List<Widget> children}) {
    final theme = Theme.of(context);
    final headingColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurface
        : AppTheme.brandDeep;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Text(
            title,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: headingColor,
            ),
          ),
          SizedBox(height: 16.h),
        ],
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) SizedBox(height: 16.h),
          children[index],
        ],
      ],
    );
  }

  Widget _buildAvatarSection({bool isEditing = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasPhoto = _selectedImageFile != null || _avatarUrl != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          color: colorScheme.surfaceContainerHighest,
          shape:
              CircleBorder(side: BorderSide(color: colorScheme.outlineVariant)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('pet_editor_avatar_button'),
            customBorder: const CircleBorder(),
            onTap: _isSubmitting ? null : _pickImage,
            child: SizedBox(
              width: 88,
              height: 88,
              child: _buildAvatarContent(colorScheme),
            ),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isEditing) ...[
                Text(
                  '프로필 사진',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 2.h),
              ],
              TextButton.icon(
                key: const Key('pet_editor_photo_label_button'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  foregroundColor: AppTheme.actionBase,
                  alignment: Alignment.centerLeft,
                ),
                onPressed: _isSubmitting ? null : _pickImage,
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: Text(
                  hasPhoto ? '사진 변경' : '사진 추가',
                  style:
                      TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
              ),
              if (!isEditing)
                Padding(
                  padding: EdgeInsets.only(left: 8.w),
                  child: Text(
                    '선택',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarContent(ColorScheme colorScheme) {
    if (_selectedImageFile != null) {
      final selectedImageBuilder = widget.selectedImageBuilder;
      if (selectedImageBuilder != null) {
        return selectedImageBuilder(_selectedImageFile!);
      }
      return Image.file(_selectedImageFile!, fit: BoxFit.cover);
    }
    if (_avatarUrl != null) {
      return Image.network(
        _avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildAvatarFallback(colorScheme),
      );
    }
    return _buildAvatarFallback(colorScheme);
  }

  Widget _buildAvatarFallback(ColorScheme colorScheme) {
    return Icon(Icons.pets_outlined,
        size: 38, color: colorScheme.onSurfaceVariant);
  }

  Widget _buildNameField() {
    return TextFormField(
      key: const Key('pet_editor_name_field'),
      controller: _nameController,
      maxLength: 50,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        labelText: '이름 *',
        border: petEditorInputBorder,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return '이름을 입력해주세요';
        return null;
      },
    );
  }

  Widget _buildTypeSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '종류 *',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8.h),
        PetEditorSegmentedChoice<PetType>(
          options: const [
            PetEditorSegmentOption(value: PetType.dog, label: '강아지'),
            PetEditorSegmentOption(value: PetType.cat, label: '고양이'),
          ],
          selectedValue: _selectedType,
          onSelected: (value) {
            if (value == _selectedType || _isSubmitting) return;
            setState(() {
              _selectedType = value;
              _selectedBreed = null;
              _isCustomBreed = false;
              _breedController.clear();
            });
          },
        ),
      ],
    );
  }

  Widget _buildBreedField() {
    final breeds = petBreeds[_selectedType] ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(
              'pet_editor_breed_${_selectedType.name}_${_selectedBreed ?? 'none'}'),
          initialValue: _selectedBreed,
          decoration: const InputDecoration(
            labelText: '품종',
            border: petEditorInputBorder,
          ),
          hint: const Text('품종을 선택하세요'),
          items: breeds
              .map(
                  (breed) => DropdownMenuItem(value: breed, child: Text(breed)))
              .toList(),
          onChanged: _isSubmitting
              ? null
              : (value) {
                  setState(() {
                    _selectedBreed = value;
                    _isCustomBreed = value == '기타';
                    if (!_isCustomBreed) _breedController.clear();
                  });
                },
        ),
        if (_isCustomBreed) ...[
          SizedBox(height: 16.h),
          TextFormField(
            key: const Key('pet_editor_custom_breed_field'),
            controller: _breedController,
            decoration: const InputDecoration(
              labelText: '품종 직접 입력',
              hintText: '예: 믹스견, 코숏 등',
              border: petEditorInputBorder,
            ),
            validator: (value) {
              if (_isCustomBreed && (value == null || value.trim().isEmpty)) {
                return '품종을 입력해주세요';
              }
              return null;
            },
          ),
        ],
        if (_selectedBreed != null) ...[
          SizedBox(height: 4.h),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('pet_editor_clear_breed_button'),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: _isSubmitting
                  ? null
                  : () {
                      setState(() {
                        _selectedBreed = null;
                        _isCustomBreed = false;
                        _breedController.clear();
                      });
                    },
              child: const Text('품종 선택 해제'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGenderSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '성별',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8.h),
        PetEditorSegmentedChoice<PetGender>(
          options: const [
            PetEditorSegmentOption(value: PetGender.male, label: '수컷'),
            PetEditorSegmentOption(value: PetGender.female, label: '암컷'),
          ],
          selectedValue: _selectedGender,
          onSelected: (value) {
            if (_isSubmitting) return;
            setState(() => _selectedGender = value);
          },
        ),
        if (_selectedGender != null) ...[
          SizedBox(height: 4.h),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('pet_editor_clear_gender_button'),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: _isSubmitting
                  ? null
                  : () => setState(() => _selectedGender = null),
              child: const Text('성별 선택 해제'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBirthDateField() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const Key('pet_editor_birth_date_field'),
          onTap: _isSubmitting ? null : _selectBirthDate,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(minHeight: kPetEditorMinTouchTarget),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '생년월일',
                border: petEditorInputBorder,
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(
                _selectedBirthDate == null
                    ? '생년월일을 선택해주세요'
                    : '${_selectedBirthDate!.year}.${_selectedBirthDate!.month.toString().padLeft(2, '0')}.${_selectedBirthDate!.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 15.sp,
                  color: _selectedBirthDate == null
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        if (_selectedBirthDate != null) ...[
          SizedBox(height: 4.h),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('pet_editor_clear_birth_date_button'),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: _isSubmitting
                  ? null
                  : () => setState(() => _selectedBirthDate = null),
              child: const Text('생년월일 삭제'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      key: const Key('pet_editor_description_field'),
      controller: _descriptionController,
      minLines: 3,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: '소개',
        alignLabelWithHint: true,
        border: petEditorInputBorder,
      ),
    );
  }

  Widget _buildPassportNotice() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.badge_outlined,
              color: AppTheme.actionBase, size: 22),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              '여권 정보는 등록 완료 후 반려동물 상세에서 만들 수 있어요.',
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.45,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassportRow() {
    final colorScheme = Theme.of(context).colorScheme;
    final hasPassport = widget.pet?.passportNo?.trim().isNotEmpty ?? false;
    final status =
        hasPassport ? '등록됨 · $_countryCode' : '선택 정보 · $_countryCode';
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        key: const Key('pet_editor_passport_manage_button'),
        borderRadius: BorderRadius.circular(14.r),
        onTap: _isSubmitting ? null : _openPassportEditor,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Row(
            children: [
              const Icon(Icons.badge_outlined, color: AppTheme.actionBase),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '여권 정보',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      status,
                      key: const Key('pet_editor_passport_status'),
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '관리',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.actionBase,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right, color: AppTheme.actionBase),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    final colorScheme = Theme.of(context).colorScheme;
    return PetSpaceBottomActionBar(
      key: const Key('pet_editor_bottom_action'),
      minimum: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 14.h),
      child: _isEditing
          ? _buildPrimaryButton(label: '변경사항 저장', onPressed: _submit)
          : _registrationStep == 0
              ? _buildPrimaryButton(label: '다음', onPressed: _goToStepTwo)
              : Row(
                  children: [
                    TextButton(
                      key: const Key('pet_editor_skip_button'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(88, 52),
                        foregroundColor: colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: Text('건너뛰기', style: TextStyle(fontSize: 15.sp)),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildPrimaryButton(
                        label: '등록 완료',
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPrimaryButton(
      {required String label, required VoidCallback onPressed}) {
    return ElevatedButton(
      key: const Key('pet_editor_primary_button'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: AppTheme.actionBase,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppTheme.actionBase.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white,
        overlayColor: AppTheme.actionPressed,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
      onPressed: _isSubmitting ? null : onPressed,
      child: _isSubmitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Text(label,
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700)),
    );
  }

  void _goToStepTwo() {
    if (_stepOneFormKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    setState(() => _registrationStep = 1);
  }

  Future<void> _pickImage() async {
    try {
      final picker = widget.imagePicker;
      File? selectedFile;
      if (picker != null) {
        selectedFile = await picker(context);
      } else {
        final image = await ImageSourcePicker.pickSingle(
          context,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 70,
        );
        selectedFile = image == null ? null : File(image.path);
      }
      final pickedFile = selectedFile;
      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImageFile = pickedFile;
          _avatarUrl = pickedFile.path;
          _cachedUploadedAvatarUrl = null;
          _cachedUploadedAvatarSourcePath = null;
        });
      }
    } catch (_) {
      if (mounted) _showMessage('이미지를 선택하지 못했습니다. 다시 시도해주세요.');
    }
  }

  Future<void> _selectBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthDate && mounted) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  Future<void> _openPassportEditor() async {
    final result = await Navigator.of(context).push<_PassportDraft>(
      MaterialPageRoute(
        builder: (_) => _PassportEditorPage(
          passportNo: widget.pet?.passportNo,
          initialDraft: _PassportDraft(
            surname: _passportSurnameController.text,
            givenName: _passportGivenNameController.text,
            nameHanguel: _nameHanguelController.text,
            countryCode: _countryCode,
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _passportSurnameController.text = result.surname;
      _passportGivenNameController.text = result.givenName;
      _nameHanguelController.text = result.nameHanguel;
      _countryCode = result.countryCode;
    });
  }

  bool _validateForSubmit() {
    if (_isEditing) return _editFormKey.currentState?.validate() == true;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _registrationStep = 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _stepOneFormKey.currentState?.validate();
      });
      return false;
    }
    return _stepTwoFormKey.currentState?.validate() == true;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_validateForSubmit()) return;
    final bloc = context.read<PetBloc>();
    if (widget.userId.trim().isEmpty) {
      _showMessage('로그인이 필요합니다.');
      return;
    }
    if (bloc.state is! PetLoaded) {
      FocusScope.of(context).unfocus();
      setState(() {
        _isSubmitting = true;
        _resubmitAfterReload = true;
      });
      bloc.add(LoadUserPets());
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    try {
      final existing = widget.pet;
      final now = DateTime.now();
      final petId = existing?.id ??
          (_draftPetId ??= now.millisecondsSinceEpoch.toString());
      var uploadedAvatarUrl = existing?.avatarUrl;
      final selectedImageFile = _selectedImageFile;
      if (selectedImageFile != null) {
        if (_cachedUploadedAvatarUrl != null &&
            _cachedUploadedAvatarSourcePath == selectedImageFile.path) {
          uploadedAvatarUrl = _cachedUploadedAvatarUrl;
        } else {
          uploadedAvatarUrl =
              await (widget.imageUploadService ?? di.sl<ImageUploadService>())
                  .uploadPetAvatar(selectedImageFile, petId);
          _cachedUploadedAvatarUrl = uploadedAvatarUrl;
          _cachedUploadedAvatarSourcePath = selectedImageFile.path;
        }
      }
      if (!mounted) return;

      final pet = Pet(
        id: petId,
        userId: existing?.userId ?? widget.userId,
        name: _nameController.text.trim(),
        type: _selectedType,
        breed: _finalBreed(),
        birthDate: _selectedBirthDate,
        gender: _selectedGender,
        avatarUrl: uploadedAvatarUrl,
        description: _trimToNull(_descriptionController.text),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        currentMbtiType: existing?.currentMbtiType,
        currentMbtiUpdatedAt: existing?.currentMbtiUpdatedAt,
        passportNo: existing?.passportNo,
        passportSurname:
            _isEditing ? _trimToNull(_passportSurnameController.text) : null,
        passportGivenName:
            _isEditing ? _trimToNull(_passportGivenNameController.text) : null,
        nameHanguel:
            _isEditing ? _trimToNull(_nameHanguelController.text) : null,
        countryCode: _isEditing ? _countryCode : 'KOR',
      );

      bloc.add(_isEditing ? UpdatePetEvent(pet) : AddPetEvent(pet));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showMessage('저장하지 못했습니다. 잠시 후 다시 시도해주세요.');
    }
  }

  String? _finalBreed() {
    if (_selectedBreed == null) return null;
    return _isCustomBreed ? _trimToNull(_breedController.text) : _selectedBreed;
  }

  String? _trimToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PassportDraft {
  const _PassportDraft({
    required this.surname,
    required this.givenName,
    required this.nameHanguel,
    required this.countryCode,
  });

  final String surname;
  final String givenName;
  final String nameHanguel;
  final String countryCode;
}

class _PassportEditorPage extends StatefulWidget {
  const _PassportEditorPage({required this.initialDraft, this.passportNo});

  final _PassportDraft initialDraft;
  final String? passportNo;

  @override
  State<_PassportEditorPage> createState() => _PassportEditorPageState();
}

class _PassportEditorPageState extends State<_PassportEditorPage> {
  late final TextEditingController _surnameController;
  late final TextEditingController _givenNameController;
  late final TextEditingController _nameHanguelController;
  late String _countryCode;

  @override
  void initState() {
    super.initState();
    _surnameController =
        TextEditingController(text: widget.initialDraft.surname);
    _givenNameController =
        TextEditingController(text: widget.initialDraft.givenName);
    _nameHanguelController =
        TextEditingController(text: widget.initialDraft.nameHanguel);
    _countryCode = widget.initialDraft.countryCode;
  }

  @override
  void dispose() {
    _surnameController.dispose();
    _givenNameController.dispose();
    _nameHanguelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final headingColor = theme.brightness == Brightness.dark
        ? colorScheme.onSurface
        : AppTheme.brandDeep;
    return Scaffold(
      key: const Key('pet_passport_editor_page'),
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: '뒤로',
        ),
        title: Text(
          '여권 정보',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: headingColor,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '여권 카드에 표시할 선택 정보예요.',
                style: TextStyle(
                    fontSize: 14.sp, color: colorScheme.onSurfaceVariant),
              ),
              if (widget.passportNo?.trim().isNotEmpty ?? false) ...[
                SizedBox(height: 20.h),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '여권번호',
                    border: petEditorInputBorder,
                  ),
                  child: Text(widget.passportNo!),
                ),
              ],
              SizedBox(height: 20.h),
              TextFormField(
                key: const Key('pet_passport_surname_field'),
                controller: _surnameController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                  _UpperCaseTextFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: '영문 성 (Surname)',
                  hintText: '예: KIM',
                  border: petEditorInputBorder,
                ),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                key: const Key('pet_passport_given_name_field'),
                controller: _givenNameController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
                  _UpperCaseTextFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: '영문 이름 (Given name)',
                  hintText: '예: MONGE',
                  border: petEditorInputBorder,
                ),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                key: const Key('pet_passport_hanguel_name_field'),
                controller: _nameHanguelController,
                decoration: const InputDecoration(
                  labelText: '여권 표기용 한글 이름',
                  hintText: '비워두면 반려동물 이름으로 표시',
                  helperText: '기본 정보의 이름과 별개로 여권 카드에 표시돼요.',
                  border: petEditorInputBorder,
                ),
              ),
              SizedBox(height: 16.h),
              DropdownButtonFormField<String>(
                key: const Key('pet_passport_country_field'),
                initialValue: _countryCode,
                decoration: const InputDecoration(
                  labelText: '국가',
                  border: petEditorInputBorder,
                ),
                items: _PetEditorPageState._countryOptions
                    .map((option) => DropdownMenuItem(
                          value: option.code,
                          child: Text(option.label),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _countryCode = value);
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: PetSpaceBottomActionBar(
        key: const Key('pet_passport_bottom_action'),
        minimum: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 14.h),
        child: ElevatedButton(
          key: const Key('pet_passport_save_button'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: AppTheme.actionBase,
            foregroundColor: Colors.white,
            overlayColor: AppTheme.actionPressed,
            elevation: 0,
          ),
          onPressed: () {
            Navigator.of(context).pop(
              _PassportDraft(
                surname: _surnameController.text,
                givenName: _givenNameController.text,
                nameHanguel: _nameHanguelController.text,
                countryCode: _countryCode,
              ),
            );
          },
          child: Text(
            '여권 정보 저장',
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
