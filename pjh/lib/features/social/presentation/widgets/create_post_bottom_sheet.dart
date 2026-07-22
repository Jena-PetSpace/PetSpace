import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import '../../../../shared/widgets/image_source_picker.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../emotion/presentation/pages/ai_history_page.dart';
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
  String? _location;
  EmotionAnalysis? _attachedEmotion;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('legacy_create_post_sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContentInput(),
                    SizedBox(height: 16.h),
                    if (_selectedImages.isNotEmpty) _buildSelectedImages(),
                    if (_attachedEmotion != null) _buildAttachedEmotion(),
                    _buildPostTypeSelector(),
                    SizedBox(height: 16.h),
                    _buildPostOptions(),
                    SizedBox(height: 24.h),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: '닫기',
            icon: Icon(Icons.close, size: 24.w),
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
          TextButton(
            onPressed: _createPost,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppTheme.primaryColor,
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              shape: const StadiumBorder(),
            ),
            child: Text(
              '게시',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentInput() {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _contentController,
      maxLines: null,
      decoration: InputDecoration(
        hintText: '무엇을 공유하고 싶나요?',
        border: InputBorder.none,
        hintStyle: TextStyle(
          fontSize: 16.sp,
          color: colorScheme.onSurfaceVariant,
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
    return Wrap(
      spacing: 12.w,
      runSpacing: 8.h,
      children: [
        _buildPostTypeOption(
          icon: Icons.text_fields,
          label: '텍스트',
          type: PostType.text,
        ),
        _buildPostTypeOption(
          icon: Icons.image,
          label: '이미지',
          type: PostType.image,
          onTap: _pickImages,
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final foreground =
        isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return GestureDetector(
      onTap: () {
        setState(() => _postType = type);
        onTap?.call();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : null,
          border: Border.all(
            color:
                isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16.w,
              color: foreground,
            ),
            SizedBox(width: 4.w),
            Flexible(
              child: Text(
                label,
                softWrap: true,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: foreground,
                ),
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
        const ListTile(
          leading: Icon(Icons.public),
          title: Text('전체 공개'),
          subtitle: Text('이 작성 화면은 전체 공개 게시물만 지원합니다.'),
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

  Widget _buildAttachedEmotion() {
    final emotion = _attachedEmotion!;
    final colorScheme = Theme.of(context).colorScheme;
    final dominant = emotion.emotions.dominantEmotion;
    final emotionNames = {
      'happiness': '행복',
      'calm': '평온',
      'excitement': '흥분',
      'curiosity': '호기심',
      'anxiety': '불안',
      'fear': '두려움',
      'sadness': '슬픔',
      'discomfort': '불편',
    };
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology, color: AppTheme.primaryColor, size: 20.w),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '감정 분석 연결됨',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Text(
                  // 라벨만 — 퍼센트 수치 노출 금지 (P0 정책)
                  '${emotion.petName ?? '반려동물'} · ${emotionNames[dominant] ?? dominant}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _attachedEmotion = null;
              _postType = PostType.text;
            }),
            child: Icon(
              Icons.close,
              size: 18.w,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _pickImages() async {
    final images = await ImageSourcePicker.pickMultiple(context);

    if (images != null && images.isNotEmpty) {
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

  void _attachEmotionAnalysis() async {
    if (widget.currentUserId.isEmpty) return;
    final result = await Navigator.push<EmotionAnalysis>(
      context,
      MaterialPageRoute(
        builder: (_) => const AiHistoryPage(selectMode: true),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _attachedEmotion = result;
        _postType = PostType.emotionAnalysis;
      });
    }
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

    if (content.isEmpty &&
        _selectedImages.isEmpty &&
        _attachedEmotion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력하거나 이미지를 추가해주세요.')),
      );
      return;
    }

    final post = Post(
      id: '',
      authorId: widget.currentUserId,
      authorName: '',
      type: _postType,
      content: content.isNotEmpty ? content : null,
      imageUrls: const [],
      emotionAnalysis: _attachedEmotion,
      createdAt: DateTime.now(),
      isPublic: true,
      isPrivate: false,
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
