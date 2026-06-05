import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../mbti/presentation/theme/mbti_theme.dart';

/// 운세 별점(★) 표시. MBTI 4축 퍼센트 바와 헷갈리지 않게 운세는 별점 UI 로 구분.
///
/// 브랜드 규칙: 빨강 금지. 채워진 별은 코랄, 빈 별은 연회색.
/// (사고운·냥아치력 같은 말썽 항목도 동일 — 점수 높다고 빨강 쓰지 않음.)
class FortuneStars extends StatelessWidget {
  final int star; // 1~5
  final double size;

  /// 채운 별 색(기본 코랄). 강조가 필요한 곳에서 네이비로 바꿔 쓸 수 있음.
  final Color? filledColor;

  const FortuneStars({
    super.key,
    required this.star,
    this.size = 16,
    this.filledColor,
  });

  @override
  Widget build(BuildContext context) {
    final filled = filledColor ?? MbtiTheme.coral;
    final empty = Colors.grey.shade300;
    final clamped = star.clamp(1, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          Icon(
            i <= clamped ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size.sp,
            color: i <= clamped ? filled : empty,
          ),
      ],
    );
  }
}

/// 종합 별점에 대응하는 이모지(세부 평균 기준). 빨강/부정 표현 없이 톤만 차등.
String fortuneStarEmoji(int star) {
  switch (star.clamp(1, 5)) {
    case 5:
      return '🌟';
    case 4:
      return '😺';
    case 3:
      return '🐾';
    case 2:
      return '🍃';
    default:
      return '☁️';
  }
}
