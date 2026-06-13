import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../shared/themes/app_theme.dart';

/// 분석 입력 화면의 "추가 정보 입력 (선택)" 섹션.
/// - 헤더 탭으로 펼침/접힘 토글, 펼친 상태에서 100자 제한 TextField + 글자수 카운터
/// 상태(_showAdditionalInput)·컨트롤러(_additionalCtrl)는 부모가 관리,
/// 위젯은 표시·토글 콜백 전달만.
class AdditionalInputSection extends StatelessWidget {
  final TextEditingController controller;
  final bool expanded;
  final void Function(bool) onToggle;

  const AdditionalInputSection({
    super.key,
    required this.controller,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => onToggle(!expanded),
          child: Row(
            children: [
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.add_circle_outline,
                size: 18.w,
                color: AppTheme.primaryColor,
              ),
              SizedBox(width: 6.w),
              Text(
                expanded ? '추가 정보 접기' : '추가 정보 입력 (선택)',
                style: TextStyle(fontSize: 12.sp, color: AppTheme.primaryColor),
              ),
              const Spacer(),
              if (expanded)
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (_, value, __) {
                    final len = value.text.length;
                    final isNear = len >= 80;
                    return Text(
                      '$len/100자',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isNear ? AppTheme.highlightColor : AppTheme.secondaryTextColor,
                        fontWeight: isNear ? FontWeight.w600 : FontWeight.w400,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        if (expanded) ...[
          SizedBox(height: 8.h),
          TextField(
            controller: controller,
            maxLength: 100,
            maxLines: 3,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            decoration: InputDecoration(
              hintText: '장소, 상황, 특이사항 등\nex) 산책 직후, 방금 목욕을 마쳤어요',
              hintStyle: TextStyle(fontSize: 11.sp, color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              contentPadding: EdgeInsets.all(12.w),
            ),
          ),
        ],
      ],
    );
  }
}
