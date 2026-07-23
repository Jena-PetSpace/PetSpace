import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/content_filter.dart';
import '../../../../core/utils/back_press_handler.dart';
import '../../../../core/utils/hashtag_utils.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_bottom_action_bar.dart';
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
  final String? currentUserId;
  final String? currentUserName;

  const CreatePostPage({
    super.key,
    this.imageUrl,
    this.emotionAnalysis,
    this.petId,
    this.petName,
    this.editPost,
    this.currentUserId,
    this.currentUserName,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage>
    with WidgetsBindingObserver {
  final _contentController = TextEditingController();
  final _hashtagController = TextEditingController();

  List<File> _selectedImages = [];
  bool get _isEditMode => widget.editPost != null;
  String? _imageUrl;
  final List<String> _hashtags = [];
  bool _showEmotionAnalysis = true;
  bool _isSubmitting = false;
  String? _submissionError;
  Timer? _autosaveTimer;
  LocationResult? _location;

  bool get _canSubmit {
    if (_isSubmitting) return false;
    final hasText = _contentController.text.trim().isNotEmpty;
    if (_isEditMode) return hasText;
    return hasText || _selectedImages.isNotEmpty || _imageUrl != null;
  }

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
    // 해시태그 자동 부착 중단 (P0 C-3) — 사용자가 직접 입력한 태그만 사용.
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

  Future<void> _handleBackPress() async {
    final hasContent = _contentController.text.isNotEmpty ||
        _selectedImages.isNotEmpty ||
        _hashtags.isNotEmpty ||
        _location != null;
    if (hasContent) {
      final shouldDiscard = await BackPressHandler.showDiscardDialog(
        context,
        title: '게시글 작성 취소',
        content: '본문과 태그를 임시 저장하고 작성 화면을 닫을까요?\n사진과 위치는 저장되지 않습니다.',
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
              const SnackBar(content: Text('게시글을 등록했어요.')),
            );
            if (context.canPop()) context.pop();
          } else if (state is FeedPostUpdated && _isEditMode) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('게시글을 수정했어요.')),
            );
            if (context.canPop()) context.pop();
          } else if (state is FeedError) {
            setState(() {
              _isSubmitting = false;
              _submissionError = _isEditMode
                  ? '게시글을 수정하지 못했어요. 입력 내용은 그대로 유지됩니다.'
                  : '게시글을 등록하지 못했어요. 입력 내용과 사진은 그대로 유지됩니다.';
            });
          }
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            leadingWidth: 68.w,
            leading: TextButton(
              key: const Key('create_post_close_button'),
              onPressed: _isSubmitting ? null : _handleBackPress,
              child: const Text('닫기'),
            ),
            title: Text(_isEditMode ? '게시글 수정' : '게시글 작성'),
            centerTitle: true,
          ),
          // P2-3: 키보드 외부 영역 탭 시 자동 닫기 (한국 모바일 표준 UX)
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditMode ? '게시물을 다듬어보세요' : '오늘의 순간을 남겨보세요',
                      style: TextStyle(
                        fontSize: AppTheme.fontHeading.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      _isEditMode
                          ? '수정 실패 시 기존 게시물과 입력 내용을 유지합니다.'
                          : '본문과 태그는 기기에 주기적으로 임시 저장됩니다.',
                      style: TextStyle(
                        fontSize: AppTheme.fontCaption.sp,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (widget.petName?.trim().isNotEmpty == true) ...[
                      SizedBox(height: 20.h),
                      _buildPetSection(),
                    ],
                    SizedBox(height: 20.h),
                    _buildContentSection(),
                    SizedBox(height: 18.h),
                    _buildSectionLabel('사진', '최대 10장'),
                    SizedBox(height: 8.h),
                    MultiImagePicker(
                      key: const Key('create_post_image_picker'),
                      images: _selectedImages,
                      maxImages: 10,
                      emptyHeight: 132,
                      onChanged: (imgs) => setState(() {
                        _selectedImages = imgs;
                        _submissionError = null;
                      }),
                    ),
                    SizedBox(height: 16.h),
                    if (widget.emotionAnalysis != null) _buildEmotionSection(),
                    if (widget.emotionAnalysis != null) SizedBox(height: 16.h),
                    _buildHashtagSection(),
                    SizedBox(height: 16.h),
                    _buildPrivacySection(),
                    SizedBox(height: 16.h),
                    _buildLocationSection(),
                    if (_submissionError != null) ...[
                      SizedBox(height: 16.h),
                      Container(
                        key: const Key('create_post_submit_error'),
                        width: double.infinity,
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd.r),
                        ),
                        child: Text(
                          _submissionError!,
                          style: TextStyle(
                            fontSize: AppTheme.fontCaption.sp,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: _buildSubmitBar(),
        ),
      ),
    );
  }

  Widget _buildSubmitBar() {
    return PetSpaceBottomActionBar(
      key: const Key('create_post_bottom_action'),
      child: FilledButton(
        key: const Key('create_post_submit_button'),
        onPressed: _canSubmit ? (_isEditMode ? _updatePost : _submit) : null,
        child: _isSubmitting
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(_isEditMode ? '수정하기' : '게시하기'),
      ),
    );
  }

  Widget _buildSectionLabel(String title, String trailing) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: AppTheme.fontBody.sp,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        Text(
          trailing,
          style: TextStyle(
            fontSize: AppTheme.fontMicro.sp,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPetSection() {
    return Container(
      key: const Key('create_post_pet'),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.pets_outlined, color: AppTheme.actionBase),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '함께한 반려동물',
                  style: TextStyle(
                    fontSize: AppTheme.fontMicro.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  widget.petName!,
                  style: TextStyle(
                    fontSize: AppTheme.fontBody.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionSection() {
    final theme = Theme.of(context);
    return Container(
      key: const Key('create_post_emotion_card'),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: theme.colorScheme.outlineVariant),
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
                      fontWeight: FontWeight.w700,
                      fontSize: 16.sp,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
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
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
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
    // 라벨만 — 퍼센트 수치 노출 금지 (P0 정책)
    return '${widget.petName ?? "반려동물"}이(가) 지금 ${topEmotion.key} 상태입니다';
  }

  Widget _buildContentSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('내용', '최대 1,000자'),
        SizedBox(height: 8.h),
        TextField(
          key: const Key('create_post_content_field'),
          controller: _contentController,
          enabled: !_isSubmitting,
          onChanged: (_) {
            setState(() => _submissionError = null);
          },
          style: TextStyle(
            fontSize: AppTheme.fontBody.sp,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: '반려동물과의 특별한 순간을 공유해보세요...',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: AppTheme.fontCaption.sp,
            ),
            contentPadding: EdgeInsets.all(16.w),
          ),
          minLines: 4,
          maxLines: 6,
          maxLength: 1000,
        ),
      ],
    );
  }

  Widget _buildHashtagSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('태그', '선택'),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            ..._hashtags.map(
              (tag) => Chip(
                label: Text('#$tag', style: TextStyle(fontSize: 12.sp)),
                onDeleted: () => setState(() => _hashtags.remove(tag)),
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                labelStyle:
                    TextStyle(color: AppTheme.primaryColor, fontSize: 12.sp),
                deleteIconColor: AppTheme.primaryColor,
              ),
            ),
            ActionChip(
              key: const Key('create_post_add_hashtag'),
              avatar: Icon(
                Icons.add_rounded,
                size: 16.w,
                color: AppTheme.actionBase,
              ),
              label: Text(
                '태그 추가',
                style: TextStyle(
                  fontSize: AppTheme.fontCaption.sp,
                  color: AppTheme.actionBase,
                ),
              ),
              onPressed: _showAddHashtagDialog,
              backgroundColor: theme.colorScheme.surface,
              side: BorderSide(
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.outlineVariant
                    : AppTheme.border,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    final theme = Theme.of(context);
    return Container(
      key: const Key('create_post_privacy_card'),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('공개 범위',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16.sp,
                color: theme.colorScheme.onSurface,
              )),
          SizedBox(height: 8.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.public_rounded, color: AppTheme.actionBase),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditMode ? '기존 공개 범위 유지' : '전체 공개',
                      style: TextStyle(
                        fontSize: AppTheme.fontBody.sp,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      _isEditMode
                          ? '수정 화면에서는 공개 범위를 변경하지 않아요.'
                          : '로그인한 모든 사용자가 볼 수 있어요.',
                      style: TextStyle(
                        fontSize: AppTheme.fontCaption.sp,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_isEditMode) ...[
            SizedBox(height: 10.h),
            Text(
              '제한 공개는 데이터 정책 검증이 끝난 뒤 제공할 예정입니다.',
              style: TextStyle(
                fontSize: AppTheme.fontMicro.sp,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () async {
        final result = await LocationPickerSheet.show(context);
        if (result != null && mounted) {
          setState(() => _location = result);
        }
      },
      child: Container(
        key: const Key('create_post_location_card'),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(
              _location != null
                  ? Icons.location_on
                  : Icons.add_location_alt_outlined,
              size: 20.w,
              color: _location != null
                  ? AppTheme.primaryColor
                  : theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                _location != null ? _location!.name : '위치 추가',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: _location != null
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_location != null)
              GestureDetector(
                onTap: () => setState(() => _location = null),
                child: Icon(Icons.close,
                    size: 18.w, color: theme.colorScheme.onSurfaceVariant),
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
          key: const Key('create_post_hashtag_field'),
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
            key: const Key('create_post_hashtag_add_button'),
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
    if (_isSubmitting) return;
    final contentText = _contentController.text.trim();
    if (contentText.isEmpty && _selectedImages.isEmpty && _imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용 또는 사진을 추가해주세요')),
      );
      return;
    }

    // 1차 콘텐츠 필터 — 비속어/혐오/성적 표현 차단 (커뮤니티 가이드라인)
    if (ContentFilter.hasBannedKeyword(contentText) ||
        _hashtags.any(ContentFilter.hasBannedKeyword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('커뮤니티 가이드라인에 어긋나는 표현이 포함되어 있습니다.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final user = widget.currentUserId == null
        ? Supabase.instance.client.auth.currentUser
        : null;
    final userId = widget.currentUserId ?? user?.id;
    if (userId == null || userId.isEmpty) {
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
      authorId: userId,
      authorName: widget.currentUserName ??
          user?.userMetadata?['display_name'] as String? ??
          user?.email ??
          '사용자',
      type: widget.emotionAnalysis != null
          ? PostType.emotionAnalysis
          : PostType.image,
      content: contentText,
      imageUrls: existingUrls,
      emotionAnalysis: _showEmotionAnalysis ? widget.emotionAnalysis : null,
      tags: allHashtags,
      createdAt: DateTime.now(),
      isPublic: true,
      isPrivate: false,
      location: _location?.name,
      locationLat: _location?.lat,
      locationLng: _location?.lng,
    );

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });
    context.read<FeedBloc>().add(CreatePostRequested(
          post: post,
          images: _selectedImages,
        ));
  }

  Future<void> _updatePost() async {
    if (_isSubmitting) return;
    final trimmed = _contentController.text.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요.')),
      );
      return;
    }
    if (ContentFilter.hasBannedKeyword(trimmed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('커뮤니티 가이드라인에 어긋나는 표현이 포함되어 있습니다.'),
          backgroundColor: AppTheme.errorColor,
        ),
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
    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });
    context.read<FeedBloc>().add(UpdatePostRequested(post: updatedPost));
  }
}
