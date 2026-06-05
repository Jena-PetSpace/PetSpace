import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/entities/mbti_content.dart';
import '../../domain/entities/pet_mbti_result.dart';
import '../theme/mbti_theme.dart';

/// 4축 퍼센트 바 1개.
///
/// 레이아웃(레퍼런스 기준):
///   [좌극 코드]  좌% ────바──── 우%  [우극 코드]
///    외향        56%  [그룹색|연회색]  44%   내향
/// - 좌측 극 = posCode(E/S/T/J), 우측 극 = negCode(I/N/F/P).
/// - 막대는 좌측 극 점유율(posCount/total)만큼 채우고 나머지는 연회색.
/// - 우세 극 쪽(코드·라벨·%·막대)은 그룹색으로 강조, 열세 쪽은 연회색.
class MbtiAxisBar extends StatelessWidget {
  final MbtiAxis axis;
  final AxisScore score;
  final Color groupColor;

  const MbtiAxisBar({
    super.key,
    required this.axis,
    required this.score,
    required this.groupColor,
  });

  @override
  Widget build(BuildContext context) {
    final total = score.total;
    // 좌측(pos) 점유율. 가중 점수 기준.
    final posRatio = total == 0 ? 0.5 : score.positiveCount / total;
    final posPercent = (posRatio * 100).round();
    final negPercent = 100 - posPercent;
    final posDominant = score.positiveCount > score.negativeCount;

    const inactive = MbtiTheme.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 좌측 극 코드 + 라벨
        _poleLabel(
          code: axis.posCode,
          label: axis.posLabel,
          active: posDominant,
          alignEnd: false,
          inactive: inactive,
        ),
        SizedBox(width: 12.w),
        // 가운데: 퍼센트(좌/우) + 막대
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$posPercent%',
                    style: TextStyle(
                      fontSize: 9.8.sp,
                      fontWeight: FontWeight.w800,
                      color: posDominant ? groupColor : inactive,
                    ),
                  ),
                  Text(
                    '$negPercent%',
                    style: TextStyle(
                      fontSize: 9.8.sp,
                      fontWeight: FontWeight.w800,
                      color: !posDominant ? groupColor : inactive,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              _bar(posRatio.toDouble(), posDominant),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        // 우측 극 코드 + 라벨
        _poleLabel(
          code: axis.negCode,
          label: axis.negLabel,
          active: !posDominant,
          alignEnd: true,
          inactive: inactive,
        ),
      ],
    );
  }

  Widget _poleLabel({
    required String code,
    required String label,
    required bool active,
    required bool alignEnd,
    required Color inactive,
  }) {
    return SizedBox(
      width: 36.w,
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            code,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: active ? groupColor : inactive,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? groupColor : inactive,
            ),
          ),
        ],
      ),
    );
  }

  /// 좌측 극 점유율만큼 채우는 막대. 우세 쪽은 그룹색, 열세 쪽은 연회색.
  Widget _bar(double posRatio, bool posDominant) {
    final fillColor = groupColor;
    final emptyColor = groupColor.withValues(alpha: 0.12);
    final leftColor = posDominant ? fillColor : emptyColor;
    final rightColor = posDominant ? emptyColor : fillColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(100.r),
      child: SizedBox(
        height: 14.h,
        child: Row(
          children: [
            Expanded(
              flex: (posRatio * 1000).round().clamp(1, 999),
              child: Container(color: leftColor),
            ),
            Expanded(
              flex: ((1 - posRatio) * 1000).round().clamp(1, 999),
              child: Container(color: rightColor),
            ),
          ],
        ),
      ),
    );
  }
}
