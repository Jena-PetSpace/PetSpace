import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../themes/app_theme.dart';

/// 표준 RefreshIndicator + 새로고침 시작 시 mediumImpact 햅틱.
///
/// iOS 와 Android 모두에서 일관된 새로고침 감각을 제공하기 위한 래퍼.
/// 기존 RefreshIndicator 사용 코드는 그대로 두되, 신규 화면이나
/// 점진적 통일 시 본 위젯으로 교체.
class HapticRefreshIndicator extends StatelessWidget {
  const HapticRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.backgroundColor,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: color ?? AppTheme.primaryColor,
      backgroundColor: backgroundColor,
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        await onRefresh();
      },
      child: child,
    );
  }
}
