import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SettingsBottomSheet extends StatelessWidget {
  const SettingsBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<AuthBloc>(),
        child: const SettingsBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 바
          Container(
            margin: EdgeInsets.only(top: 10.h, bottom: 4.h),
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8.h),
                  // 그룹 1 - 반려동물 관리
                  _buildGroup(context, items: [
                    _SettingsItem(
                      icon: Icons.pets_outlined,
                      label: '내 반려동물 관리',
                      bgColor: const Color(0xFFE6F1FB),
                      onTap: () { Navigator.pop(context); context.push('/pets'); },
                    ),
                    _SettingsItem(
                      icon: Icons.bar_chart_outlined,
                      label: '감정 히스토리',
                      bgColor: const Color(0xFFEAF3DE),
                      onTap: () { Navigator.pop(context); context.push('/emotion/calendar'); },
                    ),
                    _SettingsItem(
                      icon: Icons.card_giftcard_outlined,
                      label: '리워드 스토어',
                      bgColor: const Color(0xFFFAECE7),
                      onTap: () { Navigator.pop(context); context.push('/reward'); },
                    ),
                  ]),
                  _buildDivider(),
                  // 그룹 2 - 계정 설정
                  _buildGroup(context, items: [
                    _SettingsItem(
                      icon: Icons.edit_outlined,
                      label: '프로필 편집',
                      bgColor: const Color(0xFFF1EFE8),
                      onTap: () { Navigator.pop(context); context.push('/my/edit-profile'); },
                    ),
                    _SettingsItem(
                      icon: Icons.notifications_none_outlined,
                      label: '알림 설정',
                      bgColor: const Color(0xFFFBEAF0),
                      onTap: () { Navigator.pop(context); context.push('/my/notification-settings'); },
                    ),
                    _SettingsItem(
                      icon: Icons.lock_outline,
                      label: '개인정보처리방침',
                      bgColor: const Color(0xFFF1EFE8),
                      onTap: () { Navigator.pop(context); context.push('/privacy'); },
                    ),
                    _SettingsItem(
                      icon: Icons.info_outline,
                      label: '앱 정보 · 버전',
                      bgColor: const Color(0xFFF1EFE8),
                      onTap: () {
                        Navigator.pop(context);
                        showAboutDialog(
                          context: context,
                          applicationName: 'PetSpace',
                          applicationVersion: '1.0.0',
                        );
                      },
                    ),
                  ]),
                  _buildDivider(),
                  // 그룹 3 - 위험 구역
                  _buildGroup(context, items: [
                    _SettingsItem(
                      icon: Icons.logout,
                      label: '로그아웃',
                      bgColor: const Color(0xFFFCEBEB),
                      textColor: AppTheme.errorColor,
                      showChevron: false,
                      onTap: () => _confirmLogout(context),
                    ),
                    _SettingsItem(
                      icon: Icons.warning_amber,
                      label: '회원탈퇴',
                      bgColor: const Color(0xFFFCEBEB),
                      textColor: AppTheme.errorColor,
                      showChevron: false,
                      onTap: () => _confirmDelete(context),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, {required List<_SettingsItem> items}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
      child: Column(
        children: items.map((item) => _buildTile(context, item)).toList(),
      ),
    );
  }

  Widget _buildTile(BuildContext context, _SettingsItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 0, vertical: 13.h),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: item.bgColor,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(item.icon, size: 18.w,
                  color: item.textColor ?? AppTheme.primaryTextColor),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: item.textColor ?? AppTheme.primaryTextColor,
                ),
              ),
            ),
            if (item.showChevron)
              Icon(Icons.chevron_right, size: 20.w, color: const Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
      color: const Color(0xFFF0F0F0),
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
              Navigator.pop(context);
              context.read<AuthBloc>().add(AuthSignOutRequested());
            },
            child: const Text('로그아웃', style: TextStyle(color: AppTheme.errorColor)),
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
            child: const Text('탈퇴', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color? textColor;
  final bool showChevron;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.bgColor,
    this.textColor,
    this.showChevron = true,
    required this.onTap,
  });
}
