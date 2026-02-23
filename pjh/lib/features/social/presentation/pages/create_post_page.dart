import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../emotion/presentation/widgets/emotion_chart_widget.dart';
import '../../domain/entities/post.dart';
import '../bloc/feed_bloc.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../core/utils/hashtag_utils.dart';

class CreatePostPage extends StatefulWidget {
  final String? imageUrl;
  final EmotionAnalysis? emotionAnalysis;
  final String? petId;
  final String? petName;

  const CreatePostPage({
    super.key,
    this.imageUrl,
    this.emotionAnalysis,
    this.petId,
    this.petName,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _contentController = TextEditingController();
  final _hashtagController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedImage;
  String? _imageUrl;
  final List<String> _hashtags = [];
  bool _isPublic = true;
  bool _showEmotionAnalysis = true;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.imageUrl;

    // 자동 해시태그 제안 (감정 분석 결과 기반)
    if (widget.emotionAnalysis != null) {
      _suggestHashtags(widget.emotionAnalysis!);
    }
  }

  void _suggestHashtags(EmotionAnalysis analysis) {
    // 가장 높은 감정 점수에 따라 해시태그 제안
    final Map<String, double> emotions = {
      '행복': analysis.emotions.happiness,
      '슬픔': analysis.emotions.sadness,
      '불안': analysis.emotions.anxiety,
      '졸림': analysis.emotions.sleepiness,
      '호기심': analysis.emotions.curiosity,
    };

    final topEmotion =
        emotions.entries.reduce((a, b) => a.value > b.value ? a : b);

    if (topEmotion.value > 0.3) {
      final hashtagMap = {
        '행복': ['행복한하루', '행복'],
        '슬픔': ['위로', '슬픔'],
        '불안': ['불안', '진정'],
        '졸림': ['졸림', '휴식'],
        '호기심': ['호기심', '탐험'],
      };

      final suggestions = hashtagMap[topEmotion.key] ?? [];
      setState(() {
        _hashtags.addAll(suggestions);
      });
    }

    // 반려동물 이름 해시태그
    if (widget.petName != null && widget.petName!.isNotEmpty) {
      setState(() {
        _hashtags.add(widget.petName!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FeedBloc, FeedState>(
      listener: (context, state) {
        if (state is FeedError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('오류: ${state.message}')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('게시글 작성'),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _createPost,
              child: const Text(
                '게시',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이미지 섹션
                _buildImageSection(),
                SizedBox(height: 16.h),

                // 감정 분석 결과 섹션
                if (widget.emotionAnalysis != null) _buildEmotionSection(),

                SizedBox(height: 16.h),

                // 내용 입력 섹션
                _buildContentSection(),

                SizedBox(height: 16.h),

                // 해시태그 섹션
                _buildHashtagSection(),

                SizedBox(height: 16.h),

                // 공개 설정 섹션
                _buildPrivacySection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 300.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: _selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                ),
              )
            : _imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: Image.network(
                      _imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildImagePlaceholder();
                      },
                    ),
                  )
                : _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 60.w, color: Colors.grey[400]),
        SizedBox(height: 12.h),
        Text(
          '사진 추가 또는 변경',
          style: TextStyle(color: Colors.grey[600], fontSize: 16.sp),
        ),
        SizedBox(height: 4.h),
        Text(
          '터치하여 사진을 선택하세요',
          style: TextStyle(color: Colors.grey[400], fontSize: 12.sp),
        ),
      ],
    );
  }

  Widget _buildEmotionSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology, color: AppTheme.primaryColor, size: 24.w),
                  SizedBox(width: 8.w),
                  Text(
                    'AI 감정 분석 결과',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _showEmotionAnalysis,
                onChanged: (value) {
                  setState(() {
                    _showEmotionAnalysis = value;
                  });
                },
                activeThumbColor: AppTheme.primaryColor,
              ),
            ],
          ),
          if (_showEmotionAnalysis) ...[
            SizedBox(height: 12.h),
            EmotionChartWidget(
              emotionAnalysis: widget.emotionAnalysis!,
              height: 150.h,
            ),
            SizedBox(height: 8.h),
            Text(
              _getEmotionSummary(widget.emotionAnalysis!),
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14.sp,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getEmotionSummary(EmotionAnalysis analysis) {
    final Map<String, double> emotions = {
      '행복': analysis.emotions.happiness,
      '슬픔': analysis.emotions.sadness,
      '불안': analysis.emotions.anxiety,
      '졸림': analysis.emotions.sleepiness,
      '호기심': analysis.emotions.curiosity,
    };

    final topEmotion =
        emotions.entries.reduce((a, b) => a.value > b.value ? a : b);
    final percentage = (topEmotion.value * 100).toStringAsFixed(0);

    return '${widget.petName ?? "반려동물"}이(가) 지금 ${topEmotion.key} 상태입니다 ($percentage%)';
  }

  Widget _buildContentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '내용',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _contentController,
          style: TextStyle(fontSize: 14.sp),
          decoration: InputDecoration(
            hintText:
                '반려동물과의 특별한 순간을 공유해보세요...\n\n감정 분석 결과와 함께 어떤 상황이었는지,\n어떤 기분이었는지 자유롭게 작성하세요!',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14.sp),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide:
                  const BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.all(16.w),
          ),
          maxLines: 6,
          maxLength: 1000,
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
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '공개 설정',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
          ),
          SizedBox(height: 12.h),
          RadioGroup<bool>(
            groupValue: _isPublic,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _isPublic = value;
                });
              }
            },
            child: Column(
              children: [
                RadioListTile<bool>(
                  value: true,
                  title: Text('전체 공개', style: TextStyle(fontSize: 14.sp)),
                  subtitle: Text('모든 사용자가 볼 수 있습니다', style: TextStyle(fontSize: 12.sp)),
                  activeColor: AppTheme.primaryColor,
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<bool>(
                  value: false,
                  title: Text('팔로워만', style: TextStyle(fontSize: 14.sp)),
                  subtitle: Text('나를 팔로우하는 사용자만 볼 수 있습니다', style: TextStyle(fontSize: 12.sp)),
                  activeColor: AppTheme.primaryColor,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _imageUrl = null; // 새 이미지 선택 시 기존 URL 제거
      });
    }
  }

  void _showAddHashtagDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('해시태그 추가'),
          content: TextField(
            controller: _hashtagController,
            decoration: const InputDecoration(
              hintText: '해시태그 입력 (# 제외)',
              prefixText: '#',
            ),
            autofocus: true,
            onSubmitted: (value) {
              _addHashtag(value);
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                _addHashtag(_hashtagController.text);
                Navigator.pop(context);
              },
              child: const Text('추가'),
            ),
          ],
        );
      },
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

  void _createPost() async {
    if (_contentController.text.trim().isEmpty &&
        _selectedImage == null &&
        _imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용 또는 사진을 추가해주세요')),
      );
      return;
    }

    // Supabase에서 현재 사용자 정보 가져오기
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }

    final userId = user.id;
    final userName = user.userMetadata?['display_name'] as String? ?? user.email ?? '사용자';

    // 이미지 업로드 처리
    String? uploadedImageUrl = _imageUrl;
    if (_selectedImage != null) {
      try {
        // 로딩 표시
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 업로드 중...')),
        );

        // Supabase Storage에 이미지 업로드 (사용자 ID 폴더 구조)
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'posts/$userId/temp/$timestamp.jpg';
        await supabase.storage
            .from('images')
            .upload(fileName, _selectedImage!);

        // 업로드된 이미지의 공개 URL 가져오기
        uploadedImageUrl = supabase.storage
            .from('images')
            .getPublicUrl(fileName);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 업로드 실패: $e')),
        );
        return;
      }
    }

    // 본문에서 해시태그 자동 추출
    final contentText = _contentController.text.trim();
    final extractedHashtags = HashtagUtils.extractHashtags(contentText);

    // 수동 추가 해시태그와 자동 추출 해시태그 병합 (중복 제거)
    final allHashtags = {..._hashtags, ...extractedHashtags}.toList();

    // Post 엔티티 생성
    final post = Post(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      authorId: userId,
      authorName: userName,
      type: widget.emotionAnalysis != null
          ? PostType.emotionAnalysis
          : PostType.image,
      content: contentText,
      imageUrls: uploadedImageUrl != null ? [uploadedImageUrl] : [],
      emotionAnalysis: _showEmotionAnalysis ? widget.emotionAnalysis : null,
      tags: allHashtags,
      createdAt: DateTime.now(),
      isPublic: _isPublic,
      isPrivate: !_isPublic,
    );

    // BLoC로 게시글 생성 요청
    if (!mounted) return;
    context.read<FeedBloc>().add(CreatePostRequested(
          post: post,
        ));

    // 성공 메시지 표시 후 홈으로 이동
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('게시글이 작성되었습니다!')),
    );

    // 홈 화면으로 이동 (GoRouter 사용)
    if (!mounted) return;
    context.go('/home');
  }

  @override
  void dispose() {
    _contentController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }
}
