import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'petspace_app_bar.dart' show PetSpaceHeaderTokens;

/// 로그인/가입 등 루트 진입 화면의 **대형 좌측 타이틀** 헤더(body 요소).
///
/// 상단바([PetSpaceAppBar])와 구현 위치만 다를 뿐, 동일한 타이포 토큰
/// ([PetSpaceHeaderTokens])을 사용해 사용자 눈엔 "같은 앱의 헤더"로 읽힌다.
/// (뒤로가기가 없는 루트 화면용이라 AppBar가 아니라 body에 둔다.)
class PetSpaceHeroHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const PetSpaceHeroHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: PetSpaceHeaderTokens.heroTitle()),
        if (subtitle != null) ...[
          SizedBox(height: 8.h),
          Text(subtitle!, style: PetSpaceHeaderTokens.heroSubtitle()),
        ],
      ],
    );
  }
}
