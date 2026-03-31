import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/chat_message_model.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_participant.dart';
import '../bloc/chat_detail/chat_detail_bloc.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';

class ChatDetailPage extends StatefulWidget {
  final String roomId;
  final String? roomName;

  const ChatDetailPage({
    super.key,
    required this.roomId,
    this.roomName,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _messageChannel;

  List<ChatParticipant> _participants = [];

  String get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) return authState.user.id;
    return '';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // 메시지 로드
        context.read<ChatDetailBloc>().add(
              ChatDetailLoadRequested(roomId: widget.roomId),
            );
        // 읽음 처리
        context.read<ChatDetailBloc>().add(
              ChatDetailMarkAsReadRequested(
                roomId: widget.roomId,
                userId: _currentUserId,
              ),
            );
        // 참여자 로드
        _loadParticipants();
        // 실시간 구독
        _subscribeToMessages();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _unsubscribeFromMessages();
    super.dispose();
  }

  Future<void> _loadParticipants() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('chat_participants').select('''
            *,
            users(id, display_name, photo_url)
          ''').eq('room_id', widget.roomId).eq('is_active', true);

      if (mounted) {
        setState(() {
          _participants = (response as List).map((json) {
            final map = json as Map<String, dynamic>;
            final userData = map['users'] as Map<String, dynamic>?;
            return ChatParticipant(
              id: map['id'] as String,
              roomId: map['room_id'] as String,
              userId: map['user_id'] as String,
              displayName: userData?['display_name'] as String?,
              photoUrl: userData?['photo_url'] as String?,
              role: (map['role'] as String?) == 'admin'
                  ? ChatRole.admin
                  : ChatRole.member,
              joinedAt: DateTime.parse(map['joined_at'] as String),
              lastReadAt: DateTime.parse(map['last_read_at'] as String),
              isActive: map['is_active'] as bool? ?? true,
            );
          }).toList();
        });
      }
    } catch (e) {
      log('Failed to load participants: $e', name: 'ChatDetail');
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      context.read<ChatDetailBloc>().add(
            ChatDetailLoadMoreRequested(roomId: widget.roomId),
          );
    }
  }

  void _subscribeToMessages() {
    final supabase = Supabase.instance.client;
    _messageChannel = supabase.channel('chat_messages:${widget.roomId}');

    _messageChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: widget.roomId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            // 본인이 보낸 메시지는 이미 UI에 반영됨 - 중복 방지는 BLoC에서 처리
            try {
              final messageModel = ChatMessageModel.fromJson(newRecord);
              context.read<ChatDetailBloc>().add(
                    ChatDetailNewMessageReceived(
                        message: messageModel.toEntity()),
                  );
              // 읽음 처리
              context.read<ChatDetailBloc>().add(
                    ChatDetailMarkAsReadRequested(
                      roomId: widget.roomId,
                      userId: _currentUserId,
                    ),
                  );
              // 참여자 다시 로드 (상대방 읽음 상태 갱신)
              _loadParticipants();
              // 새 메시지 수신 시 맨 아래로 스크롤
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });
            } catch (e) {
              log('Failed to parse realtime message: $e', name: 'ChatDetail');
            }
          },
        )
        .subscribe();
  }

  void _unsubscribeFromMessages() {
    if (_messageChannel != null) {
      Supabase.instance.client.removeChannel(_messageChannel!);
      _messageChannel = null;
    }
  }

  /// 메시지별 안 읽은 참여자 수 계산 (1:1, 그룹 모두 동일)
  int _getUnreadCount(ChatMessage message) {
    if (_participants.isEmpty) return 0;

    int unreadCount = 0;
    for (final participant in _participants) {
      if (participant.userId == _currentUserId) continue;
      if (participant.lastReadAt.isBefore(message.createdAt)) {
        unreadCount++;
      }
    }
    return unreadCount;
  }

  Future<void> _sendMultipleImages(List<File> images) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = _currentUserId;
      final List<String> uploadedUrls = [];

      for (int i = 0; i < images.length; i++) {
        final fileExt = images[i].path.split('.').last;
        final fileName =
            'chat/$userId/${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';
        await supabase.storage.from('images').upload(fileName, images[i]);
        final url = supabase.storage.from('images').getPublicUrl(fileName);
        uploadedUrls.add(url);
      }

      final response = await supabase.from('chat_messages').insert({
        'room_id': widget.roomId,
        'sender_id': userId,
        'type': 'image',
        'image_url': uploadedUrls.first,
        'image_urls': uploadedUrls,
        'content': '사진 ${uploadedUrls.length}장',
      }).select('''
            *,
            users:sender_id(id, display_name, photo_url)
          ''').single();

      if (mounted) {
        final messageModel = ChatMessageModel.fromJson(response);
        context.read<ChatDetailBloc>().add(
              ChatDetailNewMessageReceived(message: messageModel.toEntity()),
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 전송 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/chat');
            }
          },
        ),
        title: Text(
          widget.roomName ?? '채팅',
          style: TextStyle(fontSize: 16.sp),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(
              '/chat/${widget.roomId}/settings?name=${Uri.encodeComponent(widget.roomName ?? '')}',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatDetailBloc, ChatDetailState>(
              builder: (context, state) {
                if (state is ChatDetailInitial || state is ChatDetailLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ChatDetailError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48.w, color: Colors.grey),
                        SizedBox(height: 12.h),
                        Text(state.message,
                            style:
                                TextStyle(fontSize: 14.sp, color: Colors.grey)),
                        SizedBox(height: 12.h),
                        ElevatedButton(
                          onPressed: () {
                            context.read<ChatDetailBloc>().add(
                                  ChatDetailLoadRequested(
                                      roomId: widget.roomId),
                                );
                          },
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  );
                }
                if (state is ChatDetailLoaded) {
                  return _buildMessageList(state);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          BlocBuilder<ChatDetailBloc, ChatDetailState>(
            builder: (context, state) {
              final isSending = state is ChatDetailLoaded && state.isSending;
              return ChatInputBar(
                isSending: isSending,
                onSendText: (text) {
                  context.read<ChatDetailBloc>().add(
                        ChatDetailSendTextRequested(
                          roomId: widget.roomId,
                          senderId: _currentUserId,
                          content: text,
                        ),
                      );
                },
                onSendImage: (File imageFile) {
                  context.read<ChatDetailBloc>().add(
                        ChatDetailSendImageRequested(
                          roomId: widget.roomId,
                          senderId: _currentUserId,
                          imageFile: imageFile,
                        ),
                      );
                },
                onSendMultipleImages: (List<File> images) {
                  _sendMultipleImages(images);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatDetailLoaded state) {
    if (state.messages.isEmpty) {
      return Center(
        child: Text(
          '첫 메시지를 보내보세요!',
          style: TextStyle(fontSize: 14.sp, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      itemCount: state.messages.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (state.isLoadingMore && index == state.messages.length) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: const CircularProgressIndicator(),
            ),
          );
        }

        final message = state.messages[index];
        final isMine = message.isMine(_currentUserId);

        // 이전 메시지(index+1)와 발신자가 다르면 발신자 정보 표시
        bool showSenderInfo = true;
        if (index + 1 < state.messages.length) {
          final prevMessage = state.messages[index + 1];
          if (prevMessage.senderId == message.senderId &&
              prevMessage.type != ChatMessageType.system) {
            showSenderInfo = false;
          }
        }

        // 날짜 구분선
        Widget? dateSeparator;
        if (index == state.messages.length - 1) {
          dateSeparator = _buildDateSeparator(message.createdAt);
        } else {
          final nextMessage = state.messages[index + 1];
          if (!_isSameDay(message.createdAt, nextMessage.createdAt)) {
            dateSeparator = _buildDateSeparator(message.createdAt);
          }
        }

        // 읽음 표시 계산 (1:1, 그룹 모두 안 읽은 수로 통일)
        final unreadCount = _getUnreadCount(message);

        return Column(
          children: [
            if (dateSeparator != null) dateSeparator,
            ChatBubble(
              message: message,
              isMine: isMine,
              showSenderInfo: showSenderInfo,
              unreadCount: unreadCount,
              showReadLabel: false,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    String text;

    if (_isSameDay(date, now)) {
      text = '오늘';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      text = '어제';
    } else if (date.year == now.year) {
      text = '${date.month}월 ${date.day}일';
    } else {
      text = '${date.year}년 ${date.month}월 ${date.day}일';
    }

    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
