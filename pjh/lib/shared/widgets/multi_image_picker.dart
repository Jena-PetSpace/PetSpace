import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../themes/app_theme.dart';

class MultiImagePicker extends StatelessWidget {
  final List<File> images;
  final ValueChanged<List<File>> onChanged;
  final int maxImages;

  const MultiImagePicker({
    super.key,
    required this.images,
    required this.onChanged,
    this.maxImages = 10,
  });

  Future<void> _pickImages(BuildContext context) async {
    final remaining = maxImages - images.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최대 $maxImages장까지 선택할 수 있습니다')),
      );
      return;
    }

    final source = await _showSourceSheet(context);
    if (source == null) return;

    final picker = ImagePicker();
    List<XFile> picked = [];

    if (source == ImageSource.camera) {
      final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (file != null) picked = [file];
    } else {
      picked = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
        limit: remaining,
      );
    }

    if (picked.isEmpty) return;
    final newImages = [...images, ...picked.map((x) => File(x.path))];
    onChanged(newImages.take(maxImages).toList());
  }

  Future<ImageSource?> _showSourceSheet(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 8.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppTheme.neutral300,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 8.h),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('카메라로 촬영', style: TextStyle(fontSize: 15.sp)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('갤러리에서 선택', style: TextStyle(fontSize: 15.sp)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  void _removeImage(int index) {
    final updated = [...images]..removeAt(index);
    onChanged(updated);
  }

  void _reorderImage(int oldIndex, int newIndex) {
    final updated = [...images];
    if (newIndex > oldIndex) newIndex--;
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Semantics(
        label: '사진 추가하기, 최대 $maxImages장',
        button: true,
        child: Material(
          key: const Key('multi_image_picker_empty'),
          color: AppTheme.actionContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
          child: InkWell(
            onTap: () => _pickImages(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
            child: Container(
              height: math.max(132, 148.h).toDouble(),
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 36,
                    color: AppTheme.actionBase,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '사진 추가',
                    style: TextStyle(
                      color: AppTheme.brandDeep,
                      fontSize: AppTheme.fontBody.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    '최대 $maxImages장 · 사진만 지원',
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor,
                      fontSize: AppTheme.fontCaption.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: math.max(152, 188.h).toDouble(),
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        onReorder: _reorderImage,
        itemCount: images.length + (images.length < maxImages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == images.length) {
            return _AddButton(
              key: const ValueKey('add_btn'),
              onTap: () => _pickImages(context),
            );
          }

          return ReorderableDragStartListener(
            key: ValueKey(images[index].path),
            index: index,
            child: _ImageTile(
              file: images[index],
              index: index,
              isFirst: index == 0,
              onRemove: () => _removeImage(index),
            ),
          );
        },
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final File file;
  final int index;
  final bool isFirst;
  final VoidCallback onRemove;

  const _ImageTile({
    required this.file,
    required this.index,
    required this.isFirst,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160.w,
      margin: EdgeInsets.only(right: 8.w),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: Image.file(file, fit: BoxFit.cover),
          ),
          if (isFirst)
            Positioned(
              left: 6.w,
              bottom: 6.h,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  '대표',
                  style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          Positioned(
            right: 4.w,
            top: 4.h,
            child: Semantics(
              label: '${index + 1}번째 사진 삭제',
              button: true,
              child: SizedBox(
                width: 44,
                height: 44,
                child: IconButton.filled(
                  onPressed: onRemove,
                  tooltip: '사진 삭제',
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    minimumSize: const Size(36, 36),
                  ),
                  icon: const Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            left: 6.w,
            top: 6.h,
            child: Container(
              width: 20.w,
              height: 20.w,
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '사진 더 추가',
      button: true,
      child: Material(
        color: AppTheme.actionContainer,
        borderRadius: BorderRadius.circular(10.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            width: 88.w,
            margin: EdgeInsets.only(right: 4.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 28,
                  color: AppTheme.actionBase,
                ),
                SizedBox(height: 6.h),
                Text(
                  '사진 추가',
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    color: AppTheme.brandDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
