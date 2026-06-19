import 'package:flutter/material.dart';

import '../themes/app_theme.dart';

/// 아이콘 원형 배지의 의미(맥락) 톤.
///
/// 맥락별 적용 규칙(묶음1 기준):
/// - [neutral] : 온보딩 안내/가이드 (slides, tutorial)
/// - [feature] : 인증·보안 (email-verification, password-reset)
/// - [success] : 완료/성공 (complete, tutorial 완료)
enum BadgeTone { neutral, feature, success }

/// 화면마다 제각각이던 `Container(circle)+Icon` 인라인 구현을 한 규칙으로 수렴한
/// 공용 아이콘 원형 배지.
///
/// 배경은 base 색의 10%, 아이콘은 base 색, (옵션) 테두리는 30%.
class IconBadgeCircle extends StatelessWidget {
  final IconData icon;

  /// 원 지름(아이콘은 약 42%).
  final double size;

  final BadgeTone tone;

  /// 톤 enum으로 덮이지 않는 경우(예: 묶음3 감정 9종 팔레트)만 사용.
  /// **반드시 AppTheme 토큰 색만 전달할 것** — raw hex 금지(하드코딩 재유입 방지).
  final Color? toneOverride;

  /// 테두리 링 표시(예: complete).
  final bool ring;

  /// 우하단 오버레이 배지(예: 성공 체크).
  final Widget? cornerBadge;

  const IconBadgeCircle({
    super.key,
    required this.icon,
    this.size = 96,
    this.tone = BadgeTone.feature,
    this.toneOverride,
    this.ring = false,
    this.cornerBadge,
  });

  Color get _base {
    if (toneOverride != null) return toneOverride!;
    switch (tone) {
      case BadgeTone.neutral:
        return AppTheme.secondaryTextColor;
      case BadgeTone.feature:
        return AppTheme.primaryColor;
      case BadgeTone.success:
        return AppTheme.successColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = _base;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: base.withValues(alpha: 0.1),
            border: ring
                ? Border.all(color: base.withValues(alpha: 0.3), width: 3)
                : null,
          ),
          child: Icon(icon, size: size * 0.42, color: base),
        ),
        if (cornerBadge != null)
          Positioned(
            right: size * 0.06,
            bottom: size * 0.06,
            child: cornerBadge!,
          ),
      ],
    );
  }
}

/// IconBadgeCircle.cornerBadge 용 표준 성공 체크(작은 원형 체크).
/// complete의 '발바닥 + 성공 체크' 합성에 사용.
class SuccessCheckBadge extends StatelessWidget {
  final double size;
  const SuccessCheckBadge({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.successColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.successColor.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(Icons.check, color: Colors.white, size: size * 0.6),
    );
  }
}
