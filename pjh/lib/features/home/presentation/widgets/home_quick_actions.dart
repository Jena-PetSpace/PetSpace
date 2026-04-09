import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        emoji: '📊',
        label: '건강 기록',
        sub: '기록 추가하기',
        color: AppTheme.accentColor,
        onTap: () => context.go('/health'),
      ),
      _QuickAction(
        emoji: '🏥',
        label: '병원 찾기',
        sub: '주변 동물병원',
        color: const Color(0xFF4CAF50),
        onTap: () => context.push('/hospital'),
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: actions
            .map(
              (a) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: a == actions.last ? 0 : 8.w,
                  ),
                  child: _buildActionCard(context, a),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, _QuickAction action) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppTheme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
                child: Text(action.emoji, style: TextStyle(fontSize: 20.sp)),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    action.sub,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  final String emoji;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.emoji,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });
}
