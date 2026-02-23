import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../config/injection_container.dart' as di;
import '../../domain/entities/pet.dart';

// 품종 데이터
const Map<PetType, List<String>> petBreeds = {
  PetType.dog: [
    '골든 리트리버',
    '래브라도 리트리버',
    '비글',
    '시바견',
    '진돗개',
    '포메라니안',
    '말티즈',
    '푸들',
    '치와와',
    '요크셔테리어',
    '시츄',
    '웰시코기',
    '보더콜리',
    '허스키',
    '사모예드',
    '기타',
  ],
  PetType.cat: [
    '코리안 숏헤어',
    '페르시안',
    '러시안 블루',
    '브리티시 숏헤어',
    '스코티시 폴드',
    '아메리칸 숏헤어',
    '샴',
    '뱅갈',
    '메인쿤',
    '노르웨이 숲',
    '랙돌',
    '터키시 앙고라',
    '기타',
  ],
};

class AddPetBottomSheet extends StatefulWidget {
  final Pet? pet; // null이면 추가, 있으면 수정
  final Function(Pet) onPetAdded;

  const AddPetBottomSheet({
    super.key,
    this.pet,
    required this.onPetAdded,
  });

  @override
  State<AddPetBottomSheet> createState() => _AddPetBottomSheetState();
}

class _AddPetBottomSheetState extends State<AddPetBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _descriptionController = TextEditingController();

  PetType _selectedType = PetType.dog;
  PetGender? _selectedGender;
  DateTime? _selectedBirthDate;
  String? _avatarUrl;
  File? _selectedImageFile; // 선택한 이미지 파일 저장
  bool _isLoading = false;

  String? _selectedBreed; // 드롭다운에서 선택된 품종
  bool _isCustomBreed = false; // "기타" 선택 시 true

  @override
  void initState() {
    super.initState();
    if (widget.pet != null) {
      _initializeWithPet(widget.pet!);
    }
  }

  void _initializeWithPet(Pet pet) {
    _nameController.text = pet.name;
    _descriptionController.text = pet.description ?? '';
    _selectedType = pet.type;
    _selectedGender = pet.gender;
    _selectedBirthDate = pet.birthDate;
    _avatarUrl = pet.avatarUrl;

    // 품종 초기화
    if (pet.breed != null && pet.breed!.isNotEmpty) {
      final breeds = petBreeds[pet.type] ?? [];
      if (breeds.contains(pet.breed)) {
        _selectedBreed = pet.breed;
        _isCustomBreed = pet.breed == '기타';
        if (_isCustomBreed) {
          _breedController.text = '';
        }
      } else {
        _selectedBreed = '기타';
        _isCustomBreed = true;
        _breedController.text = pet.breed!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  SizedBox(height: 24.h),
                  _buildAvatarSection(),
                  SizedBox(height: 24.h),
                  _buildNameField(),
                  SizedBox(height: 16.h),
                  _buildTypeSelector(),
                  SizedBox(height: 16.h),
                  _buildBreedField(),
                  SizedBox(height: 16.h),
                  _buildGenderSelector(),
                  SizedBox(height: 16.h),
                  _buildBirthDateField(),
                  SizedBox(height: 16.h),
                  _buildDescriptionField(),
                  SizedBox(height: 24.h),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.pet == null ? '반려동물 추가하기' : '반려동물 수정하기',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.close, size: 24.w),
        ),
      ],
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: 100.w,
          height: 100.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: _selectedImageFile != null
              ? ClipOval(
                  child: Image.file(
                    _selectedImageFile!,
                    width: 100.w,
                    height: 100.w,
                    fit: BoxFit.cover,
                  ),
                )
              : _avatarUrl != null
                  ? ClipOval(
                      child: Image.network(
                        _avatarUrl!,
                        width: 100.w,
                        height: 100.w,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.add_a_photo,
                            size: 40.w,
                            color: AppTheme.primaryColor,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.add_a_photo,
                      size: 40.w,
                      color: AppTheme.primaryColor,
                    ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: '이름 *',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '이름을 입력해주세요';
        }
        return null;
      },
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '종류 *',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        RadioGroup<PetType>(
          groupValue: _selectedType,
          onChanged: (value) {
            setState(() {
              _selectedType = value!;
              // 종류가 변경되면 품종 선택 초기화
              _selectedBreed = null;
              _isCustomBreed = false;
              _breedController.clear();
            });
          },
          child: const Row(
            children: [
              Expanded(
                child: RadioListTile<PetType>(
                  title: Text('강아지'),
                  value: PetType.dog,
                ),
              ),
              Expanded(
                child: RadioListTile<PetType>(
                  title: Text('고양이'),
                  value: PetType.cat,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreedField() {
    final breeds = petBreeds[_selectedType] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedBreed,
          decoration: const InputDecoration(
            labelText: '품종',
            border: OutlineInputBorder(),
          ),
          hint: const Text('품종을 선택하세요'),
          items: breeds.map((String breed) {
            return DropdownMenuItem<String>(
              value: breed,
              child: Text(breed),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedBreed = newValue;
              _isCustomBreed = newValue == '기타';
              if (!_isCustomBreed) {
                _breedController.clear();
              }
            });
          },
        ),
        if (_isCustomBreed) ...[
          SizedBox(height: 16.h),
          TextFormField(
            controller: _breedController,
            decoration: const InputDecoration(
              labelText: '품종 직접 입력',
              hintText: '예: 믹스견, 코숏 등',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (_isCustomBreed && (value == null || value.trim().isEmpty)) {
                return '품종을 입력해주세요';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '성별',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        RadioGroup<PetGender?>(
          groupValue: _selectedGender,
          onChanged: (value) {
            setState(() {
              _selectedGender = value;
            });
          },
          child: const Row(
            children: [
              Expanded(
                child: RadioListTile<PetGender?>(
                  title: Text('수컷'),
                  value: PetGender.male,
                ),
              ),
              Expanded(
                child: RadioListTile<PetGender?>(
                  title: Text('암컷'),
                  value: PetGender.female,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBirthDateField() {
    return InkWell(
      onTap: _selectBirthDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '생년월일',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(
          _selectedBirthDate != null
              ? '${_selectedBirthDate!.year}.${_selectedBirthDate!.month.toString().padLeft(2, '0')}.${_selectedBirthDate!.day.toString().padLeft(2, '0')}'
              : '생년월일을 선택해주세요',
          style: TextStyle(
            color: _selectedBirthDate != null ? Colors.black : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: '설명',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      maxLines: 3,
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('취소', style: TextStyle(fontSize: 16.sp)),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _savePet,
            child: _isLoading
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.pet == null ? '추가하기' : '수정하기', style: TextStyle(fontSize: 16.sp)),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
          _avatarUrl = image.path; // 프리뷰용 로컬 경로 유지
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  Future<void> _savePet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? uploadedAvatarUrl = widget.pet?.avatarUrl;

      // 새 이미지가 선택된 경우 업로드
      if (_selectedImageFile != null) {
        final imageService = di.sl<ImageUploadService>();
        final petId = widget.pet?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

        uploadedAvatarUrl = await imageService.uploadPetAvatar(
          _selectedImageFile!,
          petId,
        );
      }

      // 품종 결정: 기타를 선택했으면 직접 입력한 값, 아니면 드롭다운에서 선택한 값
      String? finalBreed;
      if (_selectedBreed != null) {
        if (_isCustomBreed) {
          finalBreed = _breedController.text.trim().isNotEmpty
              ? _breedController.text.trim()
              : null;
        } else {
          finalBreed = _selectedBreed;
        }
      }

      // 현재 사용자 ID 가져오기
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다.')),
          );
        }
        return;
      }

      final now = DateTime.now();
      final pet = Pet(
        id: widget.pet?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        userId: widget.pet?.userId ?? currentUserId,
        name: _nameController.text.trim(),
        type: _selectedType,
        breed: finalBreed,
        birthDate: _selectedBirthDate,
        gender: _selectedGender,
        avatarUrl: uploadedAvatarUrl,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        createdAt: widget.pet?.createdAt ?? now,
        updatedAt: now,
      );

      widget.onPetAdded(pet);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
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
