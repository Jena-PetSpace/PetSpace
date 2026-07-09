import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/services/permission_helper.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../social/domain/repositories/social_repository.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with WidgetsBindingObserver {
  bool _pushEnabled = true;
  bool _likeNotification = true;
  bool _commentNotification = true;
  bool _followNotification = true;
  bool _chatNotification = true;
  bool _mentionNotification = true;
  bool _systemNotification = true;

  bool _loading = true;
  bool _systemPermissionGranted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _checkSystemPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 앱이 백그라운드 → 포그라운드로 돌아올 때 시스템 권한을 다시 확인.
  /// 사용자가 설정 앱에서 권한을 토글하고 돌아왔을 가능성이 있음.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkSystemPermission();
    }
  }

  Future<void> _checkSystemPermission() async {
    final granted = await PermissionHelper.isNotificationGranted();
    if (!mounted) return;
    setState(() => _systemPermissionGranted = granted);
  }

  /// 서버 우선 로드 — 서버 실패 시 SharedPreferences fallback
  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();

    // 1. SharedPreferences 값을 먼저 읽어 캐시로 표시 (체감 속도)
    bool cachedPush = prefs.getBool('notification_push_enabled') ?? true;
    bool cachedLike = prefs.getBool('notification_like') ?? true;
    bool cachedComment = prefs.getBool('notification_comment') ?? true;
    bool cachedFollow = prefs.getBool('notification_follow') ?? true;
    bool cachedChat = prefs.getBool('notification_chat') ?? true;
    bool cachedMention = prefs.getBool('notification_mention') ?? true;
    bool cachedSystem = prefs.getBool('notification_system') ?? true;

    if (mounted) {
      setState(() {
        _pushEnabled = cachedPush;
        _likeNotification = cachedLike;
        _commentNotification = cachedComment;
        _followNotification = cachedFollow;
        _chatNotification = cachedChat;
        _mentionNotification = cachedMention;
        _systemNotification = cachedSystem;
      });
    }

    // 2. 서버 값으로 덮어쓰기 (단일 소스 원칙)
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final result = await sl<SocialRepository>().getNotificationPreferences(userId);
    await result.fold(
      (failure) async {
        dev.log('서버 알림 설정 로드 실패(로컬 값 유지): ${failure.message}',
            name: 'NotificationSettings');
      },
      (row) async {
        if (row == null || !mounted) return;
        setState(() {
          _pushEnabled = row['enabled_push'] as bool? ?? true;
          _likeNotification = row['enabled_like'] as bool? ?? true;
          _commentNotification = row['enabled_comment'] as bool? ?? true;
          _followNotification = row['enabled_follow'] as bool? ?? true;
          _mentionNotification = row['enabled_mention'] as bool? ?? true;
          _systemNotification = row['enabled_system'] as bool? ?? true;
          // chat은 서버 컬럼 없음 — 로컬 유지
        });
        // 서버 값 → SharedPreferences 캐시 갱신
        await prefs.setBool('notification_push_enabled', _pushEnabled);
        await prefs.setBool('notification_like', _likeNotification);
        await prefs.setBool('notification_comment', _commentNotification);
        await prefs.setBool('notification_follow', _followNotification);
        await prefs.setBool('notification_mention', _mentionNotification);
        await prefs.setBool('notification_system', _systemNotification);
      },
    );
    if (mounted) setState(() => _loading = false);
  }

  /// 로컬 저장 + 서버 upsert (optimistic)
  Future<void> _saveSetting(String localKey, String? serverColumn, bool value,
      {VoidCallback? onRollback}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(localKey, value);

    if (serverColumn == null) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final result = await sl<SocialRepository>().upsertNotificationPreference(
      userId: userId,
      column: serverColumn,
      value: value,
    );
    result.fold(
      (failure) {
        dev.log('서버 알림 설정 저장 실패: ${failure.message}',
            name: 'NotificationSettings');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('설정 동기화에 실패했습니다. 네트워크를 확인해주세요.'),
            ),
          );
          onRollback?.call();
        }
      },
      (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림 설정'),
        actions: [
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: SizedBox(
                width: 18.w,
                height: 18.w,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        children: [
          if (!_systemPermissionGranted) _SystemPermissionWarning(
            onTap: () async {
              await PermissionHelper.showSettingsBottomSheet(
                context,
                permissionName: '알림',
                reason: '푸시 알림을 받으려면 시스템 알림 권한이 필요합니다.',
              );
              await _checkSystemPermission();
            },
          ),
          SwitchListTile(
            title: Text('푸시 알림', style: TextStyle(fontSize: 14.sp)),
            subtitle:
                Text('전체 푸시 알림을 켜거나 끕니다', style: TextStyle(fontSize: 12.sp)),
            value: _pushEnabled,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: (value) {
              setState(() => _pushEnabled = value);
              _saveSetting('notification_push_enabled', 'enabled_push', value,
                  onRollback: () => setState(() => _pushEnabled = !value));
            },
          ),
          const Divider(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Text(
              '알림 유형',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          SwitchListTile(
            title: Text('좋아요', style: TextStyle(fontSize: 14.sp)),
            subtitle:
                Text('내 게시물에 좋아요가 달리면 알림', style: TextStyle(fontSize: 12.sp)),
            value: _likeNotification && _pushEnabled,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: _pushEnabled
                ? (value) {
                    setState(() => _likeNotification = value);
                    _saveSetting('notification_like', 'enabled_like', value,
                        onRollback: () =>
                            setState(() => _likeNotification = !value));
                  }
                : null,
          ),
          SwitchListTile(
            title: Text('댓글', style: TextStyle(fontSize: 14.sp)),
            subtitle:
                Text('내 게시물에 댓글이 달리면 알림', style: TextStyle(fontSize: 12.sp)),
            value: _commentNotification && _pushEnabled,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: _pushEnabled
                ? (value) {
                    setState(() => _commentNotification = value);
                    _saveSetting(
                        'notification_comment', 'enabled_comment', value,
                        onRollback: () =>
                            setState(() => _commentNotification = !value));
                  }
                : null,
          ),
          SwitchListTile(
            title: Text('팔로우', style: TextStyle(fontSize: 14.sp)),
            subtitle:
                Text('누군가 나를 팔로우하면 알림', style: TextStyle(fontSize: 12.sp)),
            value: _followNotification && _pushEnabled,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: _pushEnabled
                ? (value) {
                    setState(() => _followNotification = value);
                    _saveSetting('notification_follow', 'enabled_follow', value,
                        onRollback: () =>
                            setState(() => _followNotification = !value));
                  }
                : null,
          ),
          SwitchListTile(
            title: Text('멘션', style: TextStyle(fontSize: 14.sp)),
            subtitle:
                Text('누군가 나를 언급하면 알림', style: TextStyle(fontSize: 12.sp)),
            value: _mentionNotification && _pushEnabled,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: _pushEnabled
                ? (value) {
                    setState(() => _mentionNotification = value);
                    _saveSetting(
                        'notification_mention', 'enabled_mention', value,
                        onRollback: () =>
                            setState(() => _mentionNotification = !value));
                  }
                : null,
          ),
          SwitchListTile(
            title: Text('채팅', style: TextStyle(fontSize: 14.sp)),
            subtitle:
                Text('새 채팅 메시지가 오면 알림', style: TextStyle(fontSize: 12.sp)),
            value: _chatNotification && _pushEnabled,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: _pushEnabled
                ? (value) {
                    setState(() => _chatNotification = value);
                    _saveSetting('notification_chat', null, value);
                  }
                : null,
          ),
          SwitchListTile(
            title: Text('시스템', style: TextStyle(fontSize: 14.sp)),
            subtitle:
                Text('공지사항 및 시스템 안내', style: TextStyle(fontSize: 12.sp)),
            value: _systemNotification && _pushEnabled,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: _pushEnabled
                ? (value) {
                    setState(() => _systemNotification = value);
                    _saveSetting('notification_system', 'enabled_system', value,
                        onRollback: () =>
                            setState(() => _systemNotification = !value));
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _SystemPermissionWarning extends StatelessWidget {
  const _SystemPermissionWarning({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWarm, // v2-review: FFF4E5 근사
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.warningColor, width: 1), // v2-review: FFB266 근사
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 22.sp, color: AppTheme.warningColor), // v2-review: D97706 근사
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '시스템 알림이 꺼져 있어요',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textBody, // v2-review: 7A4500 근사
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '아래 알림을 모두 켜더라도 시스템 권한이 꺼져 있으면 알림이 오지 않습니다.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textBody, // v2-review: 7A4500 근사
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 8.h),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    '설정에서 켜기 →',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.warningColor, // v2-review: D97706 근사
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
