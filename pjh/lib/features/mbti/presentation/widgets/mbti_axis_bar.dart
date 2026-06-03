import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/entities/mbti_content.dart';
import '../../domain/entities/pet_mbti_result.dart';
import '../theme/mbti_theme.dart';

/// 4축 퍼센트 바 1개.
///
/// 목업 기준: 양쪽 극 라벨(E 외향 / I 내향) + 우세 극 퍼센트 + 우세 쪽에서
/// 채워지는 막대 + 그룹색. 0%/100% 도 그대로 노출.
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
    final dominant = score.dominantPole; // 'E' 등
    final percent = score.dominantPercent; // 60/80/100
    final posDominant = dominant == axis.posCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 축 이름 (예: 사교성)
        Text(
          axis.name,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: MbtiTheme.textSecondary,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            _poleLabel(
              code: axis.posCode,
              label: axis.posLabel,
              active: posDominant,
            ),
            SizedBox(width: 10.w),
            Expanded(child: _bar(posDominant, percent)),
            SizedBox(width: 10.w),
            _poleLabel(
              code: axis.negCode,
              label: axis.negLabel,
              active: !posDominant,
              alignEnd: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _poleLabel({
    required String code,
    required String label,
    required bool active,
    bool alignEnd = false,
  }) {
    return SizedBox(
      width: 56.w,
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            code,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? groupColor : MbtiTheme.textSecondary,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: active ? groupColor : MbtiTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 우세 쪽에서 채워지는 막대. 가운데 기준이 아니라, 우세 극 방향으로
  /// percent 만큼 그룹색으로 채운다.
  Widget _bar(bool posDominant, int percent) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100.r),
      child: Stack(
        children: [
          Container(
            height: 10.h,
            decoration: BoxDecoration(
              color: groupColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(100.r),
            ),
          ),
          // 우세 퍼센트 + 우세 극 퍼센트 라벨
          Align(
            alignment:
                posDominant ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: (percent / 100).clamp(0.0, 1.0),
              child: Container(
                height: 10.h,
                decoration: BoxDecoration(
                  color: groupColor,
                  borderRadius: BorderRadius.circular(100.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 우세 극 퍼센트 텍스트(막대 위 보조 표기용). 결과 페이지에서 축 행 우측에
/// 함께 노출할 수 있도록 분리.
class MbtiAxisPercentText extends StatelessWidget {
  final AxisScore score;
  final Color groupColor;

  const MbtiAxisPercentText({
    super.key,
    required this.score,
    required this.groupColor,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '${score.dominantPole} ${score.dominantPercent}%',
      style: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: groupColor,
      ),
    );
  }
}
