import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_room_model.dart';
import '../models/chat_message_model.dart';
import '../models/chat_participant_model.dart';

abstract class ChatRemoteDataSource {
  Future<List<ChatRoomModel>> getChatRooms(String userId);
  Future<List<ChatMessageModel>> getChatMessages({
    required String roomId,
    int limit = 30,
    String? lastMessageId,
  });
  Future<ChatMessageModel> sendMessage({
    required String roomId,
    required String senderId,
    required String content,
  });
  Future<ChatMessageModel> sendImageMessage({
    required String roomId,
    required String senderId,
    required File imageFile,
  });
  Future<ChatRoomModel> createDirectChat({
    required String currentUserId,
    required String otherUserId,
  });
  Future<ChatRoomModel> createGroupChat({
    required String name,
    required String creatorId,
    required List<String> memberIds,
  });
  Future<void> updateLastRead({required String roomId, required String userId});
  Future<int> getTotalUnreadCount(String userId);
  Future<List<ChatParticipantModel>> searchUsers(String query);
  Future<void> leaveChatRoom({
    required String roomId,
    required String userId,
    String? leaverName,
  });
  Future<void> addChatMembers({
    required String roomId,
    required List<String> memberIds,
  });
  Future<void> updateChatRoomName({
    required String roomId,
    required String name,
  });
  Future<void> updateChatRoomPhoto({
    required String roomId,
    required String photoUrl,
  });
  Future<String> uploadChatRoomPhoto({
    required String roomId,
    required String userId,
    required File file,
  });
  Future<Map<String, dynamic>?> getChatRoomInfo(String roomId);
  Future<List<ChatParticipantModel>> getRoomParticipants(String roomId);
  Future<ChatMessageModel> sendMultiImageMessage({
    required String roomId,
    required String senderId,
    required List<File> imageFiles,
  });

  /// 특정 채팅방의 새 메시지 Stream (Realtime INSERT 이벤트).
  /// 구독 취소 시 내부 channel 자동 정리.
  Stream<ChatMessageModel> subscribeToRoomMessages(String roomId);

  /// 채팅 상대 사용자 신고 (reports.reported_user_id).
  Future<void> reportChatUser({
    required String reportedUserId,
    required String reporterId,
    required String reason,
  });

  /// 개별 채팅 메시지 신고 (reports.reported_message_id).
  Future<void> reportChatMessage({
    required String messageId,
    required String reporterId,
    required String reason,
  });
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final SupabaseClient supabaseClient;

  ChatRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<ChatRoomModel>> getChatRooms(String userId) async {
    // 사용자가 참여 중인 채팅방 조회 (참여자 + 유저 정보 JOIN)
    final response = await supabaseClient.from('chat_rooms').select('''
          id,
          type,
          name,
          description,
          avatar_url,
          created_by,
          created_at,
          updated_at,
          chat_participants!inner(
            *,
            users(id, display_name, photo_url)
          )
        ''').eq('chat_participants.is_active', true);

    final roomDataList = (response as List).cast<Map<String, dynamic>>();

    // RLS가 숨긴 차단 사용자의 메시지는 채팅방 미리보기에도 노출하지 않는다.
    // chat_rooms의 비정규화 last_message 필드를 직접 받지 않고, 현재 사용자에게
    // 서버에서 실제로 보이는 가장 최근 chat_messages 행으로 미리보기를 재구성한다.
    final safeRoomDataList = await Future.wait(
      roomDataList.map((roomData) async {
        final preview = await supabaseClient
            .from('chat_messages')
            .select('content, type, sender_id, created_at')
            .eq('room_id', roomData['id'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        final safeRoomData = Map<String, dynamic>.from(roomData);
        if (preview == null) {
          safeRoomData['last_message'] = null;
          safeRoomData['last_message_at'] = null;
          safeRoomData['last_message_sender_id'] = null;
        } else {
          safeRoomData['last_message'] =
              preview['type'] == 'image' ? '사진을 보냈습니다' : preview['content'];
          safeRoomData['last_message_at'] = preview['created_at'];
          safeRoomData['last_message_sender_id'] = preview['sender_id'];
        }
        return safeRoomData;
      }),
    );
    safeRoomDataList.sort((a, b) {
      final aValue = a['last_message_at'] as String?;
      final bValue = b['last_message_at'] as String?;
      if (aValue == null) return bValue == null ? 0 : 1;
      if (bValue == null) return -1;
      return DateTime.parse(bValue).compareTo(DateTime.parse(aValue));
    });

    // 모든 채팅방의 안읽은 메시지 수를 병렬로 조회 (N+1 → 1+N 병렬)
    final unreadCounts = await Future.wait(
      safeRoomDataList.map((roomData) async {
        try {
          final value = await supabaseClient.rpc(
            'get_room_unread_count',
            params: {'p_room_id': roomData['id']},
          );
          return value as int? ?? 0;
        } catch (_) {
          // 다른 세션에서 방을 나간 직후의 경쟁 상태는 다음 새로고침에서
          // 방 자체가 사라지므로 한 방의 실패로 전체 목록을 막지 않는다.
          return 0;
        }
      }),
    );

    return [
      for (var i = 0; i < safeRoomDataList.length; i++)
        ChatRoomModel.fromJson(
          safeRoomDataList[i],
          unreadCount: unreadCounts[i],
        ),
    ];
  }

  @override
  Future<List<ChatMessageModel>> getChatMessages({
    required String roomId,
    int limit = 30,
    String? lastMessageId,
  }) async {
    // 메시지만 먼저 조회 (FK join 없이 — RLS 단순화)
    List<Map<String, dynamic>> messages;

    if (lastMessageId != null) {
      // 커서 기반 페이지네이션: 마지막 메시지 이전 메시지들
      final lastMsg = await supabaseClient
          .from('chat_messages')
          .select('created_at')
          .eq('id', lastMessageId)
          .maybeSingle();

      if (lastMsg == null) return const [];

      messages = ((await supabaseClient
              .from('chat_messages')
              .select('*')
              .eq('room_id', roomId)
              .lt('created_at', lastMsg['created_at'])
              .order('created_at', ascending: false)
              .limit(limit)) as List)
          .cast<Map<String, dynamic>>();
    } else {
      messages = ((await supabaseClient
              .from('chat_messages')
              .select('*')
              .eq('room_id', roomId)
              .order('created_at', ascending: false)
              .limit(limit)) as List)
          .cast<Map<String, dynamic>>();
    }

    if (messages.isEmpty) return [];

    // sender_id 목록으로 유저 정보 일괄 조회
    final senderIds =
        messages.map((m) => m['sender_id'] as String).toSet().toList();
    final usersResponse = await supabaseClient
        .from('users')
        .select('id, display_name, photo_url')
        .inFilter('id', senderIds);
    final usersMap = {
      for (final u in (usersResponse as List).cast<Map<String, dynamic>>())
        u['id'] as String: u,
    };

    return messages.map((json) {
      final enriched = Map<String, dynamic>.from(json);
      enriched['users'] = usersMap[json['sender_id'] as String];
      return ChatMessageModel.fromJson(enriched);
    }).toList();
  }

  @override
  Future<ChatMessageModel> sendMessage({
    required String roomId,
    required String senderId,
    required String content,
  }) async {
    final response = await supabaseClient.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': senderId,
      'content': content,
      'type': 'text',
    }).select('''
          *,
          users:sender_id(id, display_name, photo_url)
        ''').single();

    return ChatMessageModel.fromJson(response);
  }

  @override
  Future<ChatMessageModel> sendImageMessage({
    required String roomId,
    required String senderId,
    required File imageFile,
  }) async {
    // 이미지 업로드
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = 'chat/$senderId/$timestamp.jpg';

    await supabaseClient.storage.from('images').upload(filePath, imageFile);

    final imageUrl =
        supabaseClient.storage.from('images').getPublicUrl(filePath);

    // 이미지 메시지 전송
    final response = await supabaseClient.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': senderId,
      'content': null,
      'type': 'image',
      'image_url': imageUrl,
    }).select('''
          *,
          users:sender_id(id, display_name, photo_url)
        ''').single();

    return ChatMessageModel.fromJson(response);
  }

  @override
  Future<ChatRoomModel> createDirectChat({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final roomIdResponse = await supabaseClient.rpc(
      'get_or_create_direct_chat',
      params: {'p_other_user_id': otherUserId},
    );
    final roomId = roomIdResponse as String;
    final response = await supabaseClient.from('chat_rooms').select('''
          id,
          type,
          name,
          description,
          avatar_url,
          created_by,
          created_at,
          updated_at,
          chat_participants(
            *,
            users(id, display_name, photo_url)
          )
        ''').eq('id', roomId).single();

    return ChatRoomModel.fromJson(response);
  }

  @override
  Future<ChatRoomModel> createGroupChat({
    required String name,
    required String creatorId,
    required List<String> memberIds,
  }) async {
    final normalizedMemberIds =
        memberIds.where((id) => id != creatorId).toSet().toList();
    final roomIdResponse = await supabaseClient.rpc(
      'create_group_chat',
      params: {'p_name': name, 'p_member_ids': normalizedMemberIds},
    );
    final roomId = roomIdResponse as String;

    // 완성된 채팅방 조회
    final response = await supabaseClient.from('chat_rooms').select('''
          id,
          type,
          name,
          description,
          avatar_url,
          created_by,
          created_at,
          updated_at,
          chat_participants(
            *,
            users(id, display_name, photo_url)
          )
        ''').eq('id', roomId).single();

    return ChatRoomModel.fromJson(response);
  }

  @override
  Future<void> updateLastRead({
    required String roomId,
    required String userId,
  }) async {
    await supabaseClient
        .from('chat_participants')
        .update({'last_read_at': DateTime.now().toIso8601String()})
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  @override
  Future<int> getTotalUnreadCount(String userId) async {
    final result = await supabaseClient.rpc('get_total_unread_count');
    return result as int? ?? 0;
  }

  @override
  Future<List<ChatParticipantModel>> searchUsers(String query) async {
    final currentUserId = supabaseClient.auth.currentUser?.id;

    // 1. 닉네임으로 사용자 검색
    final userResults = await supabaseClient
        .from('users')
        .select('id, display_name, photo_url')
        .ilike('display_name', '%$query%')
        .neq('id', currentUserId ?? '')
        .limit(20);

    // 2. 반려동물 이름으로 검색 → 주인의 user_id 목록
    final petResults = await supabaseClient
        .from('pets')
        .select('user_id')
        .ilike('name', '%$query%')
        .limit(20);

    // 3. 결과 합치기 (중복 제거)
    final Map<String, Map<String, dynamic>> combined = {};

    for (final json in userResults as List) {
      final map = json as Map<String, dynamic>;
      combined[map['id'] as String] = map;
    }

    // 반려동물 주인 user_id 중 아직 없는 것만 추가 조회
    final petOwnerIds = (petResults as List)
        .map((json) => (json as Map<String, dynamic>)['user_id'] as String)
        .where((id) => id != currentUserId && !combined.containsKey(id))
        .toSet()
        .toList();

    if (petOwnerIds.isNotEmpty) {
      final ownerResults = await supabaseClient
          .from('users')
          .select('id, display_name, photo_url')
          .inFilter('id', petOwnerIds)
          .limit(20);

      for (final json in ownerResults as List) {
        final map = json as Map<String, dynamic>;
        combined[map['id'] as String] = map;
      }
    }

    return combined.values
        .map((json) => ChatParticipantModel.fromUserJson(json))
        .toList();
  }

  @override
  Future<void> leaveChatRoom({
    required String roomId,
    required String userId,
    String? leaverName,
  }) async {
    // 시스템 메시지 먼저 (나가기 전에 보내야 RLS 통과)
    if (leaverName != null && leaverName.isNotEmpty) {
      await supabaseClient.from('chat_messages').insert({
        'room_id': roomId,
        'sender_id': userId,
        'content': '$leaverName님이 채팅방을 나갔습니다.',
        'type': 'system',
      });
    }
    await supabaseClient
        .from('chat_participants')
        .update({'is_active': false})
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  @override
  Future<void> addChatMembers({
    required String roomId,
    required List<String> memberIds,
  }) async {
    final participants = memberIds
        .map((id) => {'room_id': roomId, 'user_id': id, 'is_active': true})
        .toList();
    await supabaseClient
        .from('chat_participants')
        .upsert(participants, onConflict: 'room_id,user_id');
  }

  @override
  Future<void> updateChatRoomName({
    required String roomId,
    required String name,
  }) async {
    await supabaseClient
        .from('chat_rooms')
        .update({'name': name}).eq('id', roomId);
  }

  @override
  Future<void> updateChatRoomPhoto({
    required String roomId,
    required String photoUrl,
  }) async {
    await supabaseClient
        .from('chat_rooms')
        .update({'avatar_url': photoUrl}).eq('id', roomId);
  }

  @override
  Future<String> uploadChatRoomPhoto({
    required String roomId,
    required String userId,
    required File file,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = 'chat/$userId/room_${roomId}_$timestamp.jpg';
    await supabaseClient.storage.from('images').upload(filePath, file);
    final publicUrl =
        supabaseClient.storage.from('images').getPublicUrl(filePath);
    await supabaseClient
        .from('chat_rooms')
        .update({'avatar_url': publicUrl}).eq('id', roomId);
    return publicUrl;
  }

  @override
  Future<Map<String, dynamic>?> getChatRoomInfo(String roomId) async {
    final response = await supabaseClient
        .from('chat_rooms')
        .select('name, avatar_url, type')
        .eq('id', roomId)
        .maybeSingle();
    return response;
  }

  @override
  Future<ChatMessageModel> sendMultiImageMessage({
    required String roomId,
    required String senderId,
    required List<File> imageFiles,
  }) async {
    final List<String> uploadedUrls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExt = imageFiles[i].path.split('.').last;
      final filePath = 'chat/$senderId/${timestamp}_$i.$fileExt';

      await supabaseClient.storage
          .from('images')
          .upload(filePath, imageFiles[i]);
      final url = supabaseClient.storage.from('images').getPublicUrl(filePath);
      uploadedUrls.add(url);
    }

    final response = await supabaseClient.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': senderId,
      'content': '사진 ${uploadedUrls.length}장',
      'type': 'image',
      'image_url': uploadedUrls.first,
      'image_urls': uploadedUrls,
    }).select('''
          *,
          users:sender_id(id, display_name, photo_url)
        ''').single();

    return ChatMessageModel.fromJson(response);
  }

  @override
  Future<List<ChatParticipantModel>> getRoomParticipants(String roomId) async {
    final response = await supabaseClient.from('chat_participants').select('''
          *,
          users(id, display_name, photo_url)
        ''').eq('room_id', roomId).eq('is_active', true);

    return (response as List)
        .map(
          (json) => ChatParticipantModel.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Stream<ChatMessageModel> subscribeToRoomMessages(String roomId) {
    final controller = StreamController<ChatMessageModel>();
    RealtimeChannel? channel;

    channel = supabaseClient.channel('chat_messages:$roomId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'chat_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (payload) {
          try {
            controller.add(ChatMessageModel.fromJson(payload.newRecord));
          } catch (e, st) {
            controller.addError(e, st);
          }
        },
      ).subscribe();

    controller.onCancel = () async {
      if (channel != null) {
        await supabaseClient.removeChannel(channel);
      }
    };

    return controller.stream;
  }

  @override
  Future<void> reportChatUser({
    required String reportedUserId,
    required String reporterId,
    required String reason,
  }) async {
    await supabaseClient.from('reports').insert({
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'reason': reason,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> reportChatMessage({
    required String messageId,
    required String reporterId,
    required String reason,
  }) async {
    await supabaseClient.from('reports').insert({
      'reporter_id': reporterId,
      'reported_message_id': messageId,
      'reason': reason,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
