import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../../../shared/widgets/petspace_settings_components.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class MySettingsPage extends StatelessWidget {
  const MySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PetSpacePageScaffold(
      title: '설정',
      leading: IconButton(
        // 색상은 공용 스캐폴드의 AppBar iconTheme(라이트=primaryTextColor,
        // 다크=onSurface)을 그대로 상속한다.
        icon: const Icon(Icons.arrow_back),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => context.pop(),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PetSpaceSettingsSection(
              title: '내 활동',
              children: [
                PetSpaceSettingsTile(
                  icon: Icons.pets_outlined,
                  title: '내 반려동물 관리',
                  onTap: () => context.push('/pets'),
                ),
                PetSpaceSettingsTile(
                  icon: Icons.bar_chart_outlined,
                  title: 'AI 분석 히스토리',
                  onTap: () => context.push('/ai-history-page'),
                ),
                // TODO(reward): 리워드/포인트 시스템 미완성 → 진입 숨김.
                // 리워드 트랙 복원 시 아래 타일 주석 해제로 되살리기.
                // PetSpaceSettingsTile(
                //   icon: Icons.card_giftcard_outlined,
                //   title: '리워드 스토어',
                //   onTap: () => context.push('/reward'),
                // ),
              ],
            ),
            SizedBox(height: 24.h),
            PetSpaceSettingsSection(
              title: '계정',
              children: [
                PetSpaceSettingsTile(
                  icon: Icons.person_outline,
                  title: '계정 정보',
                  onTap: () => _showAccountInfo(context),
                ),
                PetSpaceSettingsTile(
                  icon: Icons.edit_outlined,
                  title: '프로필 편집',
                  onTap: () => context.push('/my/edit-profile'),
                ),
                PetSpaceSettingsTile(
                  icon: Icons.notifications_none_outlined,
                  title: '알림 설정',
                  onTap: () => context.push('/settings/notification'),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            PetSpaceSettingsSection(
              title: '정보',
              children: [
                PetSpaceSettingsTile(
                  icon: Icons.lock_outline,
                  title: '개인정보처리방침',
                  onTap: () => context.push('/privacy'),
                ),
                PetSpaceSettingsTile(
                  icon: Icons.shield_outlined,
                  title: '커뮤니티 가이드라인',
                  onTap: () => context.push('/community-guidelines'),
                ),
                PetSpaceSettingsTile(
                  icon: Icons.help_outline,
                  title: '도움말',
                  onTap: () => context.push('/settings/help'),
                ),
                PetSpaceSettingsTile(
                  icon: Icons.info_outline,
                  title: '앱 정보 · 버전',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'PetSpace',
                    applicationVersion: '1.0.0',
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            PetSpaceSettingsSection(
              title: '계정 관리',
              children: [
                PetSpaceSettingsTile(
                  icon: Icons.logout,
                  title: '로그아웃',
                  destructive: true,
                  onTap: () => _confirmLogout(context),
                ),
                PetSpaceSettingsTile(
                  icon: Icons.warning_amber,
                  title: '회원탈퇴',
                  destructive: true,
                  onTap: () => _confirmDelete(context),
                ),
              ],
            ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  void _showAccountInfo(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final user = authState.user;

    // 다크모드는 Theme의 보조 text를 우선하고 라이트모드 시각값은 유지한다.
    final ThemeData theme = Theme.of(context);
    final Color labelIconColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurfaceVariant
        : AppTheme.secondaryTextColor;

    Widget row(IconData icon, String label, String value) => Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18.w, color: labelIconColor),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
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
