import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 로컬 파일 경로 또는 네트워크 URL 목록을 받아
/// 스와이프 가능한 갤러리 + 썸네일 네비게이션을 제공합니다.
///
/// - 1장이면 카운터/썸네일 영역 자동 숨김
/// - 최대 5장 지원
class MultiImageGalleryWidget extends StatefulWidget {
  final List<String> imagePaths;
  final double height;
  final BorderRadius? borderRadius;

  const MultiImageGalleryWidget({
    super.key,
    required this.imagePaths,
    this.height = 240,
    this.borderRadius,
  });

  @override
  State<MultiImageGalleryWidget> createState() =>
      _MultiImageGalleryWidgetState();
}

class _MultiImageGalleryWidgetState extends State<MultiImageGalleryWidget> {
  late final PageController _pageController;
  int _currentIndex = 0;

  List<String> get _paths => widget.imagePaths.take(5).toList();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isNetwork(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  Widget _buildImage(String path) {
    final radius = widget.borderRadius ?? BorderRadius.circular(16.r);
    if (_isNetwork(path)) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          path,
          width: double.infinity,
          height: widget.height.h,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return _placeholder();
          },
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.file(
        File(path),
        width: double.infinity,
        height: widget.height.h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: widget.height.h,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(16.r),
      ),
      child: Icon(Icons.image_not_supported_outlined,
          size: 40.w, color: Colors.grey.shade400),
    );
  }

  Widget _buildThumbnail(String path, int index) {
    final isSelected = index == _currentIndex;
    final thumb = _isNetwork(path)
        ? Image.network(path,
            width: 44.w, height: 44.w, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.image_not_supported_outlined, size: 20.w))
        : Image.file(File(path),
            width: 44.w, height: 44.w, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.image_not_supported_outlined, size: 20.w));

    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(index,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(horizontal: 3.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7.r),
          child: thumb,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paths = _paths;
    if (paths.isEmpty) return const SizedBox.shrink();

    final isSingle = paths.length == 1;

    return Column(
      children: [
        Stack(
          children: [
            // 메인 이미지 (PageView)
            SizedBox(
              height: widget.height.h,
              child: PageView.builder(
                controller: _pageController,
                itemCount: paths.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (_, i) => _buildImage(paths[i]),
              ),
            ),
            // 우상단 카운터 배지 (2장 이상일 때만)
            if (!isSingle)
              Positioned(
                top: 10.h,
                right: 10.w,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${paths.length}',
                    style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
        // 썸네일 스트립 (2장 이상일 때만)
        if (!isSingle) ...[
          SizedBox(height: 8.h),
          SizedBox(
            height: 44.w,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: paths.length,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemBuilder: (_, i) => _buildThumbnail(paths[i], i),
            ),
          ),
        ],
      ],
    );
  }
}
