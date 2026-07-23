import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/utils/back_press_handler.dart';
import '../../../../shared/constants/community_categories.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/category_chip.dart';
import '../../../../shared/widgets/petspace_bottom_action_bar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../social/domain/entities/post.dart';
import '../../../social/domain/repositories/social_repository.dart';

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

class _CreateCommunityPostPageState extends State<CreateCommunityPostPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;
  String _selectedCategory = CommunityCategories.defaultWriteValue;
  String? _titleError;
  String? _contentError;
  String? _submitError;

  static const _categories = CommunityCategories.lounge;

  SocialRepository get _repository =>
      widget.repository ?? sl<SocialRepository>();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final titleError = title.isEmpty ? '제목을 입력해주세요.' : null;
    final contentError = content.isEmpty ? '내용을 입력해주세요.' : null;
    if (titleError != null || contentError != null) {
      setState(() {
        _titleError = titleError;
        _contentError = contentError;
        _submitError = null;
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
      category: _selectedCategory,
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
      (_) => Navigator.of(context).pop(true),
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
    final shouldDiscard = await BackPressHandler.showDiscardDialog(
      context,
      title: '커뮤니티 글쓰기 취소',
      content: '작성 중인 내용이 있습니다.\n나가면 내용이 사라집니다.',
    );
    if (shouldDiscard && mounted && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          leadingWidth: 68.w,
          leading: TextButton(
            key: const Key('community_close_button'),
            onPressed: _isSubmitting ? null : _handleBackPress,
            child: const Text('닫기'),
          ),
          title: const Text('커뮤니티 글쓰기'),
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
                              setState(
                                () => _selectedCategory = category.value,
                              );
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
                    if (_titleError != null || _submitError != null) {
                      setState(() {
                        _titleError = null;
                        _submitError = null;
                      });
                    }
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
                    if (_contentError != null || _submitError != null) {
                      setState(() {
                        _contentError = null;
                        _submitError = null;
                      });
                    }
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
                    '등록 실패 시 제목·내용·카테고리를 그대로 유지합니다. 작성 중 나가면 내용은 저장되지 않아요.',
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
            onPressed: _isSubmitting ? null : _submit,
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
}
