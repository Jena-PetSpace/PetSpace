import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theme/emotion_result_tokens.dart';

/// 메모 저장 모달. 결과 페이지 하단 "저장" 버튼에서 호출.
/// - 200자 제한
/// - "건너뛰기" / "저장" 두 버튼
/// - 저장 시 입력 텍스트를 String?로 반환 (취소/건너뛰기 = null)
class MemoSaveModal extends StatefulWidget {
  final String? initialMemo;

  const MemoSaveModal({super.key, this.initialMemo});

  static Future<String?> show(
    BuildContext context, {
    String? initialMemo,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: MemoSaveModal(initialMemo: initialMemo),
      ),
    );
  }

  @override
  State<MemoSaveModal> createState() => _MemoSaveModalState();
}

class _MemoSaveModalState extends State<MemoSaveModal> {
  late final TextEditingController _controller;
  static const int _maxLen = 200;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialMemo ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EmotionResultTokens.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 드래그 핸들
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: EmotionResultTokens.grayInactive,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              // TODO(copy): MemoSaveModal 제목
              '이 순간 기록하기',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: EmotionResultTokens.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _controller,
              maxLength: _maxLen,
              maxLines: 4,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_maxLen),
              ],
              decoration: InputDecoration(
                // TODO(copy): MemoSaveModal placeholder
                hintText: '오늘 어땠는지 짧게 남겨주세요',
                hintStyle: TextStyle(
                  color: EmotionResultTokens.grayText,
                  fontSize: 13.sp,
                ),
                filled: true,
                fillColor: EmotionResultTokens.grayBar,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(
                fontSize: 13.sp,
                color: EmotionResultTokens.textPrimary,
                height: 1.5,
              ),
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      side: const BorderSide(
                          color: EmotionResultTokens.grayInactive),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Text(
                      // TODO(copy): MemoSaveModal 건너뛰기 버튼
                      '건너뛰기',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: EmotionResultTokens.grayDark,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final text = _controller.text.trim();
                      Navigator.of(context).pop(text.isEmpty ? null : text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EmotionResultTokens.coral,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Text(
                      // TODO(copy): MemoSaveModal 저장 버튼
                      '저장',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
