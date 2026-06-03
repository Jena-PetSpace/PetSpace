import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/mbti_theme.dart';

/// 문항 선택지(A/B) 카드. 선택 시 네이비 보더 + 연한 네이비 배경으로 강조.
class MbtiChoiceCard extends StatelessWidget {
  final String badge; // 'A' | 'B'
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const MbtiChoiceCard({
    super.key,
    required this.badge,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? MbtiTheme.navy : MbtiTheme.navy.withValues(alpha: 0.12);
    final bgColor =
        selected ? MbtiTheme.navy.withValues(alpha: 0.06) : Colors.white;

    return Semantics(
      button: true,
      selected: selected,
      label: '선택지 $badge: $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 20.h),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: borderColor,
                width: selected ? 2 : 1.2,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: MbtiTheme.navy.withValues(alpha: 0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32.w,
                  height: 32.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? MbtiTheme.navy : MbtiTheme.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : MbtiTheme.textSecondary,
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15.sp,
                      height: 1.35,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      color: MbtiTheme.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: MbtiTheme.navy, size: 22.w),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
