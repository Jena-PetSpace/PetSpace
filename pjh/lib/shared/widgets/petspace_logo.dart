import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// PetSpace 브랜드 로고 위젯
/// - light : 라이트 배경 → 딥블루+코랄 컬러 로고 (logo_color.svg)
/// - dark  : 다크/딥블루 배경 → 흰색+코랄 로고 (logo_white.svg)
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
    final asset = variant == LogoVariant.dark
        ? 'assets/svg/logo_white.svg'
        : 'assets/svg/logo_color.svg';
    return SvgPicture.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
    );
  }
}
