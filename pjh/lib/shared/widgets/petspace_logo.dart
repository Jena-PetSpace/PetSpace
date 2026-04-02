import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// PetSpace 브랜드 로고 위젯
///
/// 원본 로고 구조: "Pet" + "S[P에 발바닥 통합]ace" = "PetSpace"
/// 별도 심볼 없음 — 로고 자체에 발바닥이 내포된 워드마크 디자인
///
/// [variant]
/// - light  : 라이트 배경용 (딥블루 텍스트 + 코랄 발바닥)
/// - dark   : 다크/Primary 배경용 (흰 텍스트 + 코랄 발바닥)
/// - mono   : 단색 필요 시 (딥블루 전체)
enum LogoVariant { light, dark, mono }

class PetSpaceLogo extends StatelessWidget {
  final LogoVariant variant;

  /// 로고 높이 (가로는 비율에 맞게 자동)
  final double height;

  const PetSpaceLogo({
    super.key,
    this.variant = LogoVariant.dark,
    this.height = 32,
  });

  String get _assetPath {
    switch (variant) {
      case LogoVariant.light:
        return 'assets/svg/logo_color.svg';
      case LogoVariant.dark:
        return 'assets/svg/logo_white.svg';
      case LogoVariant.mono:
        return 'assets/svg/logo_mono.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _assetPath,
      height: height,
      fit: BoxFit.contain,
    );
  }
}
