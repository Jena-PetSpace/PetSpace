import 'dart:developer' as dev;
import 'dart:io' show Platform;

import 'package:flutter/material.dart' show GlobalKey, NavigatorState;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// 로컬 알림 서비스
/// - FCM 포그라운드 메시지를 로컬 알림으로 표시
/// - 건강 알림 D-day 스케줄링
/// - 알림 탭 시 딥링크 라우팅
class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final SupabaseClient _supabase;

  /// GoRouter navigatorKey — main.dart에서 주입
  GlobalKey<NavigatorState>? navigatorKey;

  LocalNotificationService({required SupabaseClient supabase})
      : _supabase = supabase;

  bool _initialized = false;

  /// 서비스 초기화 (main.dart에서 호출)
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. timezone 데이터 로드
      tz.initializeTimeZones();
      try {
        // 한국 기본 (시스템 timezone 가져오기 실패 시 fallback)
        tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      } catch (_) {
        // 실패해도 UTC로 fallback
      }

      // 2. 플랫폼별 초기화 설정
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings =
          InitializationSettings(android: androidInit, iOS: iosInit);

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onTap,
      );

      // 3. 채널 생성 (Android 8+)
      await _createChannels();

      // 4. 권한 요청 (iOS + Android 13+)
      await _requestPermissions();

      _initialized = true;
      dev.log('LocalNotificationService 초기화 완료',
          name: 'LocalNotificationService');
    } catch (e, st) {
      dev.log('LocalNotificationService 초기화 실패: $e',
          name: 'LocalNotificationService', error: e, stackTrace: st);
    }
  }

  Future<void> _createChannels() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'social',
        '소셜 알림',
        description: '좋아요, 댓글, 팔로우 등 소셜 활동 알림',
        importance: Importance.high,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'health',
        '건강 알림',
        description: '예방접종, 검진 등 건강관리 알림',
        importance: Importance.high,
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'system',
        '시스템 알림',
        description: '공지사항 및 시스템 메시지',
        importance: Importance.defaultImportance,
      ),
    );
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// 소셜 알림 즉시 표시 (FCM 포그라운드 수신 시 사용)
  Future<void> showSocialNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'social',
          '소셜 알림',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// 건강 알림 예약 스케줄링
  Future<void> scheduleHealthAlert({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      // 이미 지난 시간이면 스케줄 안 함
      final scheduledTz = tz.TZDateTime.from(scheduledDate, tz.local);
      if (scheduledTz.isBefore(tz.TZDateTime.now(tz.local))) {
        dev.log('과거 시간 스케줄 무시: $scheduledDate',
            name: 'LocalNotificationService');
        return;
      }

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTz,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'health',
            '건강 알림',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      dev.log('건강 알림 예약: $title @ $scheduledDate',
          name: 'LocalNotificationService');
    } catch (e, st) {
      dev.log('건강 알림 스케줄 실패: $e',
          name: 'LocalNotificationService', error: e, stackTrace: st);
    }
  }

  /// 특정 알림 취소
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// 모든 알림 취소
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// 알림 탭 시 라우팅
  void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final router = navigatorKey?.currentContext != null
        ? GoRouter.of(navigatorKey!.currentContext!)
        : null;
    if (router == null) return;

    // payload 파싱 — "key1=value1&key2=value2" 포맷
    final params = _parsePayload(payload);
    final type = params['type'];
    final postId = params['post_id'];
    final senderId = params['sender_id'];
    final userId = _supabase.auth.currentUser?.id ?? '';

    switch (type) {
      case 'like':
      case 'comment':
      case 'mention':
        if (postId != null) router.push('/post/$postId');
        break;
      case 'follow':
        if (senderId != null) {
          router.push('/user-profile/$senderId?currentUserId=$userId');
        }
        break;
      case 'health_alert':
        router.push('/health');
        break;
      default:
        router.push('/notifications?userId=$userId');
    }
  }

  Map<String, String> _parsePayload(String payload) {
    final map = <String, String>{};
    for (final part in payload.split('&')) {
      final idx = part.indexOf('=');
      if (idx > 0) {
        map[part.substring(0, idx)] =
            Uri.decodeComponent(part.substring(idx + 1));
      }
    }
    return map;
  }

  /// payload 생성 헬퍼
  static String buildPayload(Map<String, String> data) {
    return data.entries
        .map(
            (e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
