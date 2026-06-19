import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../themes/app_theme.dart';

/// 헤더 3표현(.page / .steps / hero)이 "한 가족"으로 읽히도록 공유하는
/// 타이포 토큰. 헤더 종류에 따라 크기·정렬만 달라지고 색·굵기는 동일하다.
/// (hero는 PetSpaceHeroHeader가 이 토큰을 그대로 사용)
class PetSpaceHeaderTokens {
  PetSpaceHeaderTokens._();

  static const Color titleColor = AppTheme.primaryTextColor;
  static const Color subtitleColor = AppTheme.secondaryTextColor;
  static const FontWeight titleWeight = FontWeight.bold;

  /// 앱바(.page/.steps) 중앙 타이틀
  static TextStyle appBarTitle() => TextStyle(
        color: titleColor,
        fontWeight: titleWeight,
        fontSize: 18.sp,
      );

  /// hero(로그인/가입) 대형 좌측 타이틀
  static TextStyle heroTitle() => TextStyle(
        color: titleColor,
        fontWeight: titleWeight,
        fontSize: 28.sp,
        height: 1.3,
      );

  static TextStyle heroSubtitle() => TextStyle(
        color: subtitleColor,
        fontSize: 16.sp,
      );
}

/// 앱 공용 상단 헤더.
///
/// onboarding/auth의 제각각 AppBar를 두 표현으로 수렴한다.
/// - [PetSpaceAppBar.page]  : 뒤로(선택) + 중앙 타이틀 + trailing(선택)
/// - [PetSpaceAppBar.steps] : 위 + 우측 'N/M' + 상단 세그먼트 진행바 (가입 퍼널)
///
/// 로그인/가입의 대형 좌측 타이틀은 상단바가 아닌 body 요소이므로
/// [PetSpaceHeroHeader]로 분리하되, 타이포 토큰을 공유해 같은 디자인 언어를 쓴다.
/// (표현 계층만 — 라우팅·상태는 호출부가 그대로 주입)
class PetSpaceAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Color backgroundColor;

  /// steps 모드에서만 사용(1-based 현재 단계 / 전체 단계).
  final int? step;
  final int? totalSteps;

  /// 뒤로 + 중앙 타이틀 (+ trailing). onBack 이 null 이면 뒤로가기 미표시.
  const PetSpaceAppBar.page({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.backgroundColor = Colors.transparent,
  })  : step = null,
        totalSteps = null;

  /// 가입 퍼널: 뒤로 + 중앙 타이틀 + 'N/M' + 세그먼트 진행바.
  const PetSpaceAppBar.steps({
    super.key,
    required this.title,
    required int this.step,
    required int this.totalSteps,
    required VoidCallback this.onBack,
    this.backgroundColor = Colors.transparent,
  }) : trailing = null;

  bool get _isSteps => step != null;

  static const double _barAreaHeight = 24;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (_isSteps ? _barAreaHeight : 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: onBack != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: AppTheme.primaryTextColor),
              onPressed: onBack,
            )
          : null,
      title: Text(title, style: PetSpaceHeaderTokens.appBarTitle()),
      actions: [
        if (_isSteps)
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: Center(
              child: Text(
                '$step / $totalSteps',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            ),
          )
        else if (trailing != null)
          trailing!,
      ],
      bottom: _isSteps ? _StepProgressBar(step: step!, total: totalSteps!) : null,
    );
  }
}

/// 가입 퍼널 세그먼트 진행바(AppBar.bottom).
class _StepProgressBar extends StatelessWidget implements PreferredSizeWidget {
  final int step;
  final int total;

  const _StepProgressBar({required this.step, required this.total});

  @override
  Size get preferredSize => const Size.fromHeight(24);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
      child: Row(
        children: List.generate(total, (i) {
          final filled = i < step;
          return Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 3.w),
              height: 4,
              decoration: BoxDecoration(
                color: filled
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          );
        }),
      ),
    );
  }
}
