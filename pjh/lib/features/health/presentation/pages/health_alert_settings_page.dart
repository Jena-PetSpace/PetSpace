import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../shared/themes/app_theme.dart';

class HealthAlertSettingsPage extends StatefulWidget {
  const HealthAlertSettingsPage({super.key});

  @override
  State<HealthAlertSettingsPage> createState() => _HealthAlertSettingsPageState();
}

class _HealthAlertSettingsPageState extends State<HealthAlertSettingsPage> {
  bool _alertEnabled = true;
  bool _alertD7 = true, _alertD3 = true, _alertD1 = true;
  String _alertTime = '09:00';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _alertEnabled = prefs.getBool('health_alert_enabled') ?? true;
        _alertD7 = prefs.getBool('health_alert_d7') ?? true;
        _alertD3 = prefs.getBool('health_alert_d3') ?? true;
        _alertD1 = prefs.getBool('health_alert_d1') ?? true;
        _alertTime = prefs.getString('health_alert_time') ?? '09:00';
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('health_alert_enabled', _alertEnabled);
    await prefs.setBool('health_alert_d7', _alertD7);
    await prefs.setBool('health_alert_d3', _alertD3);
    await prefs.setBool('health_alert_d1', _alertD1);
    await prefs.setString('health_alert_time', _alertTime);

    // 알림 비활성화 시 예약된 건강 알림 모두 취소
    // 활성화 시에는 HealthBloc이 기록 추가/수정 시점에 재스케줄링 (LocalNotificationService.scheduleHealthAlert)
    if (!_alertEnabled) {
      try {
        // NOTE: 현재는 건강 전용 cancelByChannel API가 없어서 전체 취소 대신
        // SharedPreferences 플래그만 읽어서 HealthBloc이 스케줄을 안 하도록 유도
        // 향후 개별 취소: sl<LocalNotificationService>().cancelNotification(recordId.hashCode)
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림 설정이 저장되었습니다'), backgroundColor: AppTheme.primaryColor),
      );
    }
  }

  /// 알림 동작 확인용 — 5초 뒤 테스트 알림
  Future<void> _sendTestNotification() async {
    try {
      final notif = sl<LocalNotificationService>();
      await notif.scheduleHealthAlert(
        id: 999999,
        title: '알림 테스트',
        body: '건강 알림이 정상적으로 동작합니다.',
        scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('5초 뒤 테스트 알림이 도착합니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('테스트 알림 예약 실패. 알림 권한을 확인해주세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('건강 알림 설정', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
        centerTitle: true, backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryTextColor, elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: '알림 테스트',
            onPressed: _sendTestNotification,
          ),
          TextButton(
            onPressed: _saveSettings,
            child: Text('저장', style: TextStyle(color: AppTheme.primaryColor, fontSize: 14.sp, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 알림 온/오프
          _buildSection(
            title: '건강 기록 알림',
            children: [
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                title: '예정일 알림 받기',
                subtitle: '건강 기록 예정일이 다가오면 알려드려요',
                value: _alertEnabled,
                onChanged: (v) => setState(() => _alertEnabled = v),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // D-day 옵션
          AnimatedOpacity(
            opacity: _alertEnabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildSection(
                title: '알림 시점',
                children: [
                  _buildCheckTile('D-7', '7일 전에 알림', _alertD7, (v) => setState(() => _alertD7 = v)),
                  _buildCheckTile('D-3', '3일 전에 알림', _alertD3, (v) => setState(() => _alertD3 = v)),
                  _buildCheckTile('D-1', '하루 전에 알림', _alertD1, (v) => setState(() => _alertD1 = v)),
                ],
              ),
              SizedBox(height: 16.h),

              _buildSection(
                title: '알림 시간',
                children: [
                  ListTile(
                    leading: Icon(Icons.access_time, size: 22.w, color: AppTheme.primaryColor),
                    title: Text('알림 받을 시간', style: TextStyle(fontSize: 14.sp)),
                    trailing: GestureDetector(
                      onTap: () async {
                        if (!_alertEnabled) return;
                        final parts = _alertTime.split(':');
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: int.parse(parts[0]),
                            minute: int.parse(parts[1]),
                          ),
                        );
                        if (picked != null && mounted) {
                          setState(() => _alertTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(_alertTime, style: TextStyle(
                          fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
                      ),
                    ),
                  ),
                ],
              ),
            ]),
          ),
          SizedBox(height: 24.h),

          // 안내 박스
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.2)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 18.w, color: AppTheme.accentColor),
              SizedBox(width: 10.w),
              Expanded(child: Text(
                '알림은 건강 기록에 등록된 다음 예정일(nextDate)을 기준으로 발송됩니다.\n'
                '푸시 알림은 FCM 서비스를 통해 발송되며, 기기 알림 권한이 필요합니다.',
                style: TextStyle(fontSize: 11.sp, color: AppTheme.secondaryTextColor, height: 1.5),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
        child: Text(title, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700,
          color: AppTheme.secondaryTextColor, letterSpacing: 0.3)),
      ),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
        child: Column(children: children),
      ),
    ]);
  }

  Widget _buildSwitchTile({
    required IconData icon, required String title, required String subtitle,
    required bool value, required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, size: 22.w, color: AppTheme.primaryColor),
      title: Text(title, style: TextStyle(fontSize: 14.sp)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11.sp, color: AppTheme.secondaryTextColor)),
      value: value, onChanged: onChanged,
      activeThumbColor: AppTheme.primaryColor,
    );
  }

  Widget _buildCheckTile(String tag, String label, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      title: Row(children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: AppTheme.highlightColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Text(tag, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppTheme.highlightColor)),
        ),
        SizedBox(width: 10.w),
        Text(label, style: TextStyle(fontSize: 13.sp)),
      ]),
      value: value, onChanged: _alertEnabled ? (v) => onChanged(v ?? value) : null,
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppTheme.primaryColor : null),
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }
}
