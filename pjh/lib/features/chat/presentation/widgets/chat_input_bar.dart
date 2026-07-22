import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/image_source_picker.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isSending;
  final ValueChanged<String> onSendText;
  final ValueChanged<File> onSendImage;
  final ValueChanged<List<File>> onSendMultipleImages;

  const ChatInputBar({
    super.key,
    required this.controller,
    this.isSending = false,
    required this.onSendText,
    required this.onSendImage,
    required this.onSendMultipleImages,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onTextChanged);
    widget.controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _handleSendText() {
    final text = widget.controller.text.trim();
    if (text.isEmpty || widget.isSending) return;
    widget.onSendText(text);
  }

  Future<void> _showImageSourceSheet() async {
    if (widget.isSending) return;

    final images = await ImageSourcePicker.pickMultiple(
      context,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (images != null && images.isNotEmpty && mounted) {
      final files = images.map((xf) => File(xf.path)).toList();
      _showImagePreview(files);
    }
  }

  void _showImagePreview(List<File> images) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ImagePreviewDialog(
        images: images,
        onSend: (selectedImages) {
          if (selectedImages.length == 1) {
            widget.onSendImage(selectedImages.first);
          } else {
            widget.onSendMultipleImages(selectedImages);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? theme.colorScheme.surface : AppTheme.surfaceColor;
    final inputSurface = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : AppTheme.actionContainer.withValues(alpha: 0.55);
    final muted = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppTheme.secondaryTextColor;

    return SafeArea(
      top: false,
      child: Container(
        key: const Key('chat_input_safe_area'),
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: surface,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? theme.colorScheme.outlineVariant
                  : AppTheme.border,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: widget.isSending ? null : _showImageSourceSheet,
              icon: Icon(Icons.add_rounded, size: 24.w),
              tooltip: '사진 선택',
              color: muted,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: 44, maxHeight: 104.h),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: inputSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl.r),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    readOnly: widget.isSending,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) => _handleSendText(),
                    style: TextStyle(
                      fontSize: AppTheme.fontBody.sp,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.isSending
                          ? '메시지를 보내는 중입니다'
                          : '메시지를 입력하세요',
                      hintStyle: TextStyle(
                        fontSize: AppTheme.fontCaption.sp,
                        color: muted,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 11.h,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 4.w),
            if (widget.isSending)
              const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              IconButton(
                onPressed: _hasText ? _handleSendText : null,
                tooltip: '메시지 전송',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(
                  Icons.send_rounded,
                  size: 22.w,
                  color: _hasText ? AppTheme.actionBase : muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreviewDialog extends StatefulWidget {
  final List<File> images;
  final ValueChanged<List<File>> onSend;

  const _ImagePreviewDialog({required this.images, required this.onSend});

  @override
  State<_ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<_ImagePreviewDialog> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(16.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.images.length > 1
                      ? '${_currentPage + 1} / ${widget.images.length}'
                      : '미리보기',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, size: 24.w),
                ),
              ],
            ),
          ),
          // Image preview
          SizedBox(
            height: 300.h,
            child: widget.images.length == 1
                ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Image.file(
                        widget.images.first,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                  )
                : PageView.builder(
                    controller: _pageController,
                    itemCount: widget.images.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: Image.file(
                            widget.images[index],
                            fit: BoxFit.contain,
                            width: double.infinity,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Page indicator dots for multi-image
          if (widget.images.length > 1)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => Container(
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    width: 6.w,
                    height: 6.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentPage
                          ? AppTheme.primaryColor
                          : Colors.grey[300],
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(height: 12.h),
          // Buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      side: const BorderSide(color: AppTheme.dividerColor),
                    ),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSend(widget.images);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.actionBase,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      widget.images.length > 1
                          ? '보내기 (${widget.images.length})'
                          : '보내기',
                      style: TextStyle(fontSize: 15.sp),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}
