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

class _EmotionAnalysisPageState extends State<EmotionAnalysisPage> {
  final ImagePicker _picker = ImagePicker();
  Pet? _selectedPet;
  String? _lastImagePath;
  bool _analyzeWithoutPet = false; // 반려동물 없이 분석 옵션

  @override
  void initState() {
    super.initState();
    // 사용자의 반려동물 목록 로드
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<PetBloc>().add(LoadUserPets());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 초기 반려동물 선택 (한 번만 실행)
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
        setState(() {
          _selectedPet = pet;
        });
      } catch (_) {
        // 해당 ID의 반려동물이 없으면 무시
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('감정 분석'),
        centerTitle: true,
      ),
      body: BlocConsumer<EmotionAnalysisBloc, EmotionAnalysisState>(
        listener: (context, state) {
          if (state is EmotionAnalysisSuccess) {
            // 분석 성공 시 결과 페이지로 이동
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EmotionResultPage(
                  analysis: state.analysis,
                  imagePath: _lastImagePath,
                ),
              ),
            );
          } else if (state is EmotionAnalysisError) {
            // 에러 발생 시 재시도 옵션 제공
            _showErrorDialog(state.message);
          }
        },
        builder: (context, emotionState) {
          // 로딩 중일 때 전체 화면 로딩 위젯 표시
          if (emotionState is EmotionAnalysisLoading) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: const EmotionLoadingWidget(),
              ),
            );
          }

          // PetBloc의 상태를 가져와서 반려동물 목록 표시
          return BlocBuilder<PetBloc, PetState>(
            builder: (context, petState) {
              List<Pet> userPets = [];

              if (petState is PetLoaded) {
                userPets = petState.pets;
                // 초기 반려동물 선택 (PetLoaded 상태일 때)
                if (widget.initialPetId != null && _selectedPet == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _selectInitialPet(userPets);
                  });
                }
              }

              return Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt,
                      size: 80.w,
                      color: AppTheme.accentColor,
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      '반려동물 사진을 촬영하거나 선택하여\nAI 감정 분석을 시작해보세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16.sp),
                    ),
                    SizedBox(height: 32.h),
                    PetSelectionDropdown(
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
                          }
                        });
                      },
                    ),
                    SizedBox(height: 32.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: (_selectedPet != null || _analyzeWithoutPet)
                              ? () => _takePicture(ImageSource.camera)
                              : null,
                          icon: const Icon(Icons.camera),
                          label: Text('카메라', style: TextStyle(fontSize: 14.sp)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.highlightColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24.w,
                              vertical: 12.h,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: (_selectedPet != null || _analyzeWithoutPet)
                              ? () => _takePicture(ImageSource.gallery)
                              : null,
                          icon: const Icon(Icons.photo_library),
                          label: Text('갤러리', style: TextStyle(fontSize: 14.sp)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24.w,
                              vertical: 12.h,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _takePicture(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (!mounted) return;

      if (image != null) {
        setState(() {
          _lastImagePath = image.path;
        });

        // 반려동물 없이 분석하는 경우 petId를 null로 전달
        context.read<EmotionAnalysisBloc>().add(
              AnalyzeEmotionRequested(
                imagePath: image.path,
                petId: _analyzeWithoutPet ? null : _selectedPet?.id,
              ),
            );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')),
      );
    }
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
            Text(
              '가능한 원인:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
            ),
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
              if (_lastImagePath != null && _selectedPet != null) {
                // 재시도
                context.read<EmotionAnalysisBloc>().add(
                      AnalyzeEmotionRequested(
                        imagePath: _lastImagePath!,
                        petId: _selectedPet!.id,
                      ),
                    );
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
