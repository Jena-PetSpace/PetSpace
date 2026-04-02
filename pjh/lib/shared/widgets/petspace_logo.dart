import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../themes/app_theme.dart';

/// PetSpace 브랜드 로고 위젯
///
/// [variant]
/// - light  : 라이트 배경용 (딥블루 "Pet" + 코랄 "Space" + 코랄심볼)
/// - dark   : 다크/Primary 배경용 (흰 "Pet" + 코랄 "Space" + 화이트심볼)
/// - symbol : 심볼(발바닥 원형)만 표시
enum LogoVariant { light, dark, symbol }

class PetSpaceLogo extends StatelessWidget {
  final LogoVariant variant;

  /// 심볼 + 텍스트 전체 높이 기준
  final double height;

  const PetSpaceLogo({
    super.key,
    this.variant = LogoVariant.dark,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    if (variant == LogoVariant.symbol) return _symbol();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _symbol(),
        SizedBox(width: height * 0.28),
        _text(),
      ],
    );
  }

  Widget _symbol() {
    final String asset;
    switch (variant) {
      case LogoVariant.light:
        asset = 'assets/svg/logo_symbol.svg';      // 코랄 배경 흰 발바닥
      case LogoVariant.dark:
        asset = 'assets/svg/logo_symbol_primary.svg'; // 반투명 배경 흰 발바닥
      case LogoVariant.symbol:
        asset = 'assets/svg/logo_symbol.svg';
    }

    return SvgPicture.asset(
      asset,
      width: height,
      height: height,
    );
  }

  Widget _text() {
    final petColor = variant == LogoVariant.light
        ? AppTheme.primaryColor
        : Colors.white;

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Pet',
            style: TextStyle(
              fontSize: height * 0.7,
              fontWeight: FontWeight.w800,
              color: petColor,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          TextSpan(
            text: 'Space',
            style: TextStyle(
              fontSize: height * 0.7,
              fontWeight: FontWeight.w800,
              color: AppTheme.highlightColor, // 코랄 고정
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
