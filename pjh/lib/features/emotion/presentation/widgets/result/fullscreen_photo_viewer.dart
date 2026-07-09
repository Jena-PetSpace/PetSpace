// v2-review: 사진 뷰어 전용 근흑색 배경 — 기능적 색상, 치환 보류.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 사진 풀스크린 뷰어. 좌우 스와이프 + 핀치 줌. 어둡고 단순.
class FullscreenPhotoViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const FullscreenPhotoViewer({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
  });

  static Future<void> open(
    BuildContext context, {
    required List<String> imagePaths,
    int initialIndex = 0,
  }) {
    if (imagePaths.isEmpty) return Future.value();
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullscreenPhotoViewer(
          imagePaths: imagePaths,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  State<FullscreenPhotoViewer> createState() => _FullscreenPhotoViewerState();
}

class _FullscreenPhotoViewerState extends State<FullscreenPhotoViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imagePaths.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isNetwork(String path) => path.startsWith('http');

  Widget _buildImage(String path) {
    if (_isNetwork(path)) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const Center(
                child: CircularProgressIndicator(color: Colors.white)),
        errorBuilder: (_, __, ___) => Center(
          child: Icon(Icons.image_not_supported_outlined,
              color: Colors.white54, size: 48.r),
        ),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: Colors.white54, size: 48.r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showCount = widget.imagePaths.length > 1;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.imagePaths.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(child: _buildImage(widget.imagePaths[i])),
              ),
            ),
            // 상단 닫기 + 카운터
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (showCount)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '${_index + 1} / ${widget.imagePaths.length}',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    const Spacer(),
                    SizedBox(width: 48.w),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
