import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../social/domain/entities/post.dart';

class PostTypePickerSheet extends StatelessWidget {
  final PostType current;
  final bool hasEmotionAnalysis;

  const PostTypePickerSheet({
    super.key,
    required this.current,
    this.hasEmotionAnalysis = false,
  });

  static Future<PostType?> show(
    BuildContext context, {
    required PostType current,
    bool hasEmotionAnalysis = false,
  }) {
    return showModalBottomSheet<PostType>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => PostTypePickerSheet(
        current: current,
        hasEmotionAnalysis: hasEmotionAnalysis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      const _TypeItem(
        type: PostType.image,
        icon: Icons.photo_library_outlined,
        label: '사진 게시물',
        desc: '사진과 함께 일상을 공유해요',
      ),
      const _TypeItem(
        type: PostType.text,
        icon: Icons.chat_bubble_outline,
        label: '커뮤니티 글',
        desc: '텍스트로 이야기를 나눠요',
      ),
      if (hasEmotionAnalysis)
        const _TypeItem(
          type: PostType.emotionAnalysis,
          icon: Icons.psychology_outlined,
          label: '감정 분석 공유',
          desc: 'AI 감정 분석 결과를 함께 공유해요',
        ),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              '게시물 유형 선택',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 12.h),
            ...items.map((item) => _buildTile(context, item)),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, _TypeItem item) {
    final isSelected = current == item.type;
    return GestureDetector(
      onTap: () => Navigator.pop(context, item.type),
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.06)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : Colors.grey[200]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.12)
                    : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.icon,
                size: 20.w,
                color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.primaryTextColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    item.desc,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle,
                  size: 20.w, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}

class _TypeItem {
  final PostType type;
  final IconData icon;
  final String label;
  final String desc;

  const _TypeItem({
    required this.type,
    required this.icon,
    required this.label,
    required this.desc,
  });
}
