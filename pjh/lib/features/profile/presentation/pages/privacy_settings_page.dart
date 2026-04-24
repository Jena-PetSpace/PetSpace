import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';

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
      final response = await Supabase.instance.client
          .from('user_blocks')
          .select('blocked_id, users!user_blocks_blocked_id_fkey(display_name, avatar_url)')
          .eq('blocker_id', userId)
          .limit(100);

      final list = (response as List).map((row) {
        final userMap = row['users'] as Map<String, dynamic>?;
        return _BlockedUser(
          id: row['blocked_id'] as String,
          displayName: userMap?['display_name'] as String? ?? '사용자',
          avatarUrl: userMap?['avatar_url'] as String?,
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
      await Supabase.instance.client
          .from('user_blocks')
          .delete()
          .eq('blocker_id', userId)
          .eq('blocked_id', user.id);
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('개인정보 보호'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: ListView(
        children: [
          // ── 프라이버시 설정 ──────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
            child: Text(
              '프라이버시',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ),
          Container(
            color: Colors.white,
            child: Column(children: [
              SwitchListTile(
                title: Text('비공개 계정', style: TextStyle(fontSize: 14.sp)),
                subtitle: Text('승인된 팔로워만 내 게시물을 볼 수 있습니다',
                    style: TextStyle(fontSize: 12.sp)),
                value: _isPrivateAccount,
                activeThumbColor: AppTheme.primaryColor,
                onChanged: (value) {
                  setState(() => _isPrivateAccount = value);
                  _saveSetting('privacy_private_account', value);
                },
              ),
              SwitchListTile(
                title: Text('온라인 상태 표시', style: TextStyle(fontSize: 14.sp)),
                subtitle: Text('다른 사용자에게 온라인 상태를 보여줍니다',
                    style: TextStyle(fontSize: 12.sp)),
                value: _showOnlineStatus,
                activeThumbColor: AppTheme.primaryColor,
                onChanged: (value) {
                  setState(() => _showOnlineStatus = value);
                  _saveSetting('privacy_show_online', value);
                },
              ),
              SwitchListTile(
                title: Text('이메일로 검색 허용', style: TextStyle(fontSize: 14.sp)),
                subtitle: Text('다른 사용자가 이메일로 나를 찾을 수 있습니다',
                    style: TextStyle(fontSize: 12.sp)),
                value: _allowSearchByEmail,
                activeThumbColor: AppTheme.primaryColor,
                onChanged: (value) {
                  setState(() => _allowSearchByEmail = value);
                  _saveSetting('privacy_search_by_email', value);
                },
              ),
            ]),
          ),

          // ── 차단 목록 ──────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 8.h),
            child: Text(
              '차단한 사용자',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ),
          Container(
            color: Colors.white,
            child: _blockedLoading
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: const Center(child: CircularProgressIndicator()),
                  )
                : _blockedUsers.isEmpty
                    ? Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Center(
                          child: Text(
                            '차단한 사용자가 없습니다',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: _blockedUsers
                            .map((u) => ListTile(
                                  leading: CircleAvatar(
                                    radius: 18.w,
                                    backgroundImage: u.avatarUrl != null
                                        ? NetworkImage(u.avatarUrl!)
                                        : null,
                                    child: u.avatarUrl == null
                                        ? Text(
                                            u.displayName.isNotEmpty
                                                ? u.displayName[0]
                                                : '?',
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    u.displayName,
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  trailing: TextButton(
                                    onPressed: () => _unblockUser(u),
                                    child: Text(
                                      '차단 해제',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
          ),
          SizedBox(height: 32.h),
        ],
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
