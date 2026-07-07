import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../shared/themes/app_theme.dart';
import '../constants/capture_guide_content.dart';
import 'guided_camera_page.dart';

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

  CaptureGuideContent get _content => CaptureGuideContent.of(
        CaptureGuideType.fromArea(isEmotion: isEmotion, area: area),
      );

  Future<void> _pick(BuildContext context, ImageSource source) async {
    List<String> paths = [];
    if (source == ImageSource.camera) {
      // Phase 2: 오버레이 가이드 커스텀 카메라 (갤러리 경로는 무변경)
      // rootNavigator — ShellRoute 밖에 띄워 하단 탭바를 가린다
      // (emotion_loading_page와 동일 패턴)
      final path = await Navigator.of(context, rootNavigator: true).push<String?>(
        MaterialPageRoute(
          builder: (_) => GuidedCameraPage(
            type: CaptureGuideType.fromArea(isEmotion: isEmotion, area: area),
          ),
        ),
      );
      if (path != null) paths = [path];
    } else {
      final xs = await ImagePicker().pickMultiImage(imageQuality: 85);
      paths = xs.map((x) => x.path).toList();
    }
    if (paths.isNotEmpty && context.mounted) {
      Navigator.pop(context);
      onImagesSelected(paths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
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
          content.title,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                children: [
                  // 헤더: 한 줄 핵심 요약
                  Text(
                    content.subtitle,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryTextColor,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // 좋은 예 섹션
                  const _SectionHeader(
                    icon: Icons.check_circle,
                    color: AppTheme.primaryColor,
                    label: '이렇게 촬영해주세요',
                  ),
                  SizedBox(height: 10.h),
                  _GoodExampleRow(examples: content.goodExamples),
                  SizedBox(height: 24.h),

                  // 나쁜 예 섹션
                  const _SectionHeader(
                    icon: Icons.cancel,
                    color: AppTheme.highlightColor,
                    label: '이런 촬영은 피해주세요',
                  ),
                  SizedBox(height: 10.h),
                  _BadExampleGrid(examples: content.badExamples),
                  SizedBox(height: 24.h),

                  // 체크리스트 섹션
                  const _SectionHeader(
                    icon: Icons.checklist_rounded,
                    color: AppTheme.primaryColor,
                    label: '촬영 전 체크리스트',
                  ),
                  SizedBox(height: 10.h),
                  ...content.checklist.asMap().entries.map(
                        (e) => _ChecklistRow(index: e.key + 1, text: e.value),
                      ),
                  SizedBox(height: 16.h),

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
            // 카메라 / 갤러리 버튼
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
              child: Row(
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
                        backgroundColor: AppTheme.highlightColor,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18.w, color: color),
        SizedBox(width: 6.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryTextColor,
          ),
        ),
      ],
    );
  }
}

/// 좋은 예: 1장이면 큰 카드 1개, 2장이면 가로 2분할.
class _GoodExampleRow extends StatelessWidget {
  final List<GuideExample> examples;

  const _GoodExampleRow({required this.examples});

  @override
  Widget build(BuildContext context) {
    if (examples.length == 1) {
      return _GoodExampleCard(example: examples.first, large: true);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < examples.length; i++) ...[
          if (i > 0) SizedBox(width: 10.w),
          Expanded(child: _GoodExampleCard(example: examples[i], large: false)),
        ],
      ],
    );
  }
}

class _GoodExampleCard extends StatelessWidget {
  final GuideExample example;
  final bool large;

  const _GoodExampleCard({required this.example, required this.large});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            _GuideImage(assetPath: example.assetPath),
            Positioned(
              top: 8.w,
              right: 8.w,
              child: _Badge(
                icon: Icons.check,
                color: AppTheme.primaryColor,
                size: large ? 26 : 22,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          example.caption,
          style: TextStyle(
            fontSize: large ? 12.sp : 11.sp,
            color: AppTheme.secondaryTextColor,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// 나쁜 예: 2~3장 가로 그리드, X 뱃지 + 실패 원인 캡션 오버레이.
class _BadExampleGrid extends StatelessWidget {
  final List<GuideExample> examples;

  const _BadExampleGrid({required this.examples});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < examples.length; i++) ...[
          if (i > 0) SizedBox(width: 8.w),
          Expanded(child: _BadExampleTile(example: examples[i])),
        ],
      ],
    );
  }
}

class _BadExampleTile extends StatelessWidget {
  final GuideExample example;

  const _BadExampleTile({required this.example});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _GuideImage(assetPath: example.assetPath),
        Positioned(
          top: 6.w,
          right: 6.w,
          child: const _Badge(
            icon: Icons.close,
            color: AppTheme.highlightColor,
            size: 20,
          ),
        ),
        // 실패 원인 캡션 오버레이
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(6.w, 12.h, 6.w, 6.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12.r)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
            child: Text(
              example.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuideImage extends StatelessWidget {
  final String assetPath;

  const _GuideImage({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          cacheWidth: 600,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade200,
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 28.w,
              color: Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _Badge({required this.icon, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Icon(icon, size: (size * 0.6).w, color: Colors.white),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final int index;
  final String text;

  const _ChecklistRow({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22.w,
            height: 22.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppTheme.primaryTextColor,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
