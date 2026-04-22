import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/back_press_handler.dart';
import '../../../../core/utils/hashtag_utils.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/multi_image_picker.dart';
import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../emotion/presentation/widgets/emotion_chart_widget.dart';
import '../../domain/entities/post.dart';
import '../bloc/feed_bloc.dart';
import '../utils/post_draft_storage.dart';
import '../widgets/location_picker_sheet.dart';

class CreatePostPage extends StatefulWidget {
  final String? imageUrl;
  final EmotionAnalysis? emotionAnalysis;
  final String? petId;
  final String? petName;
  final Post? editPost;

  const CreatePostPage({
    super.key,
    this.imageUrl,
    this.emotionAnalysis,
    this.petId,
    this.petName,
    this.editPost,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> with WidgetsBindingObserver {
  final _contentController = TextEditingController();
  final _hashtagController = TextEditingController();

  List<File> _selectedImages = [];
  bool get _isEditMode => widget.editPost != null;
  String? _imageUrl;
  final List<String> _hashtags = [];
  bool _isPublic = true;
  bool _showEmotionAnalysis = true;
  Timer? _autosaveTimer;
  LocationResult? _location;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.editPost != null) {
      _contentController.text = widget.editPost!.content ?? '';
      final tags = widget.editPost!.tags.map((h) => '#$h').join(' ');
      _hashtagController.text = tags;
    }
    _imageUrl = widget.imageUrl;
    if (widget.emotionAnalysis != null) {
      _suggestHashtags(widget.emotionAnalysis!);
    }
    if (!_isEditMode) _loadDraft();
    _startAutosave();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    _contentController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveDraft();
    }
  }

  void _startAutosave() {
    _autosaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _saveDraft();
    });
  }

  Future<void> _saveDraft() async {
    if (_isEditMode) return;
    final content = _contentController.text;
    if (content.isEmpty && _hashtags.isEmpty) return;
    await PostDraftStorage.save(content: content, hashtags: _hashtags);
  }

  Future<void> _loadDraft() async {
    final draft = await PostDraftStorage.load();
    if (draft == null || !mounted) return;
    if (draft.content.isNotEmpty || draft.hashtags.isNotEmpty) {
      final restore = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('임시저장 불러오기'),
          content: const Text('이전에 작성 중이던 내용이 있습니다.\n불러오시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('무시'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('불러오기'),
            ),
          ],
        ),
      );
      if (restore == true && mounted) {
        setState(() {
          _contentController.text = draft.content;
          _hashtags
            ..clear()
            ..addAll(draft.hashtags);
        });
      }
    }
  }

  void _suggestHashtags(EmotionAnalysis analysis) {
    final Map<String, double> emotions = {
      '행복': analysis.emotions.happiness,
      '편안': analysis.emotions.calm,
      '흥분': analysis.emotions.excitement,
      '호기심': analysis.emotions.curiosity,
      '불안': analysis.emotions.anxiety,
      '공포': analysis.emotions.fear,
      '슬픔': analysis.emotions.sadness,
      '불편': analysis.emotions.discomfort,
    };
    final topEmotion =
        emotions.entries.reduce((a, b) => a.value > b.value ? a : b);
    if (topEmotion.value > 0.3) {
      final hashtagMap = {
        '행복': ['행복한하루', '행복'],
        '편안': ['편안한하루', '힐링'],
        '흥분': ['신나는하루', '활기차'],
        '호기심': ['호기심왕성', '탐구'],
        '불안': ['불안', '진정'],
        '공포': ['공포', '안정'],
        '슬픔': ['위로', '슬픔'],
        '불편': ['불편', '케어'],
      };
      final suggestions = hashtagMap[topEmotion.key] ?? [];
      setState(() => _hashtags.addAll(suggestions));
    }
    if (widget.petName != null && widget.petName!.isNotEmpty) {
      setState(() => _hashtags.add(widget.petName!));
    }
  }

  Future<void> _handleBackPress() async {
    final hasContent =
        _contentController.text.isNotEmpty || _selectedImages.isNotEmpty;
    if (hasContent) {
      final shouldDiscard = await BackPressHandler.showDiscardDialog(
        context,
        title: '게시글 작성 취소',
        content: '작성 중인 내용이 임시저장됩니다.\n계속하시겠습니까?',
      );
      if (shouldDiscard) {
        await _saveDraft();
        if (mounted && context.canPop()) context.pop();
      }
    } else {
      if (mounted && context.canPop()) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBackPress();
      },
      child: BlocListener<FeedBloc, FeedState>(
        listener: (context, state) {
          if (state is FeedPostCreated) {
            PostDraftStorage.clear();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('게시글이 작성되었습니다!')),
            );
            if (context.canPop()) context.pop();
          } else if (state is FeedError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('오류: ${state.message}')),
            );
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(_isEditMode ? '게시글 수정' : '게시글 작성'),
            centerTitle: true,
            actions: [
              TextButton(
                onPressed: _isEditMode ? _updatePost : _submit,
                child: Text(
                  _isEditMode ? '수정완료' : '게시',
                  style: const TextStyle(
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
                  MultiImagePicker(
                    images: _selectedImages,
                    onChanged: (imgs) => setState(() => _selectedImages = imgs),
                  ),
                  SizedBox(height: 16.h),
                  if (widget.emotionAnalysis != null) _buildEmotionSection(),
                  SizedBox(height: 16.h),
                  _buildContentSection(),
                  SizedBox(height: 16.h),
                  _buildHashtagSection(),
                  SizedBox(height: 16.h),
                  _buildPrivacySection(),
                  SizedBox(height: 16.h),
                  _buildLocationSection(),
                ],
              ),
            ),
          ),
        ),
      ),
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
                  Icon(Icons.psychology,
                      color: AppTheme.primaryColor, size: 24.w),
                  SizedBox(width: 8.w),
                  Text(
                    'AI 감정 분석 결과',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16.sp),
                  ),
                ],
              ),
              Switch(
                value: _showEmotionAnalysis,
                onChanged: (value) =>
                    setState(() => _showEmotionAnalysis = value),
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
              style: TextStyle(color: Colors.grey[700], fontSize: 14.sp),
            ),
          ],
        ],
      ),
    );
  }

  String _getEmotionSummary(EmotionAnalysis analysis) {
    final Map<String, double> emotions = {
      '행복': analysis.emotions.happiness,
      '편안': analysis.emotions.calm,
      '흥분': analysis.emotions.excitement,
      '호기심': analysis.emotions.curiosity,
      '불안': analysis.emotions.anxiety,
      '공포': analysis.emotions.fear,
      '슬픔': analysis.emotions.sadness,
      '불편': analysis.emotions.discomfort,
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
        Text('내용',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
        SizedBox(height: 8.h),
        TextField(
          controller: _contentController,
          style: TextStyle(fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: '반려동물과의 특별한 순간을 공유해보세요...',
            hintStyle:
                TextStyle(color: Colors.grey[400], fontSize: 14.sp),
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
        Text('해시태그',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            ..._hashtags.map(
              (tag) => Chip(
                label: Text('#$tag', style: TextStyle(fontSize: 12.sp)),
                onDeleted: () => setState(() => _hashtags.remove(tag)),
                backgroundColor:
                    AppTheme.primaryColor.withValues(alpha: 0.1),
                labelStyle: TextStyle(
                    color: AppTheme.primaryColor, fontSize: 12.sp),
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
          Text('공개 설정',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
          SizedBox(height: 12.h),
          RadioGroup<bool>(
            groupValue: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v ?? true),
            child: Column(
              children: [
                RadioListTile<bool>(
                  value: true,
                  title: Text('전체 공개', style: TextStyle(fontSize: 14.sp)),
                  subtitle: Text('모든 사용자가 볼 수 있습니다',
                      style: TextStyle(fontSize: 12.sp)),
                  activeColor: AppTheme.primaryColor,
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<bool>(
                  value: false,
                  title: Text('팔로워만', style: TextStyle(fontSize: 14.sp)),
                  subtitle: Text('나를 팔로우하는 사용자만 볼 수 있습니다',
                      style: TextStyle(fontSize: 12.sp)),
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

  Widget _buildLocationSection() {
    return GestureDetector(
      onTap: () async {
        final result = await LocationPickerSheet.show(context);
        if (result != null && mounted) {
          setState(() => _location = result);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(
              _location != null ? Icons.location_on : Icons.add_location_alt_outlined,
              size: 20.w,
              color: _location != null ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                _location != null ? _location!.name : '위치 추가',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: _location != null
                      ? AppTheme.primaryTextColor
                      : AppTheme.secondaryTextColor,
                ),
              ),
            ),
            if (_location != null)
              GestureDetector(
                onTap: () => setState(() => _location = null),
                child: Icon(Icons.close, size: 18.w, color: Colors.grey[400]),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddHashtagDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              _addHashtag(_hashtagController.text);
              Navigator.pop(ctx);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _addHashtag(String tag) {
    final trimmed = tag.trim().replaceAll('#', '');
    if (trimmed.isNotEmpty && !_hashtags.contains(trimmed)) {
      setState(() => _hashtags.add(trimmed));
    }
    _hashtagController.clear();
  }

  void _submit() {
    final contentText = _contentController.text.trim();
    if (contentText.isEmpty && _selectedImages.isEmpty && _imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용 또는 사진을 추가해주세요')),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }

    final postId = const Uuid().v4();
    final extractedHashtags = HashtagUtils.extractHashtags(contentText);
    final allHashtags = {..._hashtags, ...extractedHashtags}.toList();

    final existingUrls = _imageUrl != null ? [_imageUrl!] : <String>[];

    final post = Post(
      id: postId,
      authorId: user.id,
      authorName: user.userMetadata?['display_name'] as String? ??
          user.email ??
          '사용자',
      type: widget.emotionAnalysis != null
          ? PostType.emotionAnalysis
          : PostType.image,
      content: contentText,
      imageUrls: existingUrls,
      emotionAnalysis:
          _showEmotionAnalysis ? widget.emotionAnalysis : null,
      tags: allHashtags,
      createdAt: DateTime.now(),
      isPublic: _isPublic,
      isPrivate: !_isPublic,
      location: _location?.name,
      locationLat: _location?.lat,
      locationLng: _location?.lng,
    );

    context.read<FeedBloc>().add(CreatePostRequested(
          post: post,
          images: _selectedImages,
        ));
  }

  Future<void> _updatePost() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요.')),
      );
      return;
    }
    if (widget.editPost == null) return;

    final hashtags = HashtagUtils.extractHashtags(
      '${_contentController.text} ${_hashtagController.text}',
    );
    final updatedPost = widget.editPost!.copyWith(
      content: _contentController.text.trim(),
      tags: hashtags,
    );

    if (!mounted) return;
    context.read<FeedBloc>().add(UpdatePostRequested(post: updatedPost));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('게시글이 수정되었습니다!')),
    );
    if (!mounted) return;
    context.pop();
  }
}
