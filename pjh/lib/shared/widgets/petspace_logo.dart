import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// PetSpace 브랜드 로고 위젯
/// 원본 로고 SVG 그대로 사용
/// - light : 라이트 배경 → 원본(검정) 그대로
/// - dark  : 다크/딥블루 배경 → 흰색으로 tint
enum LogoVariant { light, dark }

class PetSpaceLogo extends StatelessWidget {
  final LogoVariant variant;
  final double height;

  const PetSpaceLogo({
    super.key,
    this.variant = LogoVariant.dark,
    this.height = 22,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/svg/logo_original.svg',
      height: height,
      fit: BoxFit.contain,
      colorFilter: variant == LogoVariant.dark
          ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
          : null, // 라이트 배경: 원본 검정 그대로
    );
  }
}
