import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../shared/themes/app_theme.dart';

class HealthAlertSettingsPage extends StatefulWidget {
  final LocalNotificationService? notificationService;

  const HealthAlertSettingsPage({
    super.key,
    this.notificationService,
  });

  @override
  State<HealthAlertSettingsPage> createState() =>
      _HealthAlertSettingsPageState();
}

class _HealthAlertSettingsPageState extends State<HealthAlertSettingsPage> {
  bool _isTesting = false;
  String? _resultMessage;
  bool _resultSucceeded = false;
  HealthAlertScheduleResult? _lastResult;

  LocalNotificationService get _notificationService =>
      widget.notificationService ?? sl<LocalNotificationService>();

  Future<void> _sendTestNotification() async {
    if (_isTesting) return;
    setState(() {
      _isTesting = true;
      _resultMessage = null;
      _lastResult = null;
    });

    final result = await _notificationService.scheduleHealthAlert(
      id: 999999,
      title: '알림 테스트',
      body: '건강 알림이 정상적으로 동작합니다.',
      scheduledDate: DateTime.now().add(const Duration(seconds: 5)),
    );
    if (!mounted) return;

    setState(() {
      _isTesting = false;
      _lastResult = result;
      _resultSucceeded = result == HealthAlertScheduleResult.scheduled;
      _resultMessage = switch (result) {
        HealthAlertScheduleResult.scheduled =>
          '테스트 알림을 예약했어요. 5초 뒤 수신 여부를 확인해주세요. 자동 예정일 알림이 켜진 것은 아닙니다.',
        HealthAlertScheduleResult.permissionDenied =>
          '기기 설정에서 알림 권한을 허용한 뒤 다시 시도해주세요.',
        HealthAlertScheduleResult.unavailable =>
          '알림 서비스를 준비하지 못했어요. 앱을 다시 시작한 뒤 시도해주세요.',
        HealthAlertScheduleResult.invalidDate => '알림 시간을 확인하지 못했어요. 다시 시도해주세요.',
        HealthAlertScheduleResult.failed =>
          '테스트 알림을 예약하지 못했어요. 잠시 후 다시 시도해주세요.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '건강 알림',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _buildAutomaticAlertCard(theme),
          SizedBox(height: 16.h),
          _buildTestAlertCard(theme),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: AppTheme.actionContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 20,
                  color: AppTheme.actionBase,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    '기기 알림 테스트는 현재 기기의 권한과 수신 여부만 확인합니다. '
                    '건강 기록 예정일에 맞춘 자동 알림은 아직 제공되지 않습니다.',
                    style: TextStyle(
                      fontSize: AppTheme.fontCaption.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
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

  Widget _buildAutomaticAlertCard(ThemeData theme) {
    return _card(
      theme: theme,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconBox(Icons.event_available_outlined),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '자동 예정일 알림',
                  style: TextStyle(
                    fontSize: AppTheme.fontBody.sp,
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '건강 기록 예정일에 맞춘 자동 알림은 운영 연결과 검증이 끝난 뒤 제공됩니다.',
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: AppTheme.actionContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
            ),
            child: Text(
              '준비 중',
              style: TextStyle(
                fontSize: AppTheme.fontMicro.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.brandDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestAlertCard(ThemeData theme) {
    return _card(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBox(Icons.notifications_active_outlined),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '기기 알림 테스트',
                      style: TextStyle(
                        fontSize: AppTheme.fontBody.sp,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '5초 뒤 알림을 예약해 현재 기기의 권한과 수신 여부를 확인합니다.',
                      style: TextStyle(
                        fontSize: AppTheme.fontCaption.sp,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              key: const Key('health_alert_test_button'),
              onPressed: _isTesting ? null : _sendTestNotification,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.actionBase,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
                ),
              ),
              child: _isTesting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('5초 뒤 테스트 알림 보내기'),
            ),
          ),
          if (_resultMessage != null) ...[
            SizedBox(height: 12.h),
            Semantics(
              liveRegion: true,
              child: Container(
                key: const Key('health_alert_test_result'),
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: _resultSucceeded
                      ? AppTheme.actionContainer
                      : AppTheme.errorColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _resultMessage!,
                      style: TextStyle(
                        fontSize: AppTheme.fontCaption.sp,
                        color: _resultSucceeded
                            ? AppTheme.brandDeep
                            : AppTheme.errorColor,
                        height: 1.45,
                      ),
                    ),
                    if (_lastResult ==
                        HealthAlertScheduleResult.permissionDenied) ...[
                      SizedBox(height: 8.h),
                      TextButton.icon(
                        key: const Key('health_alert_open_settings'),
                        onPressed: openAppSettings,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(44, 44),
                        ),
                        icon: const Icon(Icons.settings_outlined, size: 18),
                        label: const Text('기기 설정 열기'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({
    required ThemeData theme,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
        border: Border.all(color: AppTheme.border),
        boxShadow:
            theme.brightness == Brightness.dark ? null : AppTheme.cardShadow,
      ),
      child: child,
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.actionContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
      ),
      child: Icon(icon, color: AppTheme.actionBase, size: 22),
    );
  }
}
