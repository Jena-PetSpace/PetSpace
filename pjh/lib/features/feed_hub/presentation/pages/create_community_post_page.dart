import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/injection_container.dart';
import '../../../../core/utils/back_press_handler.dart';
import '../../../../shared/constants/community_categories.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/category_chip.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../social/domain/entities/post.dart';
import '../../../social/domain/repositories/social_repository.dart';

class CreateCommunityPostPage extends StatefulWidget {
  const CreateCommunityPostPage({super.key});

  @override
  State<CreateCommunityPostPage> createState() =>
      _CreateCommunityPostPageState();
}

class _CreateCommunityPostPageState extends State<CreateCommunityPostPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;
  // 라운지 4종(shared 단일 소스). 기본값 '잡담' — 구 'qa' 기본값이
  // 어떤 필터에도 안 잡히던 버그 청산(qa는 '궁금해요' 선택지로 유지).
  String _selectedCategory = CommunityCategories.defaultWriteValue;

  static const _categories = CommunityCategories.lounge;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      _showSnack('제목을 입력해주세요.');
      return;
    }
    if (content.isEmpty) {
      _showSnack('내용을 입력해주세요.');
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    setState(() => _isSubmitting = true);

    final post = Post(
      id: '',
      authorId: authState.user.uid,
      authorName: authState.user.displayName,
      type: PostType.text, // → post_type='community'
      content: '$title\n\n$content',
      category: _selectedCategory, // hashtags 대신 category 컬럼에 저장
      createdAt: DateTime.now(),
    );

    final result = await sl<SocialRepository>().createPost(post);
    if (!mounted) return;
    result.fold(
      (failure) {
        dev.log('커뮤니티 포스트 작성 실패: ${failure.message}',
            name: 'CreateCommunityPostPage');
        _showSnack('작성에 실패했습니다. 다시 시도해주세요.');
        setState(() => _isSubmitting = false);
      },
      (_) {
        setState(() => _isSubmitting = false);
        Navigator.of(context).pop(true);
      },
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleBackPress() async {
    final hasContent = _titleController.text.isNotEmpty ||
        _contentController.text.isNotEmpty;
    if (hasContent) {
      final shouldDiscard = await BackPressHandler.showDiscardDialog(
        context,
        title: '글쓰기 취소',
        content: '작성 중인 내용이 있습니다.\n돌아가면 내용이 사라집니다.',
      );
      if (shouldDiscard && mounted && context.canPop()) context.pop();
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
      child: Scaffold(
      appBar: AppBar(
        title: Text('글쓰기',
            style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryColor))
                : Text('등록',
                    style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 카테고리
            Text('카테고리',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            SizedBox(height: 8.h),
            // 카테고리 선택 칩 — 공용 CategoryChip으로 통일 (v2 T3)
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _categories.map((cat) {
                return CategoryChip(
                  label: cat.label,
                  selected: _selectedCategory == cat.value,
                  onTap: () =>
                      setState(() => _selectedCategory = cat.value),
                );
              }).toList(),
            ),
            SizedBox(height: 20.h),

            // 제목
            Text('제목',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            SizedBox(height: 8.h),
            TextField(
              controller: _titleController,
              maxLength: 100,
              style: TextStyle(fontSize: 15.sp),
              decoration: InputDecoration(
                hintText: '제목을 입력해주세요',
                hintStyle: const TextStyle(color: AppTheme.hintColor),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r)),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              ),
            ),
            SizedBox(height: 16.h),

            // 내용
            Text('내용',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            SizedBox(height: 8.h),
            TextField(
              controller: _contentController,
              maxLines: 12,
              maxLength: 2000,
              style: TextStyle(fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: '내용을 입력해주세요',
                hintStyle: const TextStyle(color: AppTheme.hintColor),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r)),
                contentPadding: EdgeInsets.all(14.w),
              ),
            ),
            SizedBox(height: 24.h),

            // 등록 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.actionBase,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                  elevation: 0,
                ),
                child: Text('등록하기',
                    style: TextStyle(
                        fontSize: 16.sp, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
      ),   // Scaffold
    );     // PopScope
  }
}
