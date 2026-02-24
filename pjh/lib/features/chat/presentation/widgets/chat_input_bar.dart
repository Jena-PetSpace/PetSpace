import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

class ChatInputBar extends StatefulWidget {
  final bool isSending;
  final ValueChanged<String> onSendText;
  final ValueChanged<File> onSendImage;

  const ChatInputBar({
    super.key,
    this.isSending = false,
    required this.onSendText,
    required this.onSendImage,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSendText() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isSending) return;
    widget.onSendText(text);
    _controller.clear();
  }

  Future<void> _handlePickImage() async {
    if (widget.isSending) return;

    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image != null) {
      widget.onSendImage(File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 8.w,
        right: 8.w,
        top: 8.h,
        bottom: 8.h + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4.r,
            offset: Offset(0, -2.h),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _handlePickImage,
            icon: Icon(Icons.add_photo_alternate_outlined, size: 24.w),
            color: Colors.grey[600],
          ),
          Expanded(
            child: Container(
              constraints: BoxConstraints(maxHeight: 100.h),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: TextField(
                controller: _controller,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSendText(),
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요',
                  hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 4.w),
          widget.isSending
              ? Padding(
                  padding: EdgeInsets.all(8.w),
                  child: SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  onPressed: _hasText ? _handleSendText : null,
                  icon: Icon(
                    Icons.send_rounded,
                    size: 24.w,
                    color: _hasText
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[400],
                  ),
                ),
        ],
      ),
    );
  }
}
