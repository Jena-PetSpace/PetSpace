import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';

/// 가입 퍼널(약관 → 프로필 → 반려동물 등록) 공용 헤더.
///
/// `[뒤로가기] + 타이틀 + 'N / M'` 앱바와 상단 **세그먼트 진행바**로
/// "지금 몇 번째 의무 단계인지"를 일관되게 표시한다.
///
/// 스킵 가능한 튜토리얼(감정분석 가이드)은 이 헤더 대신 **콘텐츠 페이지 닷**을
/// 사용한다 — 의무 절차(세그먼트바)와 선택 안내(닷)를 시각적으로 구분하기 위함.
/// (표현 계층만 통일하며 라우팅·상태는 변경하지 않는다.)
class OnboardingStepHeader extends StatelessWidget
    implements PreferredSizeWidget {
  /// 앱바 중앙 타이틀(짧은 내비 라벨).
  final String title;

  /// 현재 단계(1-based).
  final int step;

  /// 전체 단계 수.
  final int totalSteps;

  /// 뒤로가기 동작(라우팅은 각 화면이 그대로 주입 — 본 컴포넌트는 표현만 담당).
  final VoidCallback onBack;

  /// 앱바 배경색(화면별 배경에 맞춤). 기본 투명.
  final Color backgroundColor;

  const OnboardingStepHeader({
    super.key,
    required this.title,
    required this.step,
    required this.totalSteps,
    required this.onBack,
    this.backgroundColor = Colors.transparent,
  });

  static const double _barHeight = 4;
  static const double _barAreaHeight = 24;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + _barAreaHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: onBack,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
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
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(_barAreaHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
          child: Row(
            children: List.generate(totalSteps, (i) {
              final filled = i < step;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 3.w),
                  height: _barHeight,
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
        ),
      ),
    );
  }
}
