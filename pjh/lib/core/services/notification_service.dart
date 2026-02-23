import 'dart:developer';

// import 'dart:convert'; // 현재 사용하지 않음
// import 'dart:io'; // 현재 사용하지 않음

// Firebase 제거로 인한 임시 stub 구현

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    log('Notification service initialized (stub)', name: 'NotificationService.init');
    _isInitialized = true;
  }

  Future<void> requestPermission() async {
    log('Notification permission requested (stub)', name: 'NotificationService.permission');
  }

  Future<String?> getToken() async {
    log('Getting FCM token (stub)', name: 'NotificationService.token');
    return 'stub_token';
  }

  Future<void> subscribeToTopic(String topic) async {
    log('Subscribed to topic: $topic (stub)', name: 'NotificationService.subscribe');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    log('Unsubscribed from topic: $topic (stub)', name: 'NotificationService.unsubscribe');
  }

  Future<void> sendNotification({
    required String title,
    required String body,
    String? userId,
    Map<String, dynamic>? data,
  }) async {
    log('Sending notification: $title - $body (stub)', name: 'NotificationService.send');
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    log('Showing local notification: $title - $body (stub)', name: 'NotificationService.local');
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    Map<String, dynamic>? payload,
  }) async {
    log('Scheduled notification: $title at $scheduledDate (stub)', name: 'NotificationService.schedule');
  }

  Future<void> cancelNotification(int id) async {
    log('Cancelled notification: $id (stub)', name: 'NotificationService.cancel');
  }

  Future<void> cancelAllNotifications() async {
    log('Cancelled all notifications (stub)', name: 'NotificationService.cancelAll');
  }
}