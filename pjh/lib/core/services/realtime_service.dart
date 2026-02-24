import 'dart:async';
import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Realtime을 사용한 실시간 통신 서비스
///
/// 주요 기능:
/// - 알림 실시간 구독
/// - 댓글 실시간 업데이트
/// - 좋아요 실시간 업데이트
/// - PostgreSQL Changes 구독
class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, RealtimeChannel> _channels = {};
  bool _isInitialized = false;

  // 알림 스트림 컨트롤러
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  // 댓글 스트림 컨트롤러
  final StreamController<Map<String, dynamic>> _commentController =
      StreamController<Map<String, dynamic>>.broadcast();

  // 좋아요 스트림 컨트롤러
  final StreamController<Map<String, dynamic>> _likeController =
      StreamController<Map<String, dynamic>>.broadcast();

  // 채팅 메시지 스트림 컨트롤러
  final StreamController<Map<String, dynamic>> _chatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Public streams
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;
  Stream<Map<String, dynamic>> get commentStream => _commentController.stream;
  Stream<Map<String, dynamic>> get likeStream => _likeController.stream;
  Stream<Map<String, dynamic>> get chatMessageStream => _chatMessageController.stream;

  /// 서비스 초기화
  Future<void> initialize() async {
    if (_isInitialized) {
      log('Realtime service already initialized', name: 'RealtimeService');
      return;
    }

    try {
      log('Initializing Supabase Realtime service', name: 'RealtimeService');
      _isInitialized = true;
      log('Realtime service initialized successfully', name: 'RealtimeService');
    } catch (e, stackTrace) {
      log('Failed to initialize realtime service',
          name: 'RealtimeService', error: e, stackTrace: stackTrace);
      _isInitialized = false;
      rethrow;
    }
  }

  /// 사용자별 알림 채널 구독
  ///
  /// [userId] - 구독할 사용자 ID
  Future<void> subscribeToNotifications(String userId) async {
    final channelName = 'notifications:$userId';

    if (_channels.containsKey(channelName)) {
      log('Already subscribed to notifications channel', name: 'RealtimeService');
      return;
    }

    try {
      log('Subscribing to notifications for user: $userId', name: 'RealtimeService');

      final channel = _supabase.channel(channelName);

      // PostgreSQL Changes 구독 - notifications 테이블의 INSERT 이벤트
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              log('New notification received: ${payload.newRecord}', name: 'RealtimeService');
              _notificationController.add({
                'type': 'notification',
                'event': 'insert',
                'data': payload.newRecord,
              });
            },
          )
          .subscribe();

      _channels[channelName] = channel;
      log('Successfully subscribed to notifications channel', name: 'RealtimeService');
    } catch (e, stackTrace) {
      log('Failed to subscribe to notifications',
          name: 'RealtimeService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 특정 게시물의 댓글 채널 구독
  ///
  /// [postId] - 구독할 게시물 ID
  Future<void> subscribeToPostComments(String postId) async {
    final channelName = 'comments:$postId';

    if (_channels.containsKey(channelName)) {
      log('Already subscribed to comments channel', name: 'RealtimeService');
      return;
    }

    try {
      log('Subscribing to comments for post: $postId', name: 'RealtimeService');

      final channel = _supabase.channel(channelName);

      // INSERT 이벤트 구독
      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'comments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'post_id',
          value: postId,
        ),
        callback: (payload) {
          log('New comment received: ${payload.newRecord}', name: 'RealtimeService');
          _commentController.add({
            'type': 'comment',
            'event': 'insert',
            'postId': postId,
            'data': payload.newRecord,
          });
        },
      );

      // DELETE 이벤트 구독
      channel.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'comments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'post_id',
          value: postId,
        ),
        callback: (payload) {
          log('Comment deleted: ${payload.oldRecord}', name: 'RealtimeService');
          _commentController.add({
            'type': 'comment',
            'event': 'delete',
            'postId': postId,
            'data': payload.oldRecord,
          });
        },
      );

      channel.subscribe();
      _channels[channelName] = channel;
      log('Successfully subscribed to comments channel', name: 'RealtimeService');
    } catch (e, stackTrace) {
      log('Failed to subscribe to comments',
          name: 'RealtimeService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 특정 게시물의 좋아요 채널 구독
  ///
  /// [postId] - 구독할 게시물 ID
  Future<void> subscribeToPostLikes(String postId) async {
    final channelName = 'likes:$postId';

    if (_channels.containsKey(channelName)) {
      log('Already subscribed to likes channel', name: 'RealtimeService');
      return;
    }

    try {
      log('Subscribing to likes for post: $postId', name: 'RealtimeService');

      final channel = _supabase.channel(channelName);

      // INSERT 이벤트 구독
      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'likes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'post_id',
          value: postId,
        ),
        callback: (payload) {
          log('New like received: ${payload.newRecord}', name: 'RealtimeService');
          _likeController.add({
            'type': 'like',
            'event': 'insert',
            'postId': postId,
            'data': payload.newRecord,
          });
        },
      );

      // DELETE 이벤트 구독 (좋아요 취소)
      channel.onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'likes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'post_id',
          value: postId,
        ),
        callback: (payload) {
          log('Like removed: ${payload.oldRecord}', name: 'RealtimeService');
          _likeController.add({
            'type': 'like',
            'event': 'delete',
            'postId': postId,
            'data': payload.oldRecord,
          });
        },
      );

      channel.subscribe();
      _channels[channelName] = channel;
      log('Successfully subscribed to likes channel', name: 'RealtimeService');
    } catch (e, stackTrace) {
      log('Failed to subscribe to likes',
          name: 'RealtimeService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 채팅 메시지 전체 구독 (뱃지 카운트용)
  ///
  /// [userId] - 현재 사용자 ID (자신의 참여 중인 채팅방의 메시지 수신)
  Future<void> subscribeToChatMessages(String userId) async {
    final channelName = 'chat_messages:$userId';

    if (_channels.containsKey(channelName)) {
      log('Already subscribed to chat messages channel', name: 'RealtimeService');
      return;
    }

    try {
      log('Subscribing to chat messages for user: $userId', name: 'RealtimeService');

      final channel = _supabase.channel(channelName);

      channel.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'chat_messages',
        callback: (payload) {
          log('New chat message received: ${payload.newRecord}', name: 'RealtimeService');
          _chatMessageController.add({
            'type': 'chat_message',
            'event': 'insert',
            'data': payload.newRecord,
          });
        },
      ).subscribe();

      _channels[channelName] = channel;
      log('Successfully subscribed to chat messages channel', name: 'RealtimeService');
    } catch (e, stackTrace) {
      log('Failed to subscribe to chat messages',
          name: 'RealtimeService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 특정 채널 구독 해제
  ///
  /// [channelName] - 구독 해제할 채널 이름
  Future<void> unsubscribeFromChannel(String channelName) async {
    if (!_channels.containsKey(channelName)) {
      log('Channel not found: $channelName', name: 'RealtimeService');
      return;
    }

    try {
      log('Unsubscribing from channel: $channelName', name: 'RealtimeService');

      final channel = _channels[channelName];
      await _supabase.removeChannel(channel!);
      _channels.remove(channelName);

      log('Successfully unsubscribed from channel: $channelName', name: 'RealtimeService');
    } catch (e, stackTrace) {
      log('Failed to unsubscribe from channel: $channelName',
          name: 'RealtimeService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 모든 채널 구독 해제
  Future<void> unsubscribeAll() async {
    try {
      log('Unsubscribing from all channels', name: 'RealtimeService');

      for (final entry in _channels.entries) {
        await _supabase.removeChannel(entry.value);
      }

      _channels.clear();
      log('Successfully unsubscribed from all channels', name: 'RealtimeService');
    } catch (e, stackTrace) {
      log('Failed to unsubscribe from all channels',
          name: 'RealtimeService', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 서비스 정리
  void dispose() {
    log('Disposing realtime service', name: 'RealtimeService');

    unsubscribeAll();

    _notificationController.close();
    _commentController.close();
    _likeController.close();
    _chatMessageController.close();

    _isInitialized = false;
    log('Realtime service disposed', name: 'RealtimeService');
  }

  /// 현재 구독 중인 채널 목록 반환
  List<String> getActiveChannels() {
    return _channels.keys.toList();
  }

  /// 특정 채널이 활성화되어 있는지 확인
  bool isChannelActive(String channelName) {
    return _channels.containsKey(channelName);
  }
}