import 'dart:developer' as dev;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Firebase Cloud Messaging 서비스
/// 푸시 알림을 관리하고 토큰을 Supabase에 저장
class FCMService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase;

  FCMService({required SupabaseClient supabase}) : _supabase = supabase;

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
        dev.log('푸시 알림 권한 승인됨', name: 'FCMService');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        dev.log('푸시 알림 임시 권한 승인됨', name: 'FCMService');
      } else {
        dev.log('푸시 알림 권한 거부됨', name: 'FCMService');
        return;
      }

      // FCM 토큰 가져오기
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        dev.log('FCM Token: $token', name: 'FCMService');
        await _saveTokenToDatabase(token);
      }

      // 토큰 갱신 리스너
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        dev.log('FCM Token refreshed: $newToken', name: 'FCMService');
        _saveTokenToDatabase(newToken);
      });

      // 포그라운드 메시지 핸들러
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 백그라운드 메시지 핸들러는 main.dart에서 설정

      dev.log('FCM 초기화 완료', name: 'FCMService');
    } catch (e, stackTrace) {
      dev.log('FCM 초기화 실패', error: e, stackTrace: stackTrace, name: 'FCMService');
    }
  }

  /// FCM 토큰을 데이터베이스에 저장
  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        dev.log('사용자가 로그인되지 않아 토큰 저장 생략', name: 'FCMService');
        return;
      }

      // user_devices 테이블에 토큰 저장 (중복 방지)
      await _supabase.from('user_devices').upsert({
        'user_id': userId,
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'fcm_token');

      dev.log('FCM 토큰 저장 완료: user_id=$userId', name: 'FCMService');
    } catch (e, stackTrace) {
      dev.log('FCM 토큰 저장 실패', error: e, stackTrace: stackTrace, name: 'FCMService');
    }
  }

  /// 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    dev.log('포그라운드 메시지 수신', name: 'FCMService');
    dev.log('Title: ${message.notification?.title}', name: 'FCMService');
    dev.log('Body: ${message.notification?.body}', name: 'FCMService');
    dev.log('Data: ${message.data}', name: 'FCMService');

    // TODO: 앱 내 알림 UI 표시 (SnackBar, Dialog 등)
  }

  /// 특정 토픽 구독
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      dev.log('토픽 구독 완료: $topic', name: 'FCMService');
    } catch (e, stackTrace) {
      dev.log('토픽 구독 실패', error: e, stackTrace: stackTrace, name: 'FCMService');
    }
  }

  /// 특정 토픽 구독 해제
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      dev.log('토픽 구독 해제 완료: $topic', name: 'FCMService');
    } catch (e, stackTrace) {
      dev.log('토픽 구독 해제 실패', error: e, stackTrace: stackTrace, name: 'FCMService');
    }
  }

  /// FCM 토큰 가져오기
  Future<String?> getToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e, stackTrace) {
      dev.log('FCM 토큰 가져오기 실패', error: e, stackTrace: stackTrace, name: 'FCMService');
      return null;
    }
  }

  /// 현재 기기의 토큰 삭제
  Future<void> deleteToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _firebaseMessaging.deleteToken();

        // 데이터베이스에서도 삭제
        await _supabase
            .from('user_devices')
            .delete()
            .eq('fcm_token', token);

        dev.log('FCM 토큰 삭제 완료', name: 'FCMService');
      }
    } catch (e, stackTrace) {
      dev.log('FCM 토큰 삭제 실패', error: e, stackTrace: stackTrace, name: 'FCMService');
    }
  }
}

/// 백그라운드 메시지 핸들러 (main.dart에서 호출)
/// top-level 함수여야 함
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  dev.log('백그라운드 메시지 수신', name: 'FCMService');
  dev.log('Title: ${message.notification?.title}', name: 'FCMService');
  dev.log('Body: ${message.notification?.body}', name: 'FCMService');
  dev.log('Data: ${message.data}', name: 'FCMService');
}
