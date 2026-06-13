import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/emotion_analysis.dart';
import '../../domain/usecases/get_previous_analysis.dart';
import '../bloc/emotion_analysis_bloc.dart';
import '../widgets/pet_inline_dropdown.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_event.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import 'analysis_guide_page.dart';
import 'emotion_loading_page.dart';
import 'emotion_result_page.dart';
import 'health_loading_page.dart';
import 'health_result_page.dart';
import '../../data/models/health_analysis_model.dart';
import '../widgets/analysis_input/section_card.dart';
import '../widgets/analysis_input/guide_tip_row.dart';
import '../widgets/analysis_input/analysis_sub_tab.dart';
import '../widgets/analysis_input/health_area_chips.dart';
import '../widgets/analysis_input/image_grid_section.dart';
import '../widgets/analysis_input/additional_input_section.dart';

class EmotionAnalysisPage extends StatefulWidget {
  final String? initialPetId;
  final String? initialPetName;
  /// 진입 시 미리 선택할 서브탭. 0=감정분석(기본), 1=건강분석.
  final int initialTab;

  const EmotionAnalysisPage({
    super.key,
    this.initialPetId,
    this.initialPetName,
    this.initialTab = 0,
  });

  @override
  State<EmotionAnalysisPage> createState() => _EmotionAnalysisPageState();
}

// 품종 데이터
const Map<String, List<String>> _breedsByType = {
  'dog': [
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
  'cat': [
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

class _EmotionAnalysisPageState extends State<EmotionAnalysisPage> {
  Pet? _selectedPet;
  bool _analyzeWithoutPet = false;

  // 수동 종/품종 선택 (반려동물 미선택 시)
  String? _manualPetType; // 'dog' or 'cat'
  String? _manualBreed;   // 목록에서 선택한 품종 ('기타' 포함)
  final TextEditingController _breedCustomCtrl = TextEditingController();

  // 다중 이미지 경로 목록 (최대 5장)
  final List<String> _imagePaths = [];
  static const int _maxImages = 5;

  // 전체 화면 가이드 표시 여부
  bool _showFullGuide = false;

  // 서브탭: 0=감정분석, 1=건강분석. initState에서 widget.initialTab으로 덮어씀.
  int _tabIndex = 0;

  // 건강분석 선택 부위
  String _selectedArea = '종합(전체)';

  // 추가 입력란
  bool _showAdditionalInput = false;
  final TextEditingController _additionalCtrl = TextEditingController();


  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab.clamp(0, 1);
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<PetBloc>().add(LoadUserPets());
    }
    _checkFirstVisit();
  }

  @override
  void dispose() {
    _additionalCtrl.dispose();
    _breedCustomCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTip = prefs.getBool('has_seen_emotion_guide') ?? false;
    if (!hasSeenTip && mounted) {
      setState(() => _showFullGuide = true);
    }
  }

  Future<void> _dismissFullGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_emotion_guide', true);
    if (mounted) setState(() => _showFullGuide = false);
  }

  Widget _buildFullGuide() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0F4FF), Color(0xFFFEFAF6)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            children: [
              SizedBox(height: 60.h),

              // 아이콘
              Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.1),
                      AppTheme.primaryColor.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.pets,
                      size: 40.w,
                      color: AppTheme.primaryColor,
                    ),
                    Positioned(
                      right: 20.w,
                      top: 20.h,
                      child: Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.psychology,
                          size: 14.w,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32.h),

              // 제목
              Text(
                'AI 감정 분석',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'AI가 반려동물의 표정과 행동을 분석하여\n감정 상태를 알려드립니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppTheme.secondaryTextColor,
                  height: 1.5,
                ),
              ),

              SizedBox(height: 40.h),

              // 팁 카드
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '좋은 분석을 위한 팁',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    const GuideTipRow(
                      icon: Icons.face,
                      color: Colors.blue,
                      title: '얼굴이 선명하게',
                      subtitle: '반려동물의 얼굴이 잘 보이도록 촬영해주세요',
                    ),
                    SizedBox(height: 16.h),
                    const GuideTipRow(
                      icon: Icons.wb_sunny,
                      color: Colors.orange,
                      title: '충분한 조명',
                      subtitle: '밝은 곳에서 촬영하면 더 정확해요',
                    ),
                    SizedBox(height: 16.h),
                    const GuideTipRow(
                      icon: Icons.zoom_in,
                      color: Colors.green,
                      title: '가까운 거리에서',
                      subtitle: '너무 멀리서 찍지 마시고 가까이서 촬영해주세요',
                    ),
                    SizedBox(height: 16.h),
                    const GuideTipRow(
                      icon: Icons.crop_free,
                      color: Colors.red,
                      title: '깔끔한 배경',
                      subtitle: '배경이 복잡하지 않은 곳에서 촬영해주세요',
                    ),
                  ],
                ),
              ),

              SizedBox(height: 40.h),

              // 분석 시작하기 버튼
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: _dismissFullGuide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    '분석 시작하기',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
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
      } catch (e) {
        log('[EmotionAnalysis] 초기 펫 선택 실패: $e', name: 'EmotionAnalysis');
      }
    }
  }

  bool get _canAnalyze =>
      (_selectedPet != null || _analyzeWithoutPet) && _imagePaths.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // 첫 방문 → 사용 팁 가이드
    if (_showFullGuide) {
      return Scaffold(
        body: _buildFullGuide(),
      );
    }

    return BlocListener<EmotionAnalysisBloc, EmotionAnalysisState>(
      listener: (context, state) {
        if (state is EmotionAnalysisError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('분석 실패: ${state.message}'),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('AI 분석'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, size: 22.w, color: AppTheme.primaryColor),
            tooltip: '촬영 가이드',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnalysisGuidePage(
                    isEmotion: _tabIndex == 0,
                    area: _tabIndex == 1 ? _selectedArea : null,
                    onImagesSelected: (paths) {
                      setState(() {
                        _imagePaths.clear();
                        _imagePaths.addAll(paths.take(_maxImages));
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(68.h),
          child: Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0F4),
                borderRadius: BorderRadius.circular(30.r),
              ),
              padding: EdgeInsets.all(3.w),
              child: Row(
                children: [
                  AnalysisSubTab(
                    label: '감정 분석',
                    index: 0,
                    currentIndex: _tabIndex,
                    onSelected: (i) {
                      setState(() {
                        _tabIndex = i;
                        _additionalCtrl.clear();
                        _showAdditionalInput = false;
                        _imagePaths.clear();
                      });
                    },
                  ),
                  AnalysisSubTab(
                    label: '건강 분석',
                    index: 1,
                    currentIndex: _tabIndex,
                    onSelected: (i) {
                      setState(() {
                        _tabIndex = i;
                        _additionalCtrl.clear();
                        _showAdditionalInput = false;
                        _imagePaths.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: BlocBuilder<PetBloc, PetState>(
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
                PetInlineDropdown(
                  pets: userPets,
                  selectedPet: _selectedPet,
                  showUnregistered: _analyzeWithoutPet,
                  onPetSelected: (Pet? pet) {
                    setState(() {
                      _selectedPet = pet;
                      _analyzeWithoutPet = false;
                    });
                  },
                  onUnregisteredChanged: (bool value) {
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

                // 수동 종/품종 선택 (반려동물 미선택 시)
                if (_analyzeWithoutPet) ...[
                  SizedBox(height: 12.h),
                  SectionCard(child: _buildManualBreedSelector()),
                ],

                SizedBox(height: 16.h),

                // 건강분석 탭일 때: 부위 칩 선택
                if (_tabIndex == 1) ...[
                  SectionCard(
                    child: HealthAreaChips(
                      selectedArea: _selectedArea,
                      onSelected: (area) => setState(() => _selectedArea = area),
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],

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
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: _imagePaths.length >= _maxImages
                            ? AppTheme.highlightColor
                            : AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        '${_imagePaths.length} / $_maxImages',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
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
                ImageGridSection(
                  imagePaths: _imagePaths,
                  maxImages: _maxImages,
                  onAddTapped: _requestPermissionsAndOpenGuide,
                  onRemove: (index) =>
                      setState(() => _imagePaths.removeAt(index)),
                ),

                SizedBox(height: 16.h),

                // 추가 입력란 (감정/건강 공통)
                SectionCard(
                  child: AdditionalInputSection(
                    controller: _additionalCtrl,
                    expanded: _showAdditionalInput,
                    onToggle: (v) => setState(() => _showAdditionalInput = v),
                  ),
                ),

                SizedBox(height: 24.h),

                // 분석 시작 버튼
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
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
                    child: Text(
                      _analyzeButtonText,
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
      ),
      ), // Scaffold
    ); // BlocListener
  }

  // 사진 그리드 (선택된 사진들 + 빈 슬롯 힌트)
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
          Autocomplete<String>(
            key: ValueKey('breed_${_manualPetType}_$_manualBreed'),
            initialValue: TextEditingValue(
              text: (_manualBreed != null && _manualBreed != '기타') ? _manualBreed! : '',
            ),
            optionsBuilder: (textEditingValue) {
              final query = textEditingValue.text.trim();
              if (query.isEmpty) return breeds;
              return breeds.where(
                (b) => b.contains(query),
              );
            },
            displayStringForOption: (b) => b,
            onSelected: (value) {
              setState(() {
                _manualBreed = value;
                _breedCustomCtrl.clear();
              });
              FocusScope.of(context).unfocus();
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: TextStyle(fontSize: 13.sp),
                decoration: InputDecoration(
                  labelText: '품종',
                  labelStyle: TextStyle(fontSize: 13.sp),
                  hintText: '입력하여 검색하거나 목록에서 선택',
                  hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  isDense: true,
                  suffixIcon: _manualBreed != null
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 16.w, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _manualBreed = null;
                              _breedCustomCtrl.clear();
                            });
                            controller.clear();
                          },
                        )
                      : Icon(Icons.arrow_drop_down, size: 20.w, color: Colors.grey),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 64.w,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(10.r),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 200.h),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          final isSelected = _manualBreed == option;
                          return GestureDetector(
                            onTap: () => onSelected(option),
                            child: Container(
                              width: double.infinity,
                              color: isSelected
                                  ? AppTheme.primaryColor.withValues(alpha: 0.08)
                                  : Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 13.h),
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : AppTheme.primaryTextColor,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (_manualBreed == '기타') ...[
            SizedBox(height: 8.h),
            TextField(
              controller: _breedCustomCtrl,
              style: TextStyle(fontSize: 13.sp),
              decoration: InputDecoration(
                labelText: '품종 직접 입력',
                labelStyle: TextStyle(fontSize: 13.sp),
                hintText: '예: 비숑프리제',
                hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w, vertical: 10.h),
                isDense: true,
              ),
            ),
          ],
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
          _breedCustomCtrl.clear();
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
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
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

  // ── 분석 버튼 텍스트 ──────────────────────────────────────────
  String get _analyzeButtonText {
    if (_imagePaths.isEmpty) return '분석 시작하기';
    if (_tabIndex == 0) return '분석 시작하기';
    return '분석 시작하기';
  }

  void _showPetNotSelectedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('반려동물을 먼저 선택해주세요 🐾'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// OS 권한 팝업을 띄우고, 허용된 경우에만 가이드 페이지로 이동
  Future<void> _requestPermissionsAndOpenGuide() async {
    if (!(_selectedPet != null || _analyzeWithoutPet)) {
      _showPetNotSelectedSnackBar();
      return;
    }

    // 카메라 권한 요청
    final cameraStatus = await Permission.camera.request();
    if (!mounted) return;

    if (cameraStatus.isPermanentlyDenied) {
      _showGoToSettingsSnackBar();
      return;
    }

    // 카메라 거부 시 중단
    if (!cameraStatus.isGranted) return;

    // 사진 권한 요청 (Android 13+ = photos, 이하 = storage)
    PermissionStatus photosStatus = await Permission.photos.request();
    if (!mounted) return;

    // Android 12 이하: photos가 denied여도 storage로 재시도
    if (!photosStatus.isGranted) {
      photosStatus = await Permission.storage.request();
      if (!mounted) return;
    }

    if (photosStatus.isPermanentlyDenied) {
      _showGoToSettingsSnackBar();
      return;
    }

    // 사진 권한도 없으면 중단 (거부만 한 경우 — 다음 탭에서 재요청 가능)
    if (!photosStatus.isGranted) return;

    await _openGuide();
  }

  void _showGoToSettingsSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('설정 > 앱 > PetSpace에서 카메라·사진 권한을 허용해주세요'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: '설정 열기',
          textColor: Colors.white,
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  Future<void> _openGuide() async {
    if (!(_selectedPet != null || _analyzeWithoutPet)) {
      _showPetNotSelectedSnackBar();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalysisGuidePage(
          isEmotion: _tabIndex == 0,
          area: _tabIndex == 1 ? _selectedArea : null,
          onImagesSelected: (paths) {
            final remaining = _maxImages - _imagePaths.length;
            final addable = paths.take(remaining).toList();
            setState(() => _imagePaths.addAll(addable));
            if (paths.length > remaining) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '사진은 최대 $_maxImages장까지 추가할 수 있어요. ${addable.length}장만 추가됐습니다.',
                  ),
                  backgroundColor: AppTheme.primaryColor,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
        ),
      ),
    );
    // 복귀 후 breed Autocomplete 재빌드
    if (mounted) setState(() {});
  }

  void _startAnalysis() {
    final petName   = _selectedPet?.name;
    final petType   = _selectedPet?.type.name ?? _manualPetType;
    final breed     = _selectedPet?.breed ??
        (_manualBreed == '기타'
            ? (_breedCustomCtrl.text.trim().isNotEmpty ? _breedCustomCtrl.text.trim() : null)
            : _manualBreed);
    final petAge    = _selectedPet?.displayAge;
    final petGender = _selectedPet?.genderDisplayName;
    final additional = _additionalCtrl.text.trim().isEmpty
        ? null
        : _additionalCtrl.text.trim();

    if (_tabIndex == 1) {
      // 건강분석
      _startHealthAnalysis(
        petName: petName,
        petType: petType,
        breed: breed,
        age: petAge,
        gender: petGender,
        additionalContext: additional,
      );
      return;
    }

    _runEmotionAnalysis(
      petType: petType,
      breed: breed,
      contextNote: additional,
    );
  }

  /// 감정분석: rootNavigator로 로딩 페이지 push → 풀스크린(하단 네비바 가림).
  /// 로딩 페이지가 결과/에러를 pop으로 반환하면 ShellRoute 내부 navigator에 결과
  /// 페이지를 push (결과 화면에서는 네비바 표시).
  ///
  /// [contextNote]: 사용자가 "추가 정보 입력 (선택)"에 적은 맥락. AI 프롬프트
  /// 주입 + 결과 ContextCard 노출용. null/빈 문자열이면 기존 동작과 동일.
  Future<void> _runEmotionAnalysis({
    String? petType,
    String? breed,
    String? contextNote,
  }) async {
    final bloc = context.read<EmotionAnalysisBloc>();
    final imagePathsCopy = List<String>.from(_imagePaths);
    final event = AnalyzeEmotionRequested(
      imagePaths: List.from(_imagePaths),
      petId: _analyzeWithoutPet ? null : _selectedPet?.id,
      petType: petType,
      breed: breed,
      contextNote: contextNote,
    );

    final result = await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: EmotionLoadingPage(
            imagePaths: imagePathsCopy,
            event: event,
          ),
        ),
      ),
    );

    if (!mounted) return;

    if (result is EmotionAnalysisSuccess) {
      final analysis = result.analysis;
      // 직전 분석 1건 조회. 비교 UI는 부가 기능이므로 화면 전환을 막지 않도록
      // 300ms 타임아웃 — 느리거나 실패하면 즉시 null로 진행.
      EmotionAnalysis? previous;
      try {
        previous = await sl<GetPreviousAnalysis>()(current: analysis)
            .timeout(const Duration(milliseconds: 300));
      } catch (_) {
        previous = null;
      }
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: bloc,
            child: EmotionResultPage(
              analysis: analysis,
              imagePaths: imagePathsCopy,
              previousAnalysis: previous,
            ),
          ),
        ),
      );
    } else if (result is EmotionAnalysisError) {
      _showErrorDialog(result.message);
    }
  }

  /// 건강분석: rootNavigator로 로딩 페이지 push (풀스크린).
  /// 성공 시 ShellRoute 내부에 HealthResultPage push (네비바 표시).
  /// 실패 시 에러 다이얼로그.
  Future<void> _startHealthAnalysis({
    String? petName,
    String? petType,
    String? breed,
    String? age,
    String? gender,
    String? additionalContext,
  }) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final result = await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => HealthLoadingPage(
          imagePaths: List.from(_imagePaths),
          selectedArea: _selectedArea,
          userId: authState.user.uid,
          petId: _selectedPet?.id,
          petName: petName,
          petType: petType,
          breed: breed,
          age: age,
          gender: gender,
          additionalContext: additionalContext,
        ),
      ),
    );

    if (!mounted) return;

    if (result is HealthAnalysisModel) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HealthResultPage(result: result),
        ),
      );
    } else if (result is String) {
      _showErrorDialog(result);
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
            Text('가능한 원인:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp)),
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
