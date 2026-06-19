import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../shared/themes/app_theme.dart';

/// 분석 입력 화면의 이미지 그리드.
/// - 비어 있으면 "사진을 탭해서 추가하세요" 빈 슬롯
/// - 있으면 3열 GridView + (여유 시) 추가 슬롯 + 각 사진 X 삭제 + 첫 사진 "대표" 라벨
/// 상태(_imagePaths)·권한 흐름은 부모가 관리, 위젯은 표시·콜백 전달만.
class ImageGridSection extends StatelessWidget {
  final List<String> imagePaths;
  final int maxImages;
  final VoidCallback onAddTapped;
  final void Function(int index) onRemove;

  const ImageGridSection({
    super.key,
    required this.imagePaths,
    required this.maxImages,
    required this.onAddTapped,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) {
      return GestureDetector(
        onTap: onAddTapped,
        child: Container(
          width: double.infinity,
          height: 120.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: AppTheme.neutral200,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_photo_alternate_outlined,
                    size: 28.w, color: AppTheme.primaryColor.withValues(alpha: 0.6)),
              ),
              SizedBox(height: 10.h),
              Text(
                '사진을 탭해서 추가하세요',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppTheme.primaryColor.withValues(alpha: 0.7)),
              ),
              SizedBox(height: 4.h),
              Text(
                '최대 $maxImages장 · 많을수록 정확해요',
                style: TextStyle(fontSize: 10.sp, color: AppTheme.secondaryTextColor),
              ),
            ],
          ),
        ),
      );
    }

    final showAddSlot = imagePaths.length < maxImages;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.w,
        mainAxisSpacing: 8.w,
        childAspectRatio: 1,
      ),
      itemCount: imagePaths.length + (showAddSlot ? 1 : 0),
      itemBuilder: (context, index) {
        // 마지막 슬롯 = + 추가 버튼
        if (showAddSlot && index == imagePaths.length) {
          return GestureDetector(
            onTap: onAddTapped,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 26.w, color: AppTheme.primaryColor.withValues(alpha: 0.6)),
                  SizedBox(height: 4.h),
                  Text(
                    '추가',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppTheme.primaryColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10.r),
              child: Image.file(
                File(imagePaths[index]),
                fit: BoxFit.cover,
              ),
            ),
            // X 버튼
            Positioned(
              top: 4.h,
              right: 4.w,
              child: GestureDetector(
                onTap: () => onRemove(index),
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
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    '대표',
                    style: TextStyle(fontSize: 9.sp, color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
