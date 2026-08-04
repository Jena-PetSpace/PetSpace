import 'dart:developer' as dev;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart'
    show GlobalKey, NavigatorState, WidgetsBinding;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'analytics_service.dart';
import 'local_notification_service.dart';
import 'notification_route_resolver.dart';

/// Firebase Cloud Messaging 서비스
/// 푸시 알림 수신과 라우팅을 관리합니다.
///
/// 토큰 생명주기와 user_devices 저장은 NotificationService 한 곳에서 담당합니다.
/// 포그라운드 수신 시 LocalNotificationService로 알림 표시
class FCMService {
  FirebaseMessaging get _firebaseMessaging => FirebaseMessaging.instance;
  final SupabaseClient _supabase;
  final LocalNotificationService? _localNotif;

  GlobalKey<NavigatorState>? _navigatorKey;
  Map<String, dynamic>? _pendingRouteData;

  /// GoRouter navigatorKey — AppRouter에서 주입합니다.
  GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;

  set navigatorKey(GlobalKey<NavigatorState>? value) {
    _navigatorKey = value;
    _schedulePendingRouting();
  }

  FCMService({
    required SupabaseClient supabase,
    LocalNotificationService? localNotificationService,
  })  : _supabase = supabase,
        _localNotif = localNotificationService;

  void _debugLog(String message) {
    if (kDebugMode) {
      dev.log(message, name: 'FCMService');
    }
  }

  /// 메시지 data 필드 기준 라우팅
  void _routeFromData(Map<String, dynamic> data) {
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      _pendingRouteData = Map<String, dynamic>.from(data);
      _schedulePendingRouting();
      return;
    }

    _pendingRouteData = null;
    final router = GoRouter.of(context);
    final userId = _supabase.auth.currentUser?.id ?? '';
    router.push(
      NotificationRouteResolver.resolve(data, currentUserId: userId),
    );
  }

  void _schedulePendingRouting([int attempt = 0]) {
    if (_pendingRouteData == null || _navigatorKey == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final data = _pendingRouteData;
      if (data == null) return;
      if (_navigatorKey?.currentContext != null) {
        _routeFromData(data);
      } else if (attempt < 4) {
        Future<void>.delayed(
          const Duration(milliseconds: 100),
          () => _schedulePendingRouting(attempt + 1),
        );
      }
    });
  }

  /// FCM 초기화
  Future<void> initialize() async {
    try {
      // 알림 권한 요청
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _debugLog('푸시 알림 권한 승인됨');
        AnalyticsService.instance.logNotificationPermissionGranted();
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        _debugLog('푸시 알림 임시 권한 승인됨');
        AnalyticsService.instance.logNotificationPermissionGranted();
      } else {
        _debugLog('푸시 알림 권한 거부됨');
        return;
      }

      // 포그라운드 메시지 핸들러
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 백그라운드 메시지 핸들러는 main.dart에서 설정

      // 알림 탭 → 딥링크 라우팅 설정
      setupInteractedMessage();

      _debugLog('FCM 초기화 완료');
    } catch (_) {
      _debugLog('FCM 초기화 실패');
    }
  }

  /// 포그라운드 메시지 처리 — 시스템 알림이 표시되지 않으므로 로컬 알림으로 표시
  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? '알림';
    final body = message.notification?.body ?? '';
    _debugLog('포그라운드 메시지 수신');

    final localNotif = _localNotif;
    if (localNotif == null) return;

    // payload 구성 (string=string only)
    final payload = LocalNotificationService.buildPayload(
      message.data.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    );

    // 해시 기반 id — 중복 방지
    final id =
        (message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString())
            .hashCode;

    localNotif.showSocialNotification(
      id: id,
      title: title,
      body: body,
      payload: payload,
      type: message.data['type']?.toString() ?? 'system',
    );
  }

  /// 알림 탭 → 인앱 라우팅 (앱이 백그라운드 → 포그라운드 전환 시)
  void setupInteractedMessage() {
    // 앱이 종료된 상태에서 알림 탭으로 열린 경우
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        _routeFromData(message.data);
      }
    });

    // 앱이 백그라운드 상태에서 알림 탭으로 포그라운드로 전환된 경우
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _debugLog('백그라운드 알림 탭 라우팅');
      _routeFromData(message.data);
    });
  }

  /// 특정 토픽 구독
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      _debugLog('토픽 구독 완료');
    } catch (_) {
      _debugLog('토픽 구독 실패');
    }
  }

  /// 특정 토픽 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      _debugLog('토픽 구독 해제 완료');
    } catch (_) {
      _debugLog('토픽 구독 해제 실패');
    }
  }
}

/// 백그라운드 메시지 핸들러 (main.dart에서 호출)
/// top-level 함수여야 함
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    dev.log('백그라운드 메시지 수신', name: 'FCMService');
  }
}
