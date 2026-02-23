import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../core/utils/hashtag_utils.dart';
import '../../domain/entities/post.dart';

class EditPostBottomSheet extends StatefulWidget {
  final Post post;
  final void Function(Post updatedPost) onSave;

  const EditPostBottomSheet({
    super.key,
    required this.post,
    required this.onSave,
  });

  @override
  State<EditPostBottomSheet> createState() => _EditPostBottomSheetState();
}

class _EditPostBottomSheetState extends State<EditPostBottomSheet> {
  late TextEditingController _contentController;
  late TextEditingController _hashtagController;
  late List<String> _hashtags;
  late bool _isPublic;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.post.content ?? '');
    _hashtagController = TextEditingController();
    _hashtags = List<String>.from(widget.post.tags);
    _isPublic = widget.post.isPublic;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              SizedBox(height: 20.h),

              // Content
              _buildContentField(),
              SizedBox(height: 16.h),

              // Hashtags
              _buildHashtagSection(),
              SizedBox(height: 16.h),

              // Privacy
              _buildPrivacySection(),
              SizedBox(height: 24.h),

              // Save Button
              _buildSaveButton(),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '게시물 수정',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTextColor,
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, size: 24.w),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildContentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '내용',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryTextColor,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _contentController,
          maxLines: 5,
          maxLength: 1000,
          style: TextStyle(fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: '게시물 내용을 입력하세요...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14.sp),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.all(16.w),
          ),
        ),
      ],
    );
  }

  Widget _buildHashtagSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '해시태그',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryTextColor,
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            ..._hashtags.map(
              (tag) => Chip(
                label: Text('#$tag', style: TextStyle(fontSize: 12.sp)),
                onDeleted: () {
                  setState(() {
                    _hashtags.remove(tag);
                  });
                },
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                labelStyle: TextStyle(color: AppTheme.primaryColor, fontSize: 12.sp),
                deleteIconColor: AppTheme.primaryColor,
              ),
            ),
            ActionChip(
              label: Text('+ 추가', style: TextStyle(fontSize: 12.sp)),
              onPressed: _showAddHashtagDialog,
              backgroundColor: Colors.grey[100],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(
            _isPublic ? Icons.public : Icons.lock,
            color: AppTheme.primaryColor,
            size: 20.w,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPublic ? '전체 공개' : '팔로워만',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _isPublic
                      ? '모든 사용자가 볼 수 있습니다'
                      : '나를 팔로우하는 사용자만 볼 수 있습니다',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isPublic,
            onChanged: (value) {
              setState(() {
                _isPublic = value;
              });
            },
            activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
            activeThumbColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _savePost,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 14.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.5),
        ),
        child: _isSaving
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                '저장',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  void _showAddHashtagDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('해시태그 추가', style: TextStyle(fontSize: 18.sp)),
        content: TextField(
          controller: _hashtagController,
          autofocus: true,
          style: TextStyle(fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: '해시태그 입력 (# 제외)',
            hintStyle: TextStyle(fontSize: 14.sp),
            prefixText: '#',
            prefixStyle: TextStyle(fontSize: 14.sp),
          ),
          onSubmitted: (value) {
            _addHashtag(value);
            Navigator.pop(dialogContext);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('취소', style: TextStyle(fontSize: 14.sp)),
          ),
          TextButton(
            onPressed: () {
              _addHashtag(_hashtagController.text);
              Navigator.pop(dialogContext);
            },
            child: Text('추가', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  void _addHashtag(String tag) {
    final trimmedTag = tag.trim().replaceAll('#', '');
    if (trimmedTag.isNotEmpty && !_hashtags.contains(trimmedTag)) {
      setState(() {
        _hashtags.add(trimmedTag);
      });
    }
    _hashtagController.clear();
  }

  void _savePost() {
    setState(() {
      _isSaving = true;
    });

    // 본문에서 해시태그 자동 추출
    final contentText = _contentController.text.trim();
    final extractedHashtags = HashtagUtils.extractHashtags(contentText);

    // 수동 추가 해시태그와 자동 추출 해시태그 병합 (중복 제거)
    final allHashtags = {..._hashtags, ...extractedHashtags}.toList();

    final updatedPost = widget.post.copyWith(
      content: contentText.isEmpty ? null : contentText,
      tags: allHashtags,
      isPublic: _isPublic,
      isPrivate: !_isPublic,
      updatedAt: DateTime.now(),
    );

    widget.onSave(updatedPost);
    Navigator.pop(context);
  }
}
