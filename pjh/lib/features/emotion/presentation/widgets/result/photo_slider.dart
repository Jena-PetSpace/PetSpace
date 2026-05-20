import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theme/emotion_result_tokens.dart';
import 'fullscreen_photo_viewer.dart';

/// 결과 페이지 상단 사진 슬라이더.
/// - 5장(혹은 N장) 좌우 스와이프
/// - 우상단 카운터 (1 / N)
/// - 하단 인디케이터 (현재 16x4, 나머지 4x4)
/// - 1장이면 카운터/화살표/인디케이터 모두 숨김
/// - 사진 탭 → FullscreenPhotoViewer
class PhotoSlider extends StatefulWidget {
  final List<String> imagePaths;
  final double height;

  const PhotoSlider({
    super.key,
    required this.imagePaths,
    this.height = 220,
  });

  @override
  State<PhotoSlider> createState() => _PhotoSliderState();
}

class _PhotoSliderState extends State<PhotoSlider> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isNetwork(String path) => path.startsWith('http');

  void _openFullscreen() {
    FullscreenPhotoViewer.open(
      context,
      imagePaths: widget.imagePaths,
      initialIndex: _index,
    );
  }

  Widget _buildImage(String path, double heightPx) {
    final fallback = ColoredBox(
      color: EmotionResultTokens.grayBar,
      child: Center(
        child: Icon(Icons.image_not_supported_outlined,
            size: 40.r, color: EmotionResultTokens.grayInactive),
      ),
    );

    if (_isNetwork(path)) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        // 펫 사진은 얼굴이 상단에 있는 구도가 많아 상단 우선 노출 (귀·눈 잘림 방지)
        alignment: Alignment.topCenter,
        width: double.infinity,
        height: heightPx,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return ColoredBox(
            color: EmotionResultTokens.grayBar,
            child: Center(
              child: SizedBox(
                width: 28.r,
                height: 28.r,
                child: const CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      width: double.infinity,
      height: heightPx,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  Widget _buildEmpty() => ColoredBox(
        color: EmotionResultTokens.grayBar,
        child: Center(
          child: Icon(Icons.photo_library_outlined,
              size: 40.r, color: EmotionResultTokens.grayInactive),
        ),
      );

  Widget _buildCounter() {
    return Positioned(
      top: 10.h,
      right: 12.w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_outlined, size: 12.r, color: Colors.white),
            SizedBox(width: 4.w),
            Text(
              '${_index + 1} / ${widget.imagePaths.length}',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator() {
    return Positioned(
      bottom: 10.h,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.imagePaths.length, (i) {
          final active = i == _index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.symmetric(horizontal: 3.w),
            width: active ? 16.w : 4.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2.r),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildArrow({required bool left}) {
    final visible = left ? _index > 0 : _index < widget.imagePaths.length - 1;
    if (!visible) return const SizedBox.shrink();
    return Positioned(
      left: left ? 8.w : null,
      right: left ? null : 8.w,
      top: 0,
      bottom: 0,
      child: Center(
        child: Material(
          color: Colors.white.withValues(alpha: 0.85),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              final target = left ? _index - 1 : _index + 1;
              _controller.animateToPage(
                target,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            },
            child: SizedBox(
              width: 32.r,
              height: 32.r,
              child: Icon(
                left ? Icons.chevron_left : Icons.chevron_right,
                size: 22.r,
                color: EmotionResultTokens.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heightPx = widget.height.h;
    if (widget.imagePaths.isEmpty) {
      return SizedBox(height: heightPx, child: _buildEmpty());
    }

    final showChrome = widget.imagePaths.length > 1;

    return SizedBox(
      height: heightPx,
      child: Stack(
        children: [
          GestureDetector(
            onTap: _openFullscreen,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.imagePaths.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _buildImage(widget.imagePaths[i], heightPx),
            ),
          ),
          if (showChrome) ...[
            _buildArrow(left: true),
            _buildArrow(left: false),
            _buildCounter(),
            _buildIndicator(),
          ],
        ],
      ),
    );
  }
}
