import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../pets/domain/entities/pet.dart' as pets;
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_event.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../config/injection_container.dart' as di;

enum PetType { dog, cat }

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
  final _breedController = TextEditingController();
  PetType? _selectedType;
  String? _selectedGender;
  DateTime? _birthDate;
  String? _petPhotoUrl;
  File? _selectedImageFile; // 선택한 이미지 파일 저장
  final List<Map<String, dynamic>> _registeredPets = [];

  String? _selectedBreed; // 드롭다운에서 선택된 품종
  bool _isCustomBreed = false; // "기타" 선택 시 true

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<PetBloc>(),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/onboarding/profile');
              }
            },
          ),
          title: const Text(
            '반려동물 등록',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                SizedBox(height: 20.h),
                if (_registeredPets.isNotEmpty) ...[
                  _buildRegisteredPetsList(),
                  SizedBox(height: 20.h),
                ],
                Expanded(
                  child: _buildPetRegistrationForm(),
                ),
                _buildBottomButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '반려동물을 등록해주세요',
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          '반려동물의 정보를 입력하면 더 정확한 감정 분석을 받을 수 있어요',
          style: TextStyle(
            fontSize: 16.sp,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisteredPetsList() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.subColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.subColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pets, color: AppTheme.accentColor, size: 24.w),
              SizedBox(width: 8.w),
              Text(
                '등록된 반려동물 (${_registeredPets.length}마리)',
                style: TextStyle(
                  color: AppTheme.accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...(_registeredPets.map((pet) => _buildPetItem(pet))),
        ],
      ),
    );
  }

  Widget _buildPetItem(Map<String, dynamic> pet) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20.w,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
            child: Icon(
              pet['type'] == PetType.dog ? Icons.pets : Icons.pets,
              color: AppTheme.primaryColor,
              size: 20.w,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                  ),
                ),
                Text(
                  '${pet['type'] == PetType.dog ? '강아지' : '고양이'} • ${pet['breed']} • ${pet['gender']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: AppTheme.highlightColor, size: 24.w),
            onPressed: () => _removePet(pet),
          ),
        ],
      ),
    );
  }

  Widget _buildPetRegistrationForm() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPetPhotoSection(),
            SizedBox(height: 24.h),
            _buildPetTypeSelection(),
            SizedBox(height: 16.h),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '이름 *',
                hintText: '반려동물의 이름을 입력해주세요',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.pets, size: 24.w),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '이름을 입력해주세요';
                }
                return null;
              },
            ),
            SizedBox(height: 16.h),
            _buildBreedField(),
            SizedBox(height: 16.h),
            _buildGenderSelection(),
            SizedBox(height: 16.h),
            _buildBirthDatePicker(),
            SizedBox(height: 24.h),
            _buildAddPetButton(),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildPetPhotoSection() {
    return Center(
      child: GestureDetector(
        onTap: _pickPetPhoto,
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
              : _petPhotoUrl != null
                  ? ClipOval(
                      child: Image.network(
                        _petPhotoUrl!,
                        width: 100.w,
                        height: 100.w,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPhotoPlaceholder();
                        },
                      ),
                    )
                  : _buildPhotoPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_a_photo,
          size: 30.w,
          color: AppTheme.primaryColor,
        ),
        SizedBox(height: 4.h),
        Text(
          '사진 추가',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 10.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPetTypeSelection() {
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
        Row(
          children: [
            Expanded(
              child: _buildTypeOption(
                PetType.dog,
                '강아지',
                Icons.pets,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildTypeOption(
                PetType.cat,
                '고양이',
                Icons.pets,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeOption(PetType type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          // 종류가 변경되면 품종 선택 초기화
          _selectedBreed = null;
          _isCustomBreed = false;
          _breedController.clear();
        });
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32.w,
              color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreedField() {
    if (_selectedType == null) {
      return TextFormField(
        enabled: false,
        decoration: InputDecoration(
          labelText: '품종 (선택)',
          hintText: '먼저 반려동물 종류를 선택해주세요',
          border: const OutlineInputBorder(),
          prefixIcon: Icon(Icons.category, size: 24.w),
        ),
      );
    }

    final breeds = petBreeds[_selectedType] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedBreed,
          decoration: InputDecoration(
            labelText: '품종 (선택)',
            border: const OutlineInputBorder(),
            prefixIcon: Icon(Icons.category, size: 24.w),
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
            decoration: InputDecoration(
              labelText: '품종 직접 입력',
              hintText: '예: 믹스견, 코숏 등',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit, size: 24.w),
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

  Widget _buildGenderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '성별 (선택)',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: _buildGenderOption('수컷'),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildGenderOption('암컷'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(String gender) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = isSelected ? null : gender;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Center(
          child: Text(
            gender,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryColor : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14.sp,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBirthDatePicker() {
    return GestureDetector(
      onTap: _selectBirthDate,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.grey[600], size: 24.w),
            SizedBox(width: 12.w),
            Text(
              _birthDate == null
                  ? '생년월일 (선택)'
                  : '${_birthDate!.year}년 ${_birthDate!.month}월 ${_birthDate!.day}일',
              style: TextStyle(
                color: _birthDate == null ? Colors.grey[600] : Colors.black,
                fontSize: 16.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPetButton() {
    return ElevatedButton.icon(
      onPressed: _addPet,
      icon: Icon(Icons.add, size: 24.w),
      label: Text('반려동물 추가', style: TextStyle(fontSize: 16.sp)),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Column(
      children: [
        if (_registeredPets.isNotEmpty)
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton(
              onPressed: _continue,
              child: Text(
                '계속하기',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: OutlinedButton(
              onPressed: _skip,
              child: Text(
                '나중에 등록하기',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickPetPhoto() async {
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
          _petPhotoUrl = image.path; // 프리뷰용 로컬 경로 유지
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

  void _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  void _addPet() {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('반려동물의 종류를 선택해주세요')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      // 품종 결정: 기타를 선택했으면 직접 입력한 값, 아니면 드롭다운에서 선택한 값
      String finalBreed;
      if (_selectedBreed != null) {
        if (_isCustomBreed) {
          finalBreed = _breedController.text.trim().isNotEmpty
              ? _breedController.text.trim()
              : '품종 미상';
        } else {
          finalBreed = _selectedBreed!;
        }
      } else {
        finalBreed = '품종 미상';
      }

      final newPet = {
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'breed': finalBreed,
        'gender': _selectedGender ?? '성별 미상',
        'birthDate': _birthDate,
        'photoUrl': _petPhotoUrl,
      };

      setState(() {
        _registeredPets.add(newPet);
        _nameController.clear();
        _breedController.clear();
        _selectedType = null;
        _selectedGender = null;
        _birthDate = null;
        _petPhotoUrl = null;
        _selectedImageFile = null; // 이미지 파일도 초기화
        _selectedBreed = null; // 품종 선택 초기화
        _isCustomBreed = false; // 커스텀 품종 플래그 초기화
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newPet['name']} 등록 완료!')),
      );
    }
  }

  void _removePet(Map<String, dynamic> pet) {
    setState(() {
      _registeredPets.remove(pet);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${pet['name']} 삭제됨')),
    );
  }

  Future<void> _continue() async {
    // 현재 로그인한 사용자 ID 가져오기
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
      }
      return;
    }

    final userId = authState.user.id;
    final petBloc = context.read<PetBloc>();

    // 로딩 표시
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      int successCount = 0;
      int failCount = 0;

      // PetBloc을 통해 모든 펫을 DB에 저장
      for (final petData in _registeredPets) {
        // Map을 Pet 엔티티로 변환
        final petType = petData['type'] == PetType.dog
            ? pets.PetType.dog
            : pets.PetType.cat;

        // gender 문자열을 PetGender enum으로 변환
        pets.PetGender? petGender;
        final genderStr = petData['gender'] as String?;
        if (genderStr == '수컷') {
          petGender = pets.PetGender.male;
        } else if (genderStr == '암컷') {
          petGender = pets.PetGender.female;
        }

        final pet = pets.Pet(
          id: '', // 서버에서 생성
          userId: userId,
          name: petData['name'] as String,
          type: petType,
          breed: petData['breed'] as String?,
          gender: petGender,
          birthDate: petData['birthDate'] as DateTime?,
          avatarUrl: petData['photoUrl'] as String?,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // PetBloc에 이벤트 발행
        petBloc.add(AddPetEvent(pet));

        // 상태 변화를 기다림 (최대 5초)
        await Future.delayed(const Duration(milliseconds: 500));

        // 현재 상태 확인
        final currentState = petBloc.state;
        if (currentState is PetOperationSuccess || currentState is PetLoaded) {
          successCount++;
        } else if (currentState is PetError) {
          failCount++;
        }
      }

      // 로딩 닫기
      if (mounted) {
        Navigator.of(context).pop();

        if (failCount == 0) {
          // 모두 성공
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount마리 반려동물이 성공적으로 등록되었습니다!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // 다음 페이지로 이동
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            context.go('/onboarding/tutorial');
          }
        } else {
          // 일부 실패
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$successCount마리 등록 성공, $failCount마리 실패했습니다.\n다시 시도해주세요.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // 로딩 닫기
      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('펫 등록 중 오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _skip() {
    context.go('/onboarding/tutorial');
  }
}
