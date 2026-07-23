import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 작성·편집·인증 화면의 고정 하단 액션 영역.
///
/// 페이지 캔버스와 같은 색을 사용하고 bottom safe area를 이 위젯 한 곳에서만
/// 처리해, 흰색 footer와 별도 safe-area 띠가 겹쳐 보이는 현상을 막는다.
class PetSpaceBottomActionBar extends StatelessWidget {
  final Widget child;
  final EdgeInsets? minimum;
  final bool showDivider;

  const PetSpaceBottomActionBar({
    super.key,
    required this.child,
    this.minimum,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                )
              : null,
        ),
        child: SafeArea(
          top: false,
          minimum: minimum ?? EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 12.h),
          child: child,
        ),
      ),
    );
  }
}
