import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/post.dart';

class CreatePostBottomSheet extends StatefulWidget {
  final String currentUserId;
  final Function(Post) onPostCreated;

  const CreatePostBottomSheet({
    super.key,
    required this.currentUserId,
    required this.onPostCreated,
  });

  @override
  State<CreatePostBottomSheet> createState() => _CreatePostBottomSheetState();
}

class _CreatePostBottomSheetState extends State<CreatePostBottomSheet> {
  final TextEditingController _contentController = TextEditingController();
  final List<File> _selectedImages = [];
  PostType _postType = PostType.text;
  bool _isPublic = true;
  String? _location;

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
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContentInput(),
                    SizedBox(height: 16.h),
                    if (_selectedImages.isNotEmpty) _buildSelectedImages(),
                    _buildPostTypeSelector(),
                    SizedBox(height: 16.h),
                    _buildPostOptions(),
                    SizedBox(height: 24.h),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.close, size: 24.w),
          ),
          Expanded(
            child: Center(
              child: Text(
                '게시물 작성',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: _createPost,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                '게시',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentInput() {
    return TextField(
      controller: _contentController,
      maxLines: null,
      decoration: InputDecoration(
        hintText: '무엇을 공유하고 싶나요?',
        border: InputBorder.none,
        hintStyle: TextStyle(
          fontSize: 16.sp,
          color: Colors.grey,
        ),
      ),
      style: TextStyle(fontSize: 16.sp),
    );
  }

  Widget _buildSelectedImages() {
    return SizedBox(
      height: 100.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              Container(
                width: 100.w,
                height: 100.h,
                margin: EdgeInsets.only(right: 8.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  image: DecorationImage(
                    image: FileImage(_selectedImages[index]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: 4.h,
                right: 12.w,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(4.w),
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16.w,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPostTypeSelector() {
    return Row(
      children: [
        _buildPostTypeOption(
          icon: Icons.text_fields,
          label: '텍스트',
          type: PostType.text,
        ),
        SizedBox(width: 16.w),
        _buildPostTypeOption(
          icon: Icons.image,
          label: '이미지',
          type: PostType.image,
          onTap: _pickImages,
        ),
        SizedBox(width: 16.w),
        _buildPostTypeOption(
          icon: Icons.psychology,
          label: '감정 분석',
          type: PostType.emotionAnalysis,
          onTap: _attachEmotionAnalysis,
        ),
      ],
    );
  }

  Widget _buildPostTypeOption({
    required IconData icon,
    required String label,
    required PostType type,
    VoidCallback? onTap,
  }) {
    final isSelected = _postType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _postType = type);
        onTap?.call();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color:
              isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : null,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16.w,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
            ),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: isSelected ? AppTheme.primaryColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('공개 게시물'),
          subtitle: Text(_isPublic ? '모든 사용자가 볼 수 있습니다' : '팔로워만 볼 수 있습니다'),
          value: _isPublic,
          onChanged: (value) => setState(() => _isPublic = value),
        ),
        ListTile(
          leading: const Icon(Icons.location_on),
          title: Text(_location ?? '위치 추가'),
          subtitle: _location != null ? null : const Text('현재 위치를 추가하세요'),
          onTap: _addLocation,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(fontSize: 14.sp)),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: ElevatedButton(
            onPressed: _createPost,
            child: Text('게시하기', style: TextStyle(fontSize: 14.sp)),
          ),
        ),
      ],
    );
  }

  void _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((image) => File(image.path)));
        _postType = PostType.image;
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (_selectedImages.isEmpty) {
        _postType = PostType.text;
      }
    });
  }

  void _attachEmotionAnalysis() {
    // Navigate to emotion analysis or show selection dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('감정 분석 연결'),
        content: const Text('감정 분석 결과를 게시물에 연결하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle emotion analysis attachment
            },
            child: const Text('연결'),
          ),
        ],
      ),
    );
  }

  void _addLocation() {
    showDialog(
      context: context,
      builder: (context) {
        final locationController = TextEditingController(text: _location);
        return AlertDialog(
          title: const Text('위치 추가'),
          content: TextField(
            controller: locationController,
            decoration: const InputDecoration(
              hintText: '위치를 입력하세요',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _location = locationController.text.trim();
                  if (_location!.isEmpty) _location = null;
                });
                Navigator.pop(context);
              },
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
  }

  void _createPost() {
    final content = _contentController.text.trim();

    if (content.isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력하거나 이미지를 추가해주세요.')),
      );
      return;
    }

    final post = Post(
      id: '', // Will be generated by repository
      authorId: widget.currentUserId,
      authorName: 'Current User', // Should get from auth
      type: _postType,
      content: content.isNotEmpty ? content : null,
      imageUrls: const [], // Will be populated after upload
      createdAt: DateTime.now(),
      isPublic: _isPublic,
      location: _location,
    );

    widget.onPostCreated(post);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}
