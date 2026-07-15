import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../../../shared/widgets/petspace_settings_components.dart';
import '../../../../shared/widgets/petspace_state_view.dart';
import '../../../social/domain/repositories/social_repository.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _isPrivateAccount = false;
  bool _showOnlineStatus = true;
  bool _allowSearchByEmail = true;

  List<_BlockedUser> _blockedUsers = [];
  bool _blockedLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadBlockedUsers();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPrivateAccount = prefs.getBool('privacy_private_account') ?? false;
      _showOnlineStatus = prefs.getBool('privacy_show_online') ?? true;
      _allowSearchByEmail = prefs.getBool('privacy_search_by_email') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  /// 차단된 사용자 목록을 Supabase에서 로드.
  /// 테이블 부재/권한 오류 시 빈 리스트로 fallback.
  Future<void> _loadBlockedUsers() async {
    setState(() => _blockedLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _blockedUsers = [];
          _blockedLoading = false;
        });
        return;
      }
      final result =
          await sl<SocialRepository>().getBlockedUsersDetailed(userId);
      final rows = result.fold((_) => <Map<String, dynamic>>[], (r) => r);
      final list = rows.map((row) {
        final userMap = row['users'] as Map<String, dynamic>?;
        return _BlockedUser(
          id: row['blocked_id'] as String,
          displayName: userMap?['display_name'] as String? ?? '사용자',
          avatarUrl: userMap?['photo_url'] as String?,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _blockedUsers = list;
          _blockedLoading = false;
        });
      }
    } catch (e) {
      dev.log('차단 목록 로드 실패(테이블 부재 가능): $e', name: 'PrivacySettings');
      if (mounted) {
        setState(() {
          _blockedUsers = [];
          _blockedLoading = false;
        });
      }
    }
  }

  Future<void> _unblockUser(_BlockedUser user) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final result = await sl<SocialRepository>().unblockUser(userId, user.id);
      result.fold((f) => throw Exception(f.message), (_) {});
      if (mounted) {
        setState(() => _blockedUsers.removeWhere((u) => u.id == user.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.displayName}님 차단 해제')),
        );
      }
    } catch (e) {
      dev.log('차단 해제 실패: $e', name: 'PrivacySettings');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('차단 해제 실패. 잠시 후 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PetSpacePageScaffold(
      title: '개인정보 보호',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/settings'),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        children: [
          PetSpaceSettingsSection(
            title: '프라이버시',
            children: [
              _buildSwitchTile(
                title: '비공개 계정',
                subtitle: '승인된 팔로워만 내 게시물을 볼 수 있습니다',
                value: _isPrivateAccount,
                onChanged: (value) {
                  setState(() => _isPrivateAccount = value);
                  _saveSetting('privacy_private_account', value);
                },
              ),
              _buildSwitchTile(
                title: '온라인 상태 표시',
                subtitle: '다른 사용자에게 온라인 상태를 보여줍니다',
                value: _showOnlineStatus,
                onChanged: (value) {
                  setState(() => _showOnlineStatus = value);
                  _saveSetting('privacy_show_online', value);
                },
              ),
              _buildSwitchTile(
                title: '이메일로 검색 허용',
                subtitle: '다른 사용자가 이메일로 나를 찾을 수 있습니다',
                value: _allowSearchByEmail,
                onChanged: (value) {
                  setState(() => _allowSearchByEmail = value);
                  _saveSetting('privacy_search_by_email', value);
                },
              ),
            ],
          ),
          SizedBox(height: 24.h),
          PetSpaceSettingsSection(
            title: '차단한 사용자',
            children: [
              if (_blockedLoading)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: const PetSpaceStateView.loading(),
                )
              else if (_blockedUsers.isEmpty)
                const PetSpaceStateView.empty(
                  message: '차단한 사용자가 없습니다',
                )
              else
                ..._blockedUsers.map((u) => _buildBlockedUserTile(u)),
            ],
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    // 다크모드는 Theme의 text를 우선하고 라이트모드 시각값은 유지한다.
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color bodyColor =
        isDark ? theme.colorScheme.onSurface : AppTheme.primaryTextColor;
    final Color mutedColor =
        isDark ? theme.colorScheme.onSurfaceVariant : AppTheme.textMuted;
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: AppTheme.fontBody.sp,
          fontWeight: FontWeight.w500,
          color: bodyColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: AppTheme.fontCaption.sp,
          color: mutedColor,
        ),
      ),
      value: value,
      activeThumbColor: AppTheme.actionBase,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 2.h),
      onChanged: onChanged,
    );
  }

  Widget _buildBlockedUserTile(_BlockedUser u) {
    // 다크모드는 Theme의 text를 우선하고 라이트모드 시각값은 유지한다.
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color bodyColor =
        isDark ? theme.colorScheme.onSurface : AppTheme.primaryTextColor;
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 2.h),
      leading: CircleAvatar(
        radius: 18.w,
        backgroundColor: AppTheme.actionContainer,
        backgroundImage:
            u.avatarUrl != null ? NetworkImage(u.avatarUrl!) : null,
        child: u.avatarUrl == null
            ? Text(
                u.displayName.isNotEmpty ? u.displayName[0] : '?',
                style: TextStyle(
                  fontSize: AppTheme.fontBody.sp,
                  color: AppTheme.actionBase,
                ),
              )
            : null,
      ),
      title: Text(
        u.displayName,
        style: TextStyle(
          fontSize: AppTheme.fontBody.sp,
          color: bodyColor,
        ),
      ),
      trailing: TextButton(
        onPressed: () => _unblockUser(u),
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
        ),
        child: Text(
          '차단 해제',
          style: TextStyle(
            color: AppTheme.actionBase,
            fontSize: AppTheme.fontCaption.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BlockedUser {
  final String id;
  final String displayName;
  final String? avatarUrl;
  const _BlockedUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });
}
