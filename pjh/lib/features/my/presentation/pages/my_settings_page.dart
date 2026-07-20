import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/app_package_info.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../../../shared/widgets/petspace_settings_components.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

typedef AppPackageInfoLoader = Future<AppPackageInfo> Function();

enum _AccountAction { logout, delete }

class MySettingsPage extends StatefulWidget {
  final AppPackageInfoLoader packageInfoLoader;

  const MySettingsPage({
    super.key,
    this.packageInfoLoader = AppPackageInfo.load,
  });

  @override
  State<MySettingsPage> createState() => _MySettingsPageState();
}

class _MySettingsPageState extends State<MySettingsPage> {
  late final Future<AppPackageInfo> _packageInfo;
  _AccountAction? _pendingAction;

  @override
  void initState() {
    super.initState();
    _packageInfo = widget.packageInfoLoader();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError && _pendingAction != null) {
          final failedAction = _pendingAction!;
          setState(() => _pendingAction = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              key: const Key('account_action_error'),
              content: Text(
                failedAction == _AccountAction.logout
                    ? '로그아웃하지 못했어요. 잠시 후 다시 시도해주세요.'
                    : '회원탈퇴를 처리하지 못했어요. 잠시 후 다시 시도해주세요.',
              ),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      },
      child: PopScope(
        canPop: _pendingAction == null,
        child: Stack(
          children: [
            PetSpacePageScaffold(
              title: '설정',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: _pendingAction == null ? () => context.pop() : null,
              ),
              body: _buildSettingsBody(),
            ),
            if (_pendingAction != null) _buildProgressOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsBody() {
    return SingleChildScrollView(
      key: const Key('my_settings_content'),
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
            ],
          ),
          SizedBox(height: 24.h),
          PetSpaceSettingsSection(
            title: '계정',
            children: [
              PetSpaceSettingsTile(
                icon: Icons.person_outline,
                title: '계정 정보',
                onTap: _showAccountInfo,
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
                onTap: _showAppInfo,
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
                onTap: _confirmLogout,
              ),
              PetSpaceSettingsTile(
                icon: Icons.warning_amber,
                title: '회원탈퇴',
                destructive: true,
                onTap: _confirmDelete,
              ),
            ],
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _buildProgressOverlay() {
    final isLogout = _pendingAction == _AccountAction.logout;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.28),
        child: AbsorbPointer(
          child: Center(
            child: Container(
              key: const Key('account_action_progress'),
              width: 240.w,
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  SizedBox(height: 16.h),
                  Text(
                    isLogout ? '로그아웃하고 있어요' : '회원탈퇴를 처리하고 있어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTheme.fontBody.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '잠시만 기다려주세요.',
                    style: TextStyle(
                      fontSize: AppTheme.fontCaption.sp,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAccountInfo() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final user = authState.user;
    final theme = Theme.of(context);
    final labelIconColor = theme.brightness == Brightness.dark
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
                  Text(
                    label,
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                  ),
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

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('계정 정보', style: TextStyle(fontSize: 17.sp)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row(Icons.person, '닉네임', user.displayName),
            row(Icons.email, '이메일', user.email),
            row(
              Icons.calendar_today,
              '가입일',
              '${user.createdAt.year}년 ${user.createdAt.month}월 ${user.createdAt.day}일',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAppInfo() async {
    AppPackageInfo? info;
    try {
      info = await _packageInfo;
    } catch (_) {
      // 플랫폼 메타데이터를 읽지 못해도 설정 화면 자체는 계속 사용할 수 있다.
    }
    if (!mounted) return;
    showAboutDialog(
      context: context,
      applicationName: 'PetSpace',
      applicationVersion: info?.displayVersion ?? '확인할 수 없음',
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('logout_confirm_dialog'),
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            key: const Key('logout_confirm_button'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '로그아웃',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _pendingAction = _AccountAction.logout);
    context.read<AuthBloc>().add(AuthSignOutRequested());
  }

  Future<void> _confirmDelete() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          key: const Key('delete_account_confirm_dialog'),
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
                key: const Key('delete_account_phrase'),
                controller: controller,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  hintText: "계속하려면 '탈퇴'를 입력하세요",
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            TextButton(
              key: const Key('delete_account_confirm_button'),
              onPressed: controller.text.trim() == '탈퇴'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text(
                '탈퇴',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ),
          ],
        ),
      ),
    );
    // 다이얼로그의 퇴장 애니메이션과 TextField 해체가 끝난 다음 폐기한다.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (confirmed != true || !mounted) return;
    setState(() => _pendingAction = _AccountAction.delete);
    context.read<AuthBloc>().add(AuthDeleteAccountRequested());
  }
}
