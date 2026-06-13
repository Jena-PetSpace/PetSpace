import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_config.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _showDeleteAccountDialog(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('회원탈퇴',
              style: TextStyle(fontSize: 18.sp, color: Colors.red[700])),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '탈퇴 후 30일이 지나면 모든 데이터가 영구 삭제됩니다.\n'
                '그 전까지는 다시 로그인하면 계정을 복구할 수 있어요.',
                style: TextStyle(fontSize: 14.sp),
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
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('취소', style: TextStyle(fontSize: 14.sp)),
            ),
            TextButton(
              // 네비게이션은 GoRouter refreshListenable+redirect가 처리한다.
              // 여기서 수동 context.go 를 호출하면 이중 네비게이션이 다이얼로그
              // 해체와 겹쳐 _dependents.isEmpty assertion이 발생하므로 제거.
              onPressed: controller.text.trim() == '탈퇴'
                  ? () {
                      Navigator.of(dialogContext).pop();
                      // 다이얼로그가 완전히 해체된 다음 프레임에 이벤트 발행
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        authBloc.add(AuthDeleteAccountRequested());
                      });
                    }
                  : null,
              child: Text('탈퇴',
                  style: TextStyle(color: Colors.red, fontSize: 14.sp)),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }

  void _showAccountInfo(BuildContext context) {
    final authState = context.read<AuthBloc>().state;

    if (authState is! AuthAuthenticated) {
      return;
    }

    final user = authState.user;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('계정 정보', style: TextStyle(fontSize: 18.sp)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, size: 20.w, color: Colors.grey),
                SizedBox(width: 8.w),
                Text(
                  '닉네임',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Padding(
              padding: EdgeInsets.only(left: 28.w),
              child: Text(
                user.displayName,
                style: TextStyle(fontSize: 16.sp),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Icon(Icons.email, size: 20.w, color: Colors.grey),
                SizedBox(width: 8.w),
                Text(
                  '이메일',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Padding(
              padding: EdgeInsets.only(left: 28.w),
              child: Text(
                user.email,
                style: TextStyle(fontSize: 16.sp),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 20.w, color: Colors.grey),
                SizedBox(width: 8.w),
                Text(
                  '가입일',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Padding(
              padding: EdgeInsets.only(left: 28.w),
              child: Text(
                '${user.createdAt.year}년 ${user.createdAt.month}월 ${user.createdAt.day}일',
                style: TextStyle(fontSize: 16.sp),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('확인', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.person, size: 24.w),
            title: Text('계정 정보', style: TextStyle(fontSize: 14.sp)),
            trailing: Icon(Icons.chevron_right, size: 20.w),
            onTap: () => _showAccountInfo(context),
          ),
          ListTile(
            leading: Icon(Icons.notifications, size: 24.w),
            title: Text('알림 설정', style: TextStyle(fontSize: 14.sp)),
            trailing: Icon(Icons.chevron_right, size: 20.w),
            onTap: () => context.push('/settings/notification'),
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip, size: 24.w),
            title: Text('개인정보처리방침', style: TextStyle(fontSize: 14.sp)),
            trailing: Icon(Icons.chevron_right, size: 20.w),
            onTap: () => context.push('/privacy'),
          ),
          ListTile(
            leading: Icon(Icons.shield_outlined, size: 24.w),
            title: Text('커뮤니티 가이드라인', style: TextStyle(fontSize: 14.sp)),
            trailing: Icon(Icons.chevron_right, size: 20.w),
            onTap: () => context.push('/community-guidelines'),
          ),
          ListTile(
            leading: Icon(Icons.help, size: 24.w),
            title: Text('도움말', style: TextStyle(fontSize: 14.sp)),
            trailing: Icon(Icons.chevron_right, size: 20.w),
            onTap: () => context.push('/settings/help'),
          ),
          ListTile(
            leading: Icon(Icons.info_outline, size: 24.w),
            title: Text('앱 정보', style: TextStyle(fontSize: 14.sp)),
            trailing: Icon(Icons.chevron_right, size: 20.w),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: '펫페이스',
                applicationVersion: AppConfig.appVersion,
                applicationLegalese: '© 2026 PetSpace',
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red, size: 24.w),
            title: Text('로그아웃',
                style: TextStyle(color: Colors.red, fontSize: 14.sp)),
            onTap: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('로그아웃', style: TextStyle(fontSize: 18.sp)),
                  content: Text('정말 로그아웃 하시겠습니까?',
                      style: TextStyle(fontSize: 14.sp)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('취소', style: TextStyle(fontSize: 14.sp)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('로그아웃',
                          style: TextStyle(color: Colors.red, fontSize: 14.sp)),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true && context.mounted) {
                // 네비게이션은 GoRouter refreshListenable+redirect가 처리한다
                // (수동 context.go 제거 — 이중 네비게이션 방지)
                context.read<AuthBloc>().add(AuthSignOutRequested());
              }
            },
          ),
          ListTile(
            leading:
                Icon(Icons.delete_forever, color: Colors.red[700], size: 24.w),
            title: Text('계정 삭제',
                style: TextStyle(color: Colors.red[700], fontSize: 14.sp)),
            subtitle: Text('모든 데이터가 영구적으로 삭제됩니다',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
            onTap: () => _showDeleteAccountDialog(context),
          ),
        ],
      ),
    );
  }
}
