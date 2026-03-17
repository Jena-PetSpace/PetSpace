import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Edge Function `send-notification`을 호출해
/// FCM 푸시 알림을 발송하고 notifications 테이블에 저장합니다.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // ── 알림 발송 헬퍼 ────────────────────────────────────────────────────────

  /// 좋아요 알림
  Future<void> sendLikeNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String postId,
  }) async {
    await _send(
      userId: toUserId,
      senderId: fromUserId,
      senderName: fromUserName,
      type: 'like',
      title: '$fromUserName님이 회원님의 게시글을 좋아합니다',
      body: '게시글을 확인해보세요 ❤️',
      postId: postId,
    );
  }

  /// 댓글 알림
  Future<void> sendCommentNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String postId,
    required String commentPreview,
  }) async {
    await _send(
      userId: toUserId,
      senderId: fromUserId,
      senderName: fromUserName,
      type: 'comment',
      title: '$fromUserName님이 댓글을 남겼습니다',
      body: commentPreview.length > 50
          ? '${commentPreview.substring(0, 50)}...'
          : commentPreview,
      postId: postId,
    );
  }

  /// 팔로우 알림
  Future<void> sendFollowNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
  }) async {
    await _send(
      userId: toUserId,
      senderId: fromUserId,
      senderName: fromUserName,
      type: 'follow',
      title: '$fromUserName님이 팔로우를 시작했습니다',
      body: '프로필을 확인해보세요 🐾',
    );
  }

  /// 감정 분석 완료 알림 (본인에게)
  Future<void> sendEmotionAnalysisNotification({
    required String userId,
    required String petName,
    required String dominantEmotion,
  }) async {
    await _send(
      userId: userId,
      type: 'emotionAnalysis',
      title: '$petName의 감정 분석 완료',
      body: '주요 감정: $dominantEmotion — 결과를 확인해보세요 🧠',
    );
  }

  // ── 내부 공통 발송 ────────────────────────────────────────────────────────

  Future<void> _send({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? senderId,
    String? senderName,
    String? postId,
    Map<String, String>? data,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-notification',
        body: {
          'userId': userId,
          if (senderId != null) 'senderId': senderId,
          if (senderName != null) 'senderName': senderName,
          'type': type,
          'title': title,
          'body': body,
          if (postId != null) 'postId': postId,
          if (data != null) 'data': data,
        },
      );
      dev.log('알림 발송 완료: $type → $userId', name: 'PushNotificationService');
    } catch (e) {
      // 알림 실패가 메인 기능을 막지 않도록 에러 무시
      dev.log('알림 발송 실패: $e', name: 'PushNotificationService', error: e);
    }
  }
}
