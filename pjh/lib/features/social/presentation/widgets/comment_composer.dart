import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';

class CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSubmitting;
  final String? replyAuthorName;
  final VoidCallback onSend;
  final VoidCallback onCancelReply;
  final Key inputKey;
  final Key sendKey;
  final Key? replyTargetKey;
  final Key? replyCancelKey;

  const CommentComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.replyAuthorName,
    required this.onSend,
    required this.onCancelReply,
    required this.inputKey,
    required this.sendKey,
    this.replyTargetKey,
    this.replyCancelKey,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceColor,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 8.w, 8.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyAuthorName != null)
                Container(
                  key: replyTargetKey,
                  margin: EdgeInsets.only(bottom: 6.h),
                  padding: EdgeInsets.only(left: 12.w),
                  decoration: BoxDecoration(
                    color: AppTheme.subtleBackground,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.reply,
                        size: 16.w,
                        color: AppTheme.primaryColor,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          '$replyAuthorName에게 답글',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          key: replyCancelKey,
                          onPressed: isSubmitting ? null : onCancelReply,
                          tooltip: '답글 취소',
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: inputKey,
                      controller: controller,
                      focusNode: focusNode,
                      enabled: !isSubmitting,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!isSubmitting) onSend();
                      },
                      decoration: InputDecoration(
                        hintText: replyAuthorName == null
                            ? '댓글을 입력하세요...'
                            : '답글을 입력하세요...',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                          borderSide: const BorderSide(
                            color: AppTheme.dividerColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                          borderSide: const BorderSide(
                            color: AppTheme.dividerColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24.r),
                          borderSide: const BorderSide(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      key: sendKey,
                      onPressed: isSubmitting ? null : onSend,
                      tooltip: '댓글 전송',
                      color: AppTheme.primaryColor,
                      icon: isSubmitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
