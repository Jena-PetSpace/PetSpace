import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// PetSpace 브랜드 로고 위젯
/// - light : 라이트 배경 → 딥블루 컬러 로고
/// - dark  : 다크/딥블루 배경 → 흰색 로고
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
    if (variant == LogoVariant.dark) {
      // 딥블루 배경용: 원본 로고를 흰색으로 변환
      return SvgPicture.asset(
        'assets/svg/logo_petspace_img.svg',
        height: height,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.matrix(<double>[
          // R채널을 흰색으로
          0, 0, 0, 0, 1,
          0, 0, 0, 0, 1,
          0, 0, 0, 0, 1,
          0, 0, 0, 1, 0,
        ]),
      );
    }
    // 라이트 배경용: 원본 컬러 그대로
    return SvgPicture.asset(
      'assets/svg/logo_petspace_img.svg',
      height: height,
      fit: BoxFit.contain,
    );
  }
}
