import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theme/emotion_result_tokens.dart';

/// 결과 페이지 하단 액션 바.
/// - 베이지 배경 + 0.5px 상단 베이지 디바이더
/// - 3개 액션: 공유(40x40 흰 박스), 저장(40x40 흰 박스), 히스토리(flex 코랄 버튼)
/// - fromHistory=true 일 때 히스토리 버튼이 "닫기"로 동작
/// - 감정/건강 페이지 모두 "분석 기록 모아보기"로 통일
class BottomActionBar extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onHistory;
  final bool fromHistory;

  const BottomActionBar({
    super.key,
    required this.onShare,
    required this.onSave,
    required this.onHistory,
    this.fromHistory = false,
  });

  String get _mainButtonLabel {
    if (fromHistory) return '닫기';
    return '분석 기록 모아보기';
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: EmotionResultTokens.cardSurface,
        borderRadius: BorderRadius.circular(10.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.r),
          child: SizedBox(
            width: 40.r,
            height: 40.r,
            child: Icon(
              icon,
              size: 18.r,
              color: EmotionResultTokens.grayDark,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EmotionResultTokens.background,
        border: Border(
          top: BorderSide(
            color: EmotionResultTokens.dividerLight,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Row(
            children: [
              _iconButton(
                icon: Icons.share_outlined,
                onTap: onShare,
                tooltip: '공유하기',
              ),
              SizedBox(width: 8.w),
              _iconButton(
                icon: Icons.bookmark_outline,
                onTap: onSave,
                tooltip: '메모 남기기',
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Material(
                  color: EmotionResultTokens.coral,
                  borderRadius: BorderRadius.circular(10.r),
                  child: InkWell(
                    onTap: onHistory,
                    borderRadius: BorderRadius.circular(10.r),
                    child: SizedBox(
                      height: 40.r,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            fromHistory ? Icons.close : Icons.history,
                            size: 16.r,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            _mainButtonLabel,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
