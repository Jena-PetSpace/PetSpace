import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../shared/themes/app_theme.dart';

class AnalysisGuidePage extends StatelessWidget {
  final bool isEmotion;
  final String? area;
  final Function(List<String>) onImagesSelected;

  const AnalysisGuidePage({
    super.key,
    required this.isEmotion,
    this.area,
    required this.onImagesSelected,
  });

  String get _title => isEmotion ? '감정 분석 촬영 가이드' : '${area ?? ''} 촬영 가이드';

  List<_GuideItem> get _items =>
      isEmotion ? _emotionItems : _healthItems(area ?? '');

  static const List<_GuideItem> _emotionItems = [
    _GuideItem(isOk: true, text: '얼굴 전체가 화면 안에 들어오게'),
    _GuideItem(isOk: true, text: '밝은 자연광 아래에서 촬영'),
    _GuideItem(isOk: true, text: '정면 또는 약간 측면 각도'),
    _GuideItem(isOk: true, text: '눈이 뜨인 상태, 표정이 자연스러울 때'),
    _GuideItem(isOk: false, text: '역광 및 플래시 금지'),
    _GuideItem(isOk: false, text: '너무 멀리서 찍으면 인식 어려움'),
    _GuideItem(isOk: false, text: '필터·보정 사진은 정확도 저하'),
  ];

  static List<_GuideItem> _healthItems(String area) {
    switch (area) {
      case '눈·귀':
        return const [
          _GuideItem(isOk: true, text: '눈 클로즈업, 자연광 아래'),
          _GuideItem(isOk: true, text: '눈물색·분비물이 잘 보이게'),
          _GuideItem(isOk: true, text: '귀 안쪽도 함께 촬영하면 정확도 향상'),
          _GuideItem(isOk: false, text: '플래시 사용 금지 (반사)'),
          _GuideItem(isOk: false, text: '너무 어두운 환경 금지'),
        ];
      case '코·입':
        return const [
          _GuideItem(isOk: true, text: '코 정면 + 입 살짝 벌린 상태'),
          _GuideItem(isOk: true, text: '잇몸 색이 보이도록 가까이'),
          _GuideItem(isOk: true, text: '코 분비물·색 변화 부위 중심으로'),
          _GuideItem(isOk: false, text: '너무 멀리서 찍으면 인식 불가'),
          _GuideItem(isOk: false, text: '움직일 때 찍으면 흔들림 주의'),
        ];
      case '피부·털':
        return const [
          _GuideItem(isOk: true, text: '털을 살짝 벌려 피부가 보이게'),
          _GuideItem(isOk: true, text: '발진·탈모 부위를 중심으로'),
          _GuideItem(isOk: true, text: '여러 각도 사진을 함께 추가하면 정확도 향상'),
          _GuideItem(isOk: false, text: '필터·역광 사용 금지'),
          _GuideItem(isOk: false, text: '털이 가려 피부가 안 보이면 인식 어려움'),
        ];
      case '체형(BCS)':
        return const [
          _GuideItem(isOk: true, text: '서 있는 자세 측면 전신'),
          _GuideItem(isOk: true, text: '위에서 내려다본 사진도 추가'),
          _GuideItem(isOk: true, text: '밝은 배경에서 전체 실루엣이 보이게'),
          _GuideItem(isOk: false, text: '앉거나 누워 있으면 정확도 낮음'),
          _GuideItem(isOk: false, text: '몸이 잘린 사진은 분석 불가'),
        ];
      case '자세·체형 대칭':
        return const [
          _GuideItem(isOk: true, text: '뒤에서 본 전신, 다리 4개 보이게'),
          _GuideItem(isOk: true, text: '정면 전신 사진도 함께 추가'),
          _GuideItem(isOk: true, text: '바닥이 평평한 곳에서 촬영'),
          _GuideItem(isOk: false, text: '측면만 찍으면 대칭 분석 불가'),
          _GuideItem(isOk: false, text: '어두운 환경 금지'),
        ];
      default:
        return const [
          _GuideItem(isOk: true, text: '밝은 곳에서 정면 전신 촬영'),
          _GuideItem(isOk: true, text: '여러 각도 사진을 함께 추가'),
          _GuideItem(isOk: false, text: '너무 어두운 환경 금지'),
        ];
    }
  }

  IconData _areaIcon() {
    if (isEmotion) return Icons.pets;
    switch (area) {
      case '눈·귀':         return Icons.visibility_outlined;
      case '코·입':         return Icons.face_outlined;
      case '피부·털':        return Icons.texture;
      case '체형(BCS)':    return Icons.monitor_weight_outlined;
      case '자세·체형 대칭': return Icons.accessibility_new_outlined;
      default:             return Icons.health_and_safety_outlined;
    }
  }

  String get _introText {
    if (isEmotion) {
      return 'AI가 반려동물의 표정·자세를 분석해 감정 상태를 읽어냅니다. '
          '선명하고 가까운 사진일수록 정확도가 높아져요. 최대 5장까지 업로드할 수 있습니다.';
    }
    switch (area) {
      case '눈·귀':
        return '눈 분비물·충혈·귀 상태를 분석합니다. 클로즈업 사진이 핵심이에요.';
      case '코·입':
        return '코 건조함·분비물과 잇몸 색을 분석합니다. 정면 가까이 촬영해주세요.';
      case '피부·털':
        return '발진·탈모·피부 상태를 분석합니다. 털을 살짝 벌려 피부가 보이게 해주세요.';
      case '체형(BCS)':
        return '체형 점수(BCS)로 과체중/저체중 여부를 분석합니다. 전신이 보이는 측면 사진이 필요합니다.';
      case '자세·체형 대칭':
        return '척추·사지 대칭 여부를 분석합니다. 정면·후면 전신 사진을 함께 올려주세요.';
      default:
        return '정확한 분석을 위해 아래 가이드를 따라 촬영해주세요.';
    }
  }

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    List<String> paths = [];
    if (source == ImageSource.camera) {
      final x = await picker.pickImage(source: source, imageQuality: 85);
      if (x != null) paths = [x.path];
    } else {
      final xs = await picker.pickMultiImage(imageQuality: 85);
      paths = xs.map((x) => x.path).toList();
    }
    if (paths.isNotEmpty && context.mounted) {
      Navigator.pop(context);
      onImagesSelected(paths);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _title,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 아이콘 + 도입부
              Center(
                child: Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  child: Icon(
                    _areaIcon(),
                    size: 36.w,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Center(
                child: Text(
                  isEmotion
                      ? '얼굴이 잘 보이게 촬영해주세요'
                      : '${area ?? ''} — 아래 가이드대로 촬영해주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              // 도입부 설명
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  _introText,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.secondaryTextColor,
                    height: 1.55,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              // 가이드 항목
              Expanded(
                child: ListView(
                  children: [
                    ..._items.map((item) => Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22.w,
                                height: 22.w,
                                decoration: BoxDecoration(
                                  color: item.isOk
                                      ? AppTheme.successColor
                                      : AppTheme.errorColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  item.isOk ? Icons.check : Icons.close,
                                  size: 13.w,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Text(
                                  item.text,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: AppTheme.primaryTextColor,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    SizedBox(height: 12.h),
                    // 면책 문구
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 14.w, color: Colors.grey[500]),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              'AI 분석 결과는 참고용이며 수의사의 진단을 대체하지 않습니다. '
                              '이상 징후가 지속되면 동물병원을 방문해주세요.',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: Colors.grey[500],
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              // 카메라 / 갤러리 버튼
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pick(context, ImageSource.camera),
                      icon: Icon(Icons.camera_alt_outlined, size: 16.w),
                      label: Text(
                        '카메라',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6F61),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 13.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pick(context, ImageSource.gallery),
                      icon: Icon(Icons.photo_library_outlined, size: 16.w),
                      label: Text(
                        '갤러리',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 13.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideItem {
  final bool isOk;
  final String text;
  const _GuideItem({required this.isOk, required this.text});
}
