import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../shared/themes/app_theme.dart';
import '../bloc/emotion_analysis_bloc.dart';
import '../widgets/pet_selection_dropdown.dart';
import '../widgets/emotion_loading_widget.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_event.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import 'emotion_result_page.dart';

class EmotionAnalysisPage extends StatefulWidget {
  final String? initialPetId;
  final String? initialPetName;

  const EmotionAnalysisPage({
    super.key,
    this.initialPetId,
    this.initialPetName,
  });

  @override
  State<EmotionAnalysisPage> createState() => _EmotionAnalysisPageState();
}

// 품종 데이터
const Map<String, List<String>> _breedsByType = {
  'dog': [
    '골든 리트리버', '래브라도 리트리버', '비글', '시바견', '진돗개',
    '포메라니안', '말티즈', '푸들', '치와와', '요크셔테리어',
    '시츄', '웰시코기', '보더콜리', '허스키', '사모예드', '기타',
  ],
  'cat': [
    '코리안 숏헤어', '페르시안', '러시안 블루', '브리티시 숏헤어',
    '스코티시 폴드', '아메리칸 숏헤어', '샴', '뱅갈',
    '메인쿤', '노르웨이 숲', '랙돌', '터키시 앙고라', '기타',
  ],
};

class _EmotionAnalysisPageState extends State<EmotionAnalysisPage> {
  final ImagePicker _picker = ImagePicker();
  Pet? _selectedPet;
  bool _analyzeWithoutPet = false;

  // 수동 종/품종 선택 (반려동물 미선택 시)
  String? _manualPetType; // 'dog' or 'cat'
  String? _manualBreed;

  // 다중 이미지 경로 목록 (최대 5장)
  final List<String> _imagePaths = [];
  static const int _maxImages = 5;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<PetBloc>().add(LoadUserPets());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initialPetId != null && _selectedPet == null) {
      final petState = context.read<PetBloc>().state;
      if (petState is PetLoaded) {
        _selectInitialPet(petState.pets);
      }
    }
  }

  void _selectInitialPet(List<Pet> pets) {
    if (widget.initialPetId != null) {
      try {
        final pet = pets.firstWhere((p) => p.id == widget.initialPetId);
        setState(() => _selectedPet = pet);
      } catch (_) {}
    }
  }

  bool get _canAnalyze =>
      (_selectedPet != null || _analyzeWithoutPet) && _imagePaths.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('감정 분석'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: BlocConsumer<EmotionAnalysisBloc, EmotionAnalysisState>(
        listener: (context, state) {
          if (state is EmotionAnalysisSuccess) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EmotionResultPage(
                  analysis: state.analysis,
                  imagePaths: List.from(_imagePaths),
                ),
              ),
            );
          } else if (state is EmotionAnalysisError) {
            _showErrorDialog(state.message);
          }
        },
        builder: (context, emotionState) {
          if (emotionState is EmotionAnalysisLoading) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: const EmotionLoadingWidget(),
              ),
            );
          }

          return BlocBuilder<PetBloc, PetState>(
            builder: (context, petState) {
              List<Pet> userPets = [];
              if (petState is PetLoaded) {
                userPets = petState.pets;
                if (widget.initialPetId != null && _selectedPet == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _selectInitialPet(userPets);
                  });
                }
              }

              return SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8.h),

                    // 반려동물 선택
                    _buildSectionCard(
                      child: PetSelectionDropdown(
                        pets: userPets,
                        selectedPet: _selectedPet,
                        onChanged: (Pet? pet) {
                          setState(() {
                            _selectedPet = pet;
                            _analyzeWithoutPet = false;
                          });
                        },
                        analyzeWithoutPet: _analyzeWithoutPet,
                        onAnalyzeWithoutPetChanged: (bool value) {
                          setState(() {
                            _analyzeWithoutPet = value;
                            if (value) {
                              _selectedPet = null;
                              _manualPetType = null;
                              _manualBreed = null;
                            }
                          });
                        },
                      ),
                    ),

                    // 수동 종/품종 선택 (반려동물 미선택 시)
                    if (_analyzeWithoutPet) ...[
                      SizedBox(height: 12.h),
                      _buildSectionCard(child: _buildManualBreedSelector()),
                    ],

                    SizedBox(height: 16.h),

                    // 사진 섹션 헤더
                    Row(
                      children: [
                        Text(
                          '사진 선택',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '${_imagePaths.length}/$_maxImages',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: _imagePaths.length >= _maxImages
                                ? Colors.orange
                                : Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '여러 장일수록 더 정확해요',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),

                    // 사진 그리드
                    _buildImageGrid(),

                    SizedBox(height: 8.h),

                    // 사진 추가 버튼 (최대치 미만일 때만)
                    if (_imagePaths.length < _maxImages)
                      _buildAddPhotoButtons(),

                    SizedBox(height: 24.h),

                    // 분석 시작 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: ElevatedButton.icon(
                        onPressed: _canAnalyze ? _startAnalysis : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          elevation: 0,
                        ),
                        icon: Icon(Icons.search_rounded, size: 20.w),
                        label: Text(
                          _imagePaths.isEmpty
                              ? '사진을 선택해주세요'
                              : '${_imagePaths.length}장 종합 분석 시작',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 사진 그리드 (선택된 사진들 + 빈 슬롯 힌트)
  Widget _buildImageGrid() {
    if (_imagePaths.isEmpty) {
      return Container(
        width: double.infinity,
        height: 120.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 36.w, color: Colors.grey.shade400),
            SizedBox(height: 8.h),
            Text(
              '카메라 또는 갤러리에서 사진을 추가하세요',
              style:
                  TextStyle(fontSize: 12.sp, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.w,
        mainAxisSpacing: 8.w,
        childAspectRatio: 1,
      ),
      itemCount: _imagePaths.length,
      itemBuilder: (context, index) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: Image.file(
                File(_imagePaths[index]),
                fit: BoxFit.cover,
              ),
            ),
            // X 버튼
            Positioned(
              top: 4.h,
              right: 4.w,
              child: GestureDetector(
                onTap: () => setState(() => _imagePaths.removeAt(index)),
                child: Container(
                  width: 22.w,
                  height: 22.w,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 14.w, color: Colors.white),
                ),
              ),
            ),
            // 첫 번째 사진 표시
            if (index == 0)
              Positioned(
                bottom: 4.h,
                left: 4.w,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    '대표',
                    style:
                        TextStyle(fontSize: 9.sp, color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // 사진 추가 버튼 (카메라 / 갤러리)
  Widget _buildAddPhotoButtons() {
    final enabled = _selectedPet != null || _analyzeWithoutPet;
    return Row(
      children: [
        Expanded(
          child: _buildAddButton(
            icon: Icons.camera_alt_outlined,
            label: '카메라',
            color: AppTheme.highlightColor,
            onTap: enabled ? () => _addPicture(ImageSource.camera) : null,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _buildAddButton(
            icon: Icons.photo_library_outlined,
            label: '갤러리',
            color: AppTheme.accentColor,
            onTap: enabled ? () => _addPicture(ImageSource.gallery) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52.h,
        decoration: BoxDecoration(
          color: isEnabled ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isEnabled ? color.withValues(alpha: 0.4) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18.w,
                color: isEnabled ? color : Colors.grey.shade400),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isEnabled ? color : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualBreedSelector() {
    final breeds = _manualPetType != null
        ? _breedsByType[_manualPetType] ?? []
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '종류 선택 (선택사항)',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.secondaryTextColor,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            _buildTypeChip('dog', '강아지'),
            SizedBox(width: 8.w),
            _buildTypeChip('cat', '고양이'),
          ],
        ),
        if (_manualPetType != null && breeds.isNotEmpty) ...[
          SizedBox(height: 12.h),
          DropdownButtonFormField<String>(
            initialValue: _manualBreed,
            decoration: InputDecoration(
              labelText: '품종',
              labelStyle: TextStyle(fontSize: 13.sp),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 10.h,
              ),
              isDense: true,
            ),
            items: breeds
                .map((b) => DropdownMenuItem(value: b, child: Text(b, style: TextStyle(fontSize: 13.sp))))
                .toList(),
            onChanged: (value) => setState(() => _manualBreed = value),
          ),
        ],
        SizedBox(height: 4.h),
        Text(
          '품종을 선택하면 더 정확한 분석이 가능해요',
          style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String type, String label) {
    final isSelected = _manualPetType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _manualPetType = type;
          _manualBreed = null;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Future<void> _addPicture(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        // 갤러리: 여러 장 한번에 선택
        final remaining = _maxImages - _imagePaths.length;
        final List<XFile> images = await _picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
          limit: remaining,
        );
        if (!mounted) return;
        if (images.isNotEmpty) {
          setState(() {
            for (final img in images) {
              if (_imagePaths.length < _maxImages) {
                _imagePaths.add(img.path);
              }
            }
          });
        }
      } else {
        // 카메라: 한 장씩
        final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (!mounted) return;
        if (image != null) {
          setState(() => _imagePaths.add(image.path));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')),
      );
    }
  }

  void _startAnalysis() {
    // 반려동물 선택 시 자동으로 petType/breed 추출
    String? petType;
    String? breed;
    if (_selectedPet != null) {
      petType = _selectedPet!.type.name; // 'dog' or 'cat'
      breed = _selectedPet!.breed;
    } else if (_analyzeWithoutPet) {
      petType = _manualPetType;
      breed = _manualBreed;
    }

    context.read<EmotionAnalysisBloc>().add(
          AnalyzeEmotionRequested(
            imagePaths: List.from(_imagePaths),
            petId: _analyzeWithoutPet ? null : _selectedPet?.id,
            petType: petType,
            breed: breed,
          ),
        );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 24.w),
            SizedBox(width: 12.w),
            Text('분석 실패', style: TextStyle(fontSize: 18.sp)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: TextStyle(fontSize: 14.sp)),
            SizedBox(height: 16.h),
            Text('가능한 원인:',
                style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp)),
            SizedBox(height: 8.h),
            Text('• 네트워크 연결 문제', style: TextStyle(fontSize: 14.sp)),
            Text('• 이미지가 너무 크거나 손상됨', style: TextStyle(fontSize: 14.sp)),
            Text('• AI 서버 일시적 오류', style: TextStyle(fontSize: 14.sp)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('취소', style: TextStyle(fontSize: 14.sp)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              if (_imagePaths.isNotEmpty && _canAnalyze) {
                _startAnalysis();
              }
            },
            icon: const Icon(Icons.refresh),
            label: Text('재시도', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }
}
