import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_notification_service.dart';

/// FCM 토큰 생명주기 + user_devices 테이블 관리
///
/// FCMService 는 포그라운드 메시지 수신/라우팅을 담당하고,
/// NotificationService 는 토큰 등록/비활성화를 담당합니다.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _registeredUserId;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) {
          final userId = _registeredUserId;
          if (userId != null) {
            unawaited(_upsertToken(userId: userId, token: token));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          log(
            'FCM 토큰 갱신 구독 오류',
            name: 'NotificationService',
            error: error,
            stackTrace: stackTrace,
          );
        },
      );
      _isInitialized = true;
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId != null) {
        await registerToken(currentUserId);
      }
      log('NotificationService 초기화 완료', name: 'NotificationService');
    } catch (error, stackTrace) {
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;
      _isInitialized = false;
      log(
        'NotificationService 초기화 실패',
        name: 'NotificationService',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ── 토큰 등록 ──────────────────────────────────────────────────────────────

  /// 로그인 성공 후 호출 — FCM 토큰을 user_devices 테이블에 upsert
  Future<void> registerToken(String userId) async {
    try {
      _registeredUserId = userId;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _upsertToken(userId: userId, token: token);
      log('FCM 토큰 등록 완료', name: 'NotificationService');
    } catch (error, stackTrace) {
      log(
        'FCM 토큰 등록 실패',
        name: 'NotificationService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  // ── 토큰 비활성화 ──────────────────────────────────────────────────────────

  /// 로그아웃 시 호출 — 해당 기기 토큰을 is_active=false 로 마킹
  Future<void> deactivateToken() async {
    try {
      _registeredUserId = null;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await Supabase.instance.client.from('user_devices').update({
        'is_active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('fcm_token', token);

      log('FCM 토큰 비활성화 완료', name: 'NotificationService');
    } catch (error, stackTrace) {
      log(
        'FCM 토큰 비활성화 실패',
        name: 'NotificationService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  // ── 알림 권한 요청 (필요 시 직접 호출) ───────────────────────────────────

  Future<bool> requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      log('알림 권한 요청 실패: $e', name: 'NotificationService', error: e);
      return false;
    }
  }

  // ── 로컬 알림 ─────────────────────────────────────────────────────────────

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    Map<String, String>? payload,
  }) async {
    try {
      final localNotif = LocalNotificationService(
        supabase: Supabase.instance.client,
      );
      await localNotif.showSocialNotification(
        id: id,
        title: title,
        body: body,
        payload: payload != null
            ? LocalNotificationService.buildPayload(payload)
            : null,
      );
    } catch (e) {
      log('로컬 알림 표시 실패: $e', name: 'NotificationService', error: e);
    }
  }

  // ── 내부 헬퍼 ─────────────────────────────────────────────────────────────

  Future<void> _upsertToken({
    required String userId,
    required String token,
  }) async {
    final platform =
        Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'other');

    await Supabase.instance.client.from('user_devices').upsert({
      'user_id': userId,
      'fcm_token': token,
      'platform': platform,
      'is_active': true,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'fcm_token');
  }
}
