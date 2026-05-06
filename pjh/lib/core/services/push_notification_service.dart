import 'dart:async';
import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';

/// notifications 테이블에 직접 INSERT하여 인앱 알림을 생성합니다.
/// Supabase Realtime 구독을 통해 실시간으로 수신됩니다.
/// (FCM 서버 푸시는 서비스 계정 키 확보 후 Edge Function 연결 예정)
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // ── 좋아요 배치 처리 ──────────────────────────────────────────────────────
  // 같은 postId로 들어오는 좋아요 알림을 5초 동안 모아 1건으로 합침
  // key: "$toUserId:$postId"
  final Map<String, _LikeBatch> _likeBatches = {};

  // ── 알림 발송 헬퍼 ────────────────────────────────────────────────────────

  /// 좋아요 알림 (배치: 5초 내 동일 게시글 다중 좋아요 → 묶음 알림)
  Future<void> sendLikeNotification({
    required String toUserId,
    required String fromUserId,
    required String fromUserName,
    required String postId,
  }) async {
    // 자기 자신 좋아요 제외
    if (fromUserId == toUserId) return;

    final batchKey = '$toUserId:$postId';
    final existing = _likeBatches[batchKey];

    if (existing != null) {
      // 이미 대기 중인 배치에 추가
      existing.addSender(fromUserId, fromUserName);
      return;
    }

    // 새 배치 시작 — 5초 후 flush
    final batch = _LikeBatch(firstSenderId: fromUserId, firstName: fromUserName);
    _likeBatches[batchKey] = batch;

    batch.timer = Timer(const Duration(seconds: 5), () async {
      _likeBatches.remove(batchKey);
      await _flushLikeBatch(
        toUserId: toUserId,
        postId: postId,
        batch: batch,
      );
    });
  }

  Future<void> _flushLikeBatch({
    required String toUserId,
    required String postId,
    required _LikeBatch batch,
  }) async {
    final count = batch.senderIds.length;
    final firstName = batch.firstName;

    final title = count == 1
        ? '$firstName님이 회원님의 게시글을 좋아합니다'
        : '$firstName님 외 ${count - 1}명이 게시글을 좋아합니다';

    try {
      // 같은 게시글의 미읽음 좋아요 알림이 이미 있으면 업데이트(배치 누적), 없으면 INSERT
      final existing = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', toUserId)
          .eq('post_id', postId)
          .eq('type', 'like')
          .eq('is_read', false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('notifications')
            .update({
              'title': title,
              'body': '게시글을 확인해보세요 ❤️',
              'sender_name': firstName,
              'created_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id'] as String);
        dev.log('좋아요 알림 업데이트: $title', name: 'PushNotificationService');
      } else {
        await _send(
          userId: toUserId,
          senderId: batch.senderIds.first,
          senderName: firstName,
          type: 'like',
          title: title,
          body: '게시글을 확인해보세요 ❤️',
          postId: postId,
        );
      }
    } catch (e) {
      dev.log('좋아요 배치 flush 실패: $e', name: 'PushNotificationService', error: e);
    }
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
      // 자기 자신에게 알림 보내지 않기
      if (senderId != null && senderId == userId) return;

      // notifications 테이블에 직접 INSERT
      await _supabase.from('notifications').insert({
        'user_id': userId,
        if (senderId != null) 'sender_id': senderId,
        if (senderName != null) 'sender_name': senderName,
        'type': type,
        'title': title,
        'body': body,
        'is_read': false,
        if (postId != null) 'post_id': postId,
        'data': data ?? {},
        'created_at': DateTime.now().toIso8601String(),
      });

      dev.log('알림 저장 완료: $type → $userId', name: 'PushNotificationService');
    } catch (e) {
      // 알림 실패가 메인 기능을 막지 않도록 에러 무시
      dev.log('알림 저장 실패: $e', name: 'PushNotificationService', error: e);
    }
  }
}

// ── 좋아요 배치 상태 ──────────────────────────────────────────────────────────

class _LikeBatch {
  Timer? timer;
  final List<String> senderIds;
  final List<String> senderNames;

  _LikeBatch({required String firstSenderId, required String firstName})
      : senderIds = [firstSenderId],
        senderNames = [firstName];

  String get firstName => senderNames.first;

  void addSender(String id, String name) {
    if (!senderIds.contains(id)) {
      senderIds.add(id);
      senderNames.add(name);
    }
  }
}
