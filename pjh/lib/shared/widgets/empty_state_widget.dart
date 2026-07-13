import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../themes/app_theme.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  // 확장 파라미터 — v2: 이모지 일러스트 제거, 아이콘 단일 체계
  final String? secondaryLabel;  // 보조 버튼 레이블
  final VoidCallback? onSecondary;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// 검색 결과가 없을 때 사용하는 표준 EmptyState.
  factory EmptyStateWidget.searchNoResult({
    Key? key,
    String? query,
  }) {
    return EmptyStateWidget(
      key: key,
      icon: Icons.search_off,
      title: '검색 결과가 없어요',
      subtitle: query != null && query.isNotEmpty
          ? '"$query" 와(과) 일치하는 결과가 없습니다.\n다른 단어로 다시 검색해보세요.'
          : '다른 키워드로 다시 검색해보세요.',
    );
  }

  /// 네트워크 오류 시 사용하는 표준 EmptyState.
  factory EmptyStateWidget.networkError({
    Key? key,
    required VoidCallback onRetry,
  }) {
    return EmptyStateWidget(
      key: key,
      icon: Icons.wifi_off,
      title: '연결이 불안정해요',
      subtitle: '인터넷 연결을 확인하고 다시 시도해주세요.',
      actionLabel: '다시 시도',
      onAction: onRetry,
    );
  }

  /// 일반 오류 시 사용하는 표준 EmptyState.
  factory EmptyStateWidget.error({
    Key? key,
    String? message,
    VoidCallback? onRetry,
  }) {
    return EmptyStateWidget(
      key: key,
      icon: Icons.error_outline,
      title: '문제가 발생했어요',
      subtitle: message ?? '잠시 후 다시 시도해주세요.',
      actionLabel: onRetry != null ? '다시 시도' : null,
      onAction: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 일러스트 영역 — v2: 아이콘 단일 체계 (이모지 제거)
            Container(
              width: 100.w,
              height: 100.w,
              decoration: const BoxDecoration(
                color: AppTheme.actionContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48.w,
                color: isDark ? AppTheme.infoSky : AppTheme.actionBase,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : AppTheme.primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13.sp,
                color: isDark ? Colors.white38 : AppTheme.secondaryTextColor,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            if (secondaryLabel != null || actionLabel != null) ...[
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (secondaryLabel != null && onSecondary != null) ...[
                    OutlinedButton(
                      onPressed: onSecondary,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                      ),
                      child: Text(secondaryLabel!, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(width: 10.w),
                  ],
                  if (actionLabel != null && onAction != null)
                    ElevatedButton(
                      onPressed: onAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.actionBase,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        elevation: 0,
                      ),
                      child: Text(actionLabel!, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
