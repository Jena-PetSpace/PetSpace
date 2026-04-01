import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';

class MyMenuList extends StatelessWidget {
  const MyMenuList({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          _buildMenuItem(
            context,
            emoji: '\uD83D\uDC3E',
            label: '반려동물 관리',
            onTap: () => context.push('/pets'),
          ),
          _buildDivider(),
          _buildMenuItem(
            context,
            emoji: '\uD83D\uDCDD',
            label: '내 게시글',
            onTap: () => context.push('/my/posts'),
          ),
          _buildDivider(),
          _buildMenuItem(
            context,
            emoji: '\uD83D\uDCAC',
            label: '채팅',
            onTap: () => context.push('/chat'),
          ),
          _buildDivider(),
          _buildMenuItem(
            context,
            emoji: '\uD83D\uDD16',
            label: '저장한 글',
            onTap: () => context.push('/my/saved'),
          ),
          _buildDivider(),
          _buildMenuItem(
            context,
            emoji: '\uD83D\uDD14',
            label: '알림 설정',
            onTap: () => context.push('/settings/notification'),
          ),
          _buildDivider(),
          _buildMenuItem(
            context,
            emoji: '\u2699\uFE0F',
            label: '설정',
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String emoji,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Text(emoji, style: TextStyle(fontSize: 18.sp)),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppTheme.primaryTextColor,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.lightTextColor,
              size: 20.w,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 16.w,
      endIndent: 16.w,
      color: const Color(0xFFF0F0F0),
    );
  }
}
