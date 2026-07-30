import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/constants/community_categories.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/category_chip.dart';
import '../../../../shared/widgets/petspace_bottom_action_bar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../social/domain/entities/post.dart';
import '../../../social/domain/repositories/social_repository.dart';
import '../../../social/presentation/utils/post_draft_storage.dart';

enum _CommunityDraftExitChoice { save, keepEditing, discard }

class CreateCommunityPostPage extends StatefulWidget {
  final SocialRepository? repository;
  final String? authorId;
  final String? authorName;

  const CreateCommunityPostPage({
    super.key,
    this.repository,
    this.authorId,
    this.authorName,
  });

  @override
  State<CreateCommunityPostPage> createState() =>
      _CreateCommunityPostPageState();
}

class _CreateCommunityPostPageState extends State<CreateCommunityPostPage>
    with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;
  String? _selectedCategory;
  String? _titleError;
  String? _contentError;
  String? _submitError;
  Timer? _autosaveTimer;

  static const _categories = <CommunityCategory>[
    CommunityCategory(value: 'qa', label: '질문'),
    CommunityCategory(value: 'info', label: '정보'),
    CommunityCategory(value: 'brag', label: '자랑'),
    CommunityCategory(value: 'chat', label: '일상'),
  ];

  SocialRepository get _repository =>
      widget.repository ?? sl<SocialRepository>();

  bool get _canSubmit =>
      !_isSubmitting &&
      _selectedCategory != null &&
      _titleController.text.trim().isNotEmpty &&
      _contentController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDraft();
    _autosaveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _saveDraft(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_saveDraft());
    }
  }

  Future<void> _saveDraft() async {
    final title = _titleController.text;
    final content = _contentController.text;
    final category = _selectedCategory ?? '';
    if (title.isEmpty && content.isEmpty && category.isEmpty) {
      await PostDraftStorage.clearCommunity();
      return;
    }
    await PostDraftStorage.saveCommunity(
      title: title,
      content: content,
      category: category,
    );
  }

  Future<void> _loadDraft() async {
    final draft = await PostDraftStorage.loadCommunity();
    if (draft == null || !mounted) return;
    final restore = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('커뮤니티 임시저장 불러오기'),
        content: const Text('이전에 작성 중이던 커뮤니티 글이 있습니다. 불러올까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('무시'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('불러오기'),
          ),
        ],
      ),
    );
    if (restore != true || !mounted) return;
    final allowedValues = _categories.map((item) => item.value).toSet();
    setState(() {
      _titleController.text = draft.title;
      _contentController.text = draft.content;
      _selectedCategory =
          allowedValues.contains(draft.category) ? draft.category : null;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final categoryError = _selectedCategory == null ? '카테고리를 선택해주세요.' : null;
    final titleError = title.isEmpty ? '제목을 입력해주세요.' : null;
    final contentError = content.isEmpty ? '내용을 입력해주세요.' : null;
    if (categoryError != null || titleError != null || contentError != null) {
      setState(() {
        _titleError = titleError;
        _contentError = contentError;
        _submitError = categoryError;
      });
      return;
    }

    final authState = widget.authorId == null || widget.authorName == null
        ? context.read<AuthBloc>().state
        : null;
    final authorId = widget.authorId ??
        (authState is AuthAuthenticated ? authState.user.uid : null);
    final authorName = widget.authorName ??
        (authState is AuthAuthenticated ? authState.user.displayName : null);
    if (authorId == null || authorId.isEmpty) {
      setState(() => _submitError = '로그인 정보를 확인한 뒤 다시 시도해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final post = Post(
      id: '',
      authorId: authorId,
      authorName: authorName?.trim().isNotEmpty == true ? authorName! : '사용자',
      type: PostType.text,
      content: '$title\n\n$content',
      category: _selectedCategory!,
      createdAt: DateTime.now(),
      isPublic: true,
      isPrivate: false,
    );

    final result = await _repository.createPost(post);
    if (!mounted) return;
    result.fold(
      (_) => setState(() {
        _isSubmitting = false;
        _submitError = '글을 등록하지 못했어요. 입력 내용은 그대로 유지됩니다.';
      }),
      (_) {
        unawaited(PostDraftStorage.clearCommunity());
        Navigator.of(context).pop(true);
      },
    );
  }

  Future<void> _handleBackPress() async {
    if (_isSubmitting) return;
    final hasContent =
        _titleController.text.isNotEmpty || _contentController.text.isNotEmpty;
    if (!hasContent) {
      if (mounted && context.canPop()) context.pop();
      return;
    }
    final choice = await showDialog<_CommunityDraftExitChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowAlignment: OverflowBarAlignment.end,
        title: const Text('커뮤니티 작성을 마칠까요?'),
        content: const Text('제목·내용·카테고리를 기기에 임시 저장할 수 있어요.'),
        actions: [
          TextButton(
            key: const Key('community_exit_keep'),
            onPressed: () => Navigator.pop(
              dialogContext,
              _CommunityDraftExitChoice.keepEditing,
            ),
            child: const Text('계속 작성'),
          ),
          TextButton(
            key: const Key('community_exit_discard'),
            onPressed: () => Navigator.pop(
              dialogContext,
              _CommunityDraftExitChoice.discard,
            ),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('내용 버리기'),
          ),
          FilledButton(
            key: const Key('community_exit_save'),
            onPressed: () => Navigator.pop(
              dialogContext,
              _CommunityDraftExitChoice.save,
            ),
            child: const Text('임시 저장'),
          ),
        ],
      ),
    );
    if (choice == null ||
        choice == _CommunityDraftExitChoice.keepEditing ||
        !mounted) {
      return;
    }
    if (choice == _CommunityDraftExitChoice.save) {
      await _saveDraft();
    } else {
      await PostDraftStorage.clearCommunity();
    }
    if (mounted && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final usesLargeText = textScale > 1.5;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: usesLargeText ? 72 : kToolbarHeight,
          leadingWidth: usesLargeText ? 76 : 68.w,
          leading: Center(
            child: TextButton(
              key: const Key('community_close_button'),
              onPressed: _isSubmitting ? null : _handleBackPress,
              child: const Text('닫기'),
            ),
          ),
          title: const Text(
            '커뮤니티 글쓰기',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          centerTitle: true,
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이웃과 이야기를 나눠보세요',
                  style: TextStyle(
                    fontSize: AppTheme.fontHeading.sp,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  '답변을 요구하지 않아도 괜찮아요. 알맞은 분류를 선택해주세요.',
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    height: 1.45,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 24.h),
                _label('카테고리', '필수'),
                SizedBox(height: 9.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: _categories
                      .map(
                        (category) => IntrinsicWidth(
                          child: CategoryChip(
                            label: category.label,
                            selected: _selectedCategory == category.value,
                            onTap: () {
                              if (_isSubmitting) return;
                              setState(() {
                                _selectedCategory = category.value;
                                _submitError = null;
                              });
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: 24.h),
                _label('제목', '필수 · 최대 100자'),
                SizedBox(height: 8.h),
                TextField(
                  key: const Key('community_title_field'),
                  controller: _titleController,
                  enabled: !_isSubmitting,
                  maxLength: 100,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    setState(() {
                      if (_titleError != null || _submitError != null) {
                        _titleError = null;
                        _submitError = null;
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: '이야기의 핵심을 적어주세요',
                    errorText: _titleError,
                  ),
                ),
                SizedBox(height: 16.h),
                _label('내용', '필수 · 최대 2,000자'),
                SizedBox(height: 8.h),
                TextField(
                  key: const Key('community_content_field'),
                  controller: _contentController,
                  enabled: !_isSubmitting,
                  minLines: 7,
                  maxLines: 12,
                  maxLength: 2000,
                  onChanged: (_) {
                    setState(() {
                      if (_contentError != null || _submitError != null) {
                        _contentError = null;
                        _submitError = null;
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: '상황이나 경험을 자세히 적어주세요',
                    errorText: _contentError,
                    alignLabelWithHint: true,
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  key: const Key('community_draft_notice'),
                  width: double.infinity,
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    '제목·내용·카테고리는 커뮤니티 전용 임시저장에 보관됩니다. '
                    '피드 임시저장과 섞이지 않아요.',
                    style: TextStyle(
                      fontSize: AppTheme.fontCaption.sp,
                      height: 1.45,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (_submitError != null) ...[
                  SizedBox(height: 12.h),
                  Text(
                    _submitError!,
                    key: const Key('community_submit_error'),
                    style: TextStyle(
                      fontSize: AppTheme.fontCaption.sp,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: PetSpaceBottomActionBar(
          key: const Key('community_bottom_action'),
          child: FilledButton(
            key: const Key('community_submit_button'),
            onPressed: _canSubmit ? _submit : null,
            child: _isSubmitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('등록하기'),
          ),
        ),
      ),
    );
  }

  Widget _label(String title, String trailing) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontSize: AppTheme.fontBody.sp,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Flexible(
          child: Text(
            trailing,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: AppTheme.fontMicro.sp,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
