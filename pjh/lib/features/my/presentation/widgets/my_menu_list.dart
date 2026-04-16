import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';

class MyMenuList extends StatelessWidget {
  const MyMenuList({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroup(context, label: '내 활동', items: [
            const _MenuItem(emoji: '🐾', label: '반려동물 관리', route: '/pets'),
            const _MenuItem(emoji: '📝', label: '내 게시글', route: '/my/posts'),
            const _MenuItem(emoji: '🔖', label: '저장한 글', route: '/my/saved'),
              const _MenuItem(emoji: '🤖', label: 'AI분석 히스토리', route: '/ai-history'),
          ]),
          SizedBox(height: 8.h),
          _buildGroup(context, label: '소통', items: [
            const _MenuItem(emoji: '💬', label: '채팅', route: '/chat'),
          ]),
          SizedBox(height: 8.h),
          _buildGroup(context, label: '설정', items: [
            const _MenuItem(emoji: '📡', label: '채널 구독', route: '/channels'),
              const _MenuItem(emoji: '🏥', label: '건강 알림 설정', route: '/health/alert-settings'),
              const _MenuItem(emoji: '🔔', label: '알림 설정', route: '/settings/notification'),
            const _MenuItem(emoji: '⚙️', label: '설정', route: '/settings'),
          ]),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, {required String label, required List<_MenuItem> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 6.h),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.secondaryTextColor,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _buildMenuItem(context, items[i]),
                if (i < items.length - 1)
                  Divider(height: 1, indent: 50.w, color: const Color(0xFFF0F0F0)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, _MenuItem item) {
    return InkWell(
      onTap: () => context.push(item.route),
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Text(item.emoji, style: TextStyle(fontSize: 19.sp)),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryTextColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.lightTextColor, size: 20.w),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final String emoji;
  final String label;
  final String route;
  const _MenuItem({required this.emoji, required this.label, required this.route});
}
