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
  Future<void> leaveChatRoom({required String roomId, required String userId});
  Future<void> addChatMembers({
    required String roomId,
    required List<String> memberIds,
  });
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final SupabaseClient supabaseClient;

  ChatRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<ChatRoomModel>> getChatRooms(String userId) async {
    // 사용자가 참여 중인 채팅방 조회 (참여자 + 유저 정보 JOIN)
    final response = await supabaseClient
        .from('chat_rooms')
        .select('''
          *,
          chat_participants!inner(
            *,
            users(id, display_name, photo_url)
          )
        ''')
        .order('last_message_at', ascending: false, nullsFirst: false);

    final rooms = <ChatRoomModel>[];
    for (final json in response as List) {
      final roomData = json as Map<String, dynamic>;

      // 안읽은 메시지 수 조회
      final unreadCount = await supabaseClient
          .rpc('get_room_unread_count', params: {
        'p_room_id': roomData['id'],
        'p_user_id': userId,
      });

      rooms.add(ChatRoomModel.fromJson(roomData, unreadCount: unreadCount as int? ?? 0));
    }

    return rooms;
  }

  @override
  Future<List<ChatMessageModel>> getChatMessages({
    required String roomId,
    int limit = 30,
    String? lastMessageId,
  }) async {
    var query = supabaseClient
        .from('chat_messages')
        .select('''
          *,
          users:sender_id(id, display_name, photo_url)
        ''')
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(limit);

    if (lastMessageId != null) {
      // 커서 기반 페이지네이션: 마지막 메시지 이전 메시지들
      final lastMsg = await supabaseClient
          .from('chat_messages')
          .select('created_at')
          .eq('id', lastMessageId)
          .single();

      query = supabaseClient
          .from('chat_messages')
          .select('''
            *,
            users:sender_id(id, display_name, photo_url)
          ''')
          .eq('room_id', roomId)
          .lt('created_at', lastMsg['created_at'])
          .order('created_at', ascending: false)
          .limit(limit);
    }

    final response = await query;
    return (response as List)
        .map((json) => ChatMessageModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ChatMessageModel> sendMessage({
    required String roomId,
    required String senderId,
    required String content,
  }) async {
    final response = await supabaseClient
        .from('chat_messages')
        .insert({
          'room_id': roomId,
          'sender_id': senderId,
          'content': content,
          'type': 'text',
        })
        .select('''
          *,
          users:sender_id(id, display_name, photo_url)
        ''')
        .single();

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

    await supabaseClient.storage
        .from('images')
        .upload(filePath, imageFile);

    final imageUrl = supabaseClient.storage
        .from('images')
        .getPublicUrl(filePath);

    // 이미지 메시지 전송
    final response = await supabaseClient
        .from('chat_messages')
        .insert({
          'room_id': roomId,
          'sender_id': senderId,
          'content': null,
          'type': 'image',
          'image_url': imageUrl,
        })
        .select('''
          *,
          users:sender_id(id, display_name, photo_url)
        ''')
        .single();

    return ChatMessageModel.fromJson(response);
  }

  @override
  Future<ChatRoomModel> createDirectChat({
    required String currentUserId,
    required String otherUserId,
  }) async {
    // 기존 1:1 채팅방 검색
    final existingRoomId = await supabaseClient
        .rpc('find_direct_chat', params: {
      'p_user1_id': currentUserId,
      'p_user2_id': otherUserId,
    });

    if (existingRoomId != null) {
      // 기존 채팅방 반환
      final response = await supabaseClient
          .from('chat_rooms')
          .select('''
            *,
            chat_participants(
              *,
              users(id, display_name, photo_url)
            )
          ''')
          .eq('id', existingRoomId)
          .single();

      return ChatRoomModel.fromJson(response);
    }

    // 새 채팅방 생성
    final roomResponse = await supabaseClient
        .from('chat_rooms')
        .insert({
          'type': 'direct',
          'created_by': currentUserId,
        })
        .select()
        .single();

    final roomId = roomResponse['id'] as String;

    // 참여자 추가
    await supabaseClient.from('chat_participants').insert([
      {'room_id': roomId, 'user_id': currentUserId, 'role': 'admin'},
      {'room_id': roomId, 'user_id': otherUserId, 'role': 'member'},
    ]);

    // 완성된 채팅방 조회
    final response = await supabaseClient
        .from('chat_rooms')
        .select('''
          *,
          chat_participants(
            *,
            users(id, display_name, photo_url)
          )
        ''')
        .eq('id', roomId)
        .single();

    return ChatRoomModel.fromJson(response);
  }

  @override
  Future<ChatRoomModel> createGroupChat({
    required String name,
    required String creatorId,
    required List<String> memberIds,
  }) async {
    // 그룹 채팅방 생성
    final roomResponse = await supabaseClient
        .from('chat_rooms')
        .insert({
          'type': 'group',
          'name': name,
          'created_by': creatorId,
        })
        .select()
        .single();

    final roomId = roomResponse['id'] as String;

    // 참여자 추가 (생성자는 admin)
    final participants = <Map<String, dynamic>>[
      {'room_id': roomId, 'user_id': creatorId, 'role': 'admin'},
    ];
    for (final memberId in memberIds) {
      if (memberId != creatorId) {
        participants.add({'room_id': roomId, 'user_id': memberId, 'role': 'member'});
      }
    }
    await supabaseClient.from('chat_participants').insert(participants);

    // 시스템 메시지
    await supabaseClient.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': creatorId,
      'content': '그룹 채팅이 시작되었습니다.',
      'type': 'system',
    });

    // 완성된 채팅방 조회
    final response = await supabaseClient
        .from('chat_rooms')
        .select('''
          *,
          chat_participants(
            *,
            users(id, display_name, photo_url)
          )
        ''')
        .eq('id', roomId)
        .single();

    return ChatRoomModel.fromJson(response);
  }

  @override
  Future<void> updateLastRead({required String roomId, required String userId}) async {
    await supabaseClient
        .from('chat_participants')
        .update({'last_read_at': DateTime.now().toIso8601String()})
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  @override
  Future<int> getTotalUnreadCount(String userId) async {
    final result = await supabaseClient
        .rpc('get_total_unread_count', params: {'p_user_id': userId});
    return result as int? ?? 0;
  }

  @override
  Future<List<ChatParticipantModel>> searchUsers(String query) async {
    final currentUserId = supabaseClient.auth.currentUser?.id;

    final response = await supabaseClient
        .from('users')
        .select('id, display_name, photo_url')
        .or('display_name.ilike.%$query%,email.ilike.%$query%')
        .neq('id', currentUserId ?? '')
        .limit(20);

    return (response as List)
        .map((json) => ChatParticipantModel.fromUserJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> leaveChatRoom({required String roomId, required String userId}) async {
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
        .map((id) => {'room_id': roomId, 'user_id': id, 'role': 'member'})
        .toList();
    await supabaseClient.from('chat_participants').upsert(participants);
  }
}
