import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/models/chat_message_model.dart';
import '../../domain/entities/chat_message.dart';
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
                ChatDetailNewMessageReceived(message: messageModel.toEntity()),
              );
              // 읽음 처리
              context.read<ChatDetailBloc>().add(
                ChatDetailMarkAsReadRequested(
                  roomId: widget.roomId,
                  userId: _currentUserId,
                ),
              );
            } catch (e) {
              print('[ChatDetail] Failed to parse realtime message: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.roomName ?? '채팅',
          style: TextStyle(fontSize: 16.sp),
        ),
        centerTitle: true,
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
                        Icon(Icons.error_outline, size: 48.w, color: Colors.grey),
                        SizedBox(height: 12.h),
                        Text(state.message, style: TextStyle(fontSize: 14.sp, color: Colors.grey)),
                        SizedBox(height: 12.h),
                        ElevatedButton(
                          onPressed: () {
                            context.read<ChatDetailBloc>().add(
                              ChatDetailLoadRequested(roomId: widget.roomId),
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

        return Column(
          children: [
            if (dateSeparator != null) dateSeparator,
            ChatBubble(
              message: message,
              isMine: isMine,
              showSenderInfo: showSenderInfo,
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
