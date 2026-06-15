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
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryTextColor),
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
                bgColor: AppTheme.tilePastelBlue,
                label: '내 반려동물 관리',
                onTap: () => context.push('/pets'),
              ),
              _buildTile(
                context,
                icon: Icons.bar_chart_outlined,
                bgColor: AppTheme.tilePastelGreen,
                label: 'AI 분석 히스토리',
                onTap: () => context.push('/ai-history-page'),
              ),
              // TODO(reward): 리워드/포인트 시스템 미완성 → 진입 숨김.
              // 리워드 트랙 복원 시 아래 타일 주석 해제로 되살리기.
              // _buildTile(
              //   context,
              //   icon: Icons.card_giftcard_outlined,
              //   bgColor: AppTheme.tilePastelPeach,
              //   label: '리워드 스토어',
              //   onTap: () => context.push('/reward'),
              // ),
            ]),
            SizedBox(height: 20.h),
            _buildGroupLabel('계정'),
            _buildGroup([
              _buildTile(
                context,
                icon: Icons.person_outline,
                bgColor: AppTheme.tilePastelBlue,
                label: '계정 정보',
                onTap: () => _showAccountInfo(context),
              ),
              _buildTile(
                context,
                icon: Icons.edit_outlined,
                bgColor: AppTheme.tilePastelSand,
                label: '프로필 편집',
                onTap: () => context.push('/my/edit-profile'),
              ),
              _buildTile(
                context,
                icon: Icons.notifications_none_outlined,
                bgColor: AppTheme.tilePastelPink,
                label: '알림 설정',
                onTap: () => context.push('/settings/notification'),
              ),
            ]),
            SizedBox(height: 20.h),
            _buildGroupLabel('정보'),
            _buildGroup([
              _buildTile(
                context,
                icon: Icons.lock_outline,
                bgColor: AppTheme.tilePastelSand,
                label: '개인정보처리방침',
                onTap: () => context.push('/privacy'),
              ),
              _buildTile(
                context,
                icon: Icons.shield_outlined,
                bgColor: AppTheme.tilePastelSand,
                label: '커뮤니티 가이드라인',
                onTap: () => context.push('/community-guidelines'),
              ),
              _buildTile(
                context,
                icon: Icons.help_outline,
                bgColor: AppTheme.tilePastelSand,
                label: '도움말',
                onTap: () => context.push('/settings/help'),
              ),
              _buildTile(
                context,
                icon: Icons.info_outline,
                bgColor: AppTheme.tilePastelSand,
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
                bgColor: AppTheme.tilePastelRose,
                label: '로그아웃',
                textColor: AppTheme.errorColor,
                showChevron: false,
                onTap: () => _confirmLogout(context),
              ),
              _buildTile(
                context,
                icon: Icons.warning_amber,
                bgColor: AppTheme.tilePastelRose,
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
        color: AppTheme.surfaceColor,
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
              Divider(height: 1, indent: 52.w, color: AppTheme.dividerColor),
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

  void _showAccountInfo(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final user = authState.user;

    Widget row(IconData icon, String label, String value) => Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18.w, color: AppTheme.secondaryTextColor),
                  SizedBox(width: 8.w),
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13.sp)),
                ],
              ),
              SizedBox(height: 4.h),
              Padding(
                padding: EdgeInsets.only(left: 26.w),
                child: Text(value, style: TextStyle(fontSize: 15.sp)),
              ),
            ],
          ),
        );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('계정 정보', style: TextStyle(fontSize: 17.sp)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row(Icons.person, '닉네임', user.displayName),
            row(Icons.email, '이메일', user.email),
            row(Icons.calendar_today, '가입일',
                '${user.createdAt.year}년 ${user.createdAt.month}월 ${user.createdAt.day}일'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
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
    final authBloc = context.read<AuthBloc>();
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('회원탈퇴'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '탈퇴 후 30일이 지나면 모든 데이터가 영구 삭제됩니다.\n'
                '그 전까지는 다시 로그인하면 계정을 복구할 수 있어요.',
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: controller,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: "계속하려면 '탈퇴'를 입력하세요",
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            TextButton(
              onPressed: controller.text.trim() == '탈퇴'
                  ? () {
                      Navigator.pop(ctx);
                      // 다이얼로그가 완전히 해체된 다음 프레임에 이벤트 발행 —
                      // pop과 미인증 전환(트리 교체)이 같은 프레임에 겹쳐
                      // InheritedWidget deactivate assertion이 터지는 것을 방지.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        authBloc.add(AuthDeleteAccountRequested());
                      });
                    }
                  : null,
              child: const Text('탈퇴',
                  style: TextStyle(color: AppTheme.errorColor)),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }
}
