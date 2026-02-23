import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
            leading: Icon(Icons.pets, size: 24.w),
            title: Text('반려동물 관리', style: TextStyle(fontSize: 14.sp)),
            trailing: Icon(Icons.chevron_right, size: 20.w),
            onTap: () {
              context.push('/pets');
            },
          ),
          const Divider(),
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
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip, size: 24.w),
            title: Text('개인정보 보호', style: TextStyle(fontSize: 14.sp)),
            trailing: Icon(Icons.chevron_right, size: 20.w),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.help, size: 24.w),
            title: Text('도움말', style: TextStyle(fontSize: 14.sp)),
            trailing: Icon(Icons.chevron_right, size: 20.w),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red, size: 24.w),
            title: Text('로그아웃', style: TextStyle(color: Colors.red, fontSize: 14.sp)),
            onTap: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('로그아웃', style: TextStyle(fontSize: 18.sp)),
                  content: Text('정말 로그아웃 하시겠습니까?', style: TextStyle(fontSize: 14.sp)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('취소', style: TextStyle(fontSize: 14.sp)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('로그아웃', style: TextStyle(color: Colors.red, fontSize: 14.sp)),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true && context.mounted) {
                context.read<AuthBloc>().add(AuthSignOutRequested());
                // 로그아웃 후 온보딩 로그인 페이지로 이동
                context.go('/onboarding/login');
              }
            },
          ),
        ],
      ),
    );
  }
}