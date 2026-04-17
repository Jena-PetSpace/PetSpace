import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class MySettingsPage extends StatelessWidget {
  const MySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '설정',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGroupLabel('내 활동'),
            _buildGroup([
              _buildTile(
                context,
                icon: Icons.pets_outlined,
                bgColor: const Color(0xFFE6F1FB),
                label: '내 반려동물 관리',
                onTap: () => context.push('/pets'),
              ),
              _buildTile(
                context,
                icon: Icons.bar_chart_outlined,
                bgColor: const Color(0xFFEAF3DE),
                label: 'AI 분석 히스토리',
                onTap: () => context.push('/ai-history-page'),
              ),
              _buildTile(
                context,
                icon: Icons.card_giftcard_outlined,
                bgColor: const Color(0xFFFAECE7),
                label: '리워드 스토어',
                onTap: () => context.push('/reward'),
              ),
            ]),
            SizedBox(height: 20.h),
            _buildGroupLabel('계정'),
            _buildGroup([
              _buildTile(
                context,
                icon: Icons.edit_outlined,
                bgColor: const Color(0xFFF1EFE8),
                label: '프로필 편집',
                onTap: () => context.push('/my/edit-profile'),
              ),
              _buildTile(
                context,
                icon: Icons.notifications_none_outlined,
                bgColor: const Color(0xFFFBEAF0),
                label: '알림 설정',
                onTap: () => context.push('/settings/notification'),
              ),
              _buildTile(
                context,
                icon: Icons.lock_outline,
                bgColor: const Color(0xFFF1EFE8),
                label: '개인정보처리방침',
                onTap: () => context.push('/privacy'),
              ),
              _buildTile(
                context,
                icon: Icons.info_outline,
                bgColor: const Color(0xFFF1EFE8),
                label: '앱 정보 · 버전',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'PetSpace',
                  applicationVersion: '1.0.0',
                ),
              ),
            ]),
            SizedBox(height: 20.h),
            _buildGroupLabel('계정 관리'),
            _buildGroup([
              _buildTile(
                context,
                icon: Icons.logout,
                bgColor: const Color(0xFFFCEBEB),
                label: '로그아웃',
                textColor: AppTheme.errorColor,
                showChevron: false,
                onTap: () => _confirmLogout(context),
              ),
              _buildTile(
                context,
                icon: Icons.warning_amber,
                bgColor: const Color(0xFFFCEBEB),
                label: '회원탈퇴',
                textColor: AppTheme.errorColor,
                showChevron: false,
                onTap: () => _confirmDelete(context),
              ),
            ]),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: AppTheme.secondaryTextColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildGroup(List<Widget> tiles) {
    return Container(
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
          for (int i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1)
              Divider(height: 1, indent: 52.w, color: const Color(0xFFF0F0F0)),
          ],
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required Color bgColor,
    required String label,
    required VoidCallback onTap,
    Color? textColor,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, size: 18.w,
                  color: textColor ?? AppTheme.primaryTextColor),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? AppTheme.primaryTextColor,
                ),
              ),
            ),
            if (showChevron)
              Icon(Icons.chevron_right_rounded,
                  color: AppTheme.lightTextColor, size: 20.w),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(AuthSignOutRequested());
            },
            child: const Text('로그아웃',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text('탈퇴 시 모든 데이터가 삭제되며\n복구할 수 없습니다. 정말 탈퇴하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('탈퇴',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}
