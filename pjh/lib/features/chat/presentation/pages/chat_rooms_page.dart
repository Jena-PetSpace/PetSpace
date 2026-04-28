import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/chat_room.dart';
import '../../domain/repositories/chat_repository.dart';
import '../bloc/chat_rooms/chat_rooms_bloc.dart';
import '../widgets/chat_room_tile.dart';

class ChatRoomsPage extends StatefulWidget {
  const ChatRoomsPage({super.key});

  @override
  State<ChatRoomsPage> createState() => _ChatRoomsPageState();
}

class _ChatRoomsPageState extends State<ChatRoomsPage> {
  String get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) return authState.user.id;
    return '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatRoomsBloc>().add(
              ChatRoomsLoadRequested(userId: _currentUserId),
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('채팅', style: TextStyle(fontSize: 18.sp)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square),
            onPressed: () => context.push('/chat/new'),
          ),
        ],
      ),
      body: BlocConsumer<ChatRoomsBloc, ChatRoomsState>(
        listener: (context, state) {
          if (state is ChatRoomCreated) {
            context.push('/chat/${state.room.id}');
            // 목록 새로고침
            context.read<ChatRoomsBloc>().add(
                  ChatRoomsLoadRequested(userId: _currentUserId),
                );
          }
          if (state is ChatRoomsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ChatRoomsInitial || state is ChatRoomsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ChatRoomsLoaded) {
            if (state.rooms.isEmpty) {
              return _buildEmptyState();
            }
            return RefreshIndicator(
              onRefresh: () async {
                context.read<ChatRoomsBloc>().add(
                      ChatRoomsRefreshRequested(userId: _currentUserId),
                    );
              },
              child: ListView.separated(
                itemCount: state.rooms.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 72.w,
                  color: Colors.grey[200],
                ),
                itemBuilder: (context, index) {
                  final room = state.rooms[index];
                  return ChatRoomTile(
                    room: room,
                    currentUserId: _currentUserId,
                    onTap: () async {
                      await context.push('/chat/${room.id}');
                      // 채팅방에서 돌아오면 목록 새로고침
                      if (!context.mounted) return;
                      context.read<ChatRoomsBloc>().add(
                            ChatRoomsLoadRequested(userId: _currentUserId),
                          );
                    },
                    onLongPress: () => _showRoomOptions(context, room),
                  );
                },
              ),
            );
          }

          if (state is ChatRoomsError) {
            return _buildErrorState(state.message);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64.w, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text(
            '아직 채팅이 없습니다',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Text(
            '새 채팅을 시작해보세요!',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () => context.push('/chat/new'),
            icon: const Icon(Icons.add),
            label: Text('새 채팅', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  void _showRoomOptions(BuildContext context, ChatRoom room) {
    final roomName = room.displayName(_currentUserId);
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 8.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Text(
                roomName,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text('채팅방 설정', style: TextStyle(fontSize: 14.sp)),
              onTap: () async {
                Navigator.pop(ctx);
                await context.push(
                  '/chat/${room.id}/settings?name=${Uri.encodeComponent(roomName)}',
                );
                // 설정에서 돌아오면 채팅 목록 새로고침
                if (!context.mounted) return;
                context.read<ChatRoomsBloc>().add(
                      ChatRoomsLoadRequested(userId: _currentUserId),
                    );
              },
            ),
            ListTile(
              leading: Icon(Icons.exit_to_app, color: Colors.red[400]),
              title: Text(
                '채팅방 나가기',
                style: TextStyle(fontSize: 14.sp, color: Colors.red[400]),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmLeaveRoom(context, room);
              },
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  void _confirmLeaveRoom(BuildContext context, ChatRoom room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('채팅방 나가기'),
        content: const Text('정말 이 채팅방을 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // 내 이름: AuthBloc 에서 바로 획득 (추가 네트워크 호출 제거)
              final authState = context.read<AuthBloc>().state;
              final myName = authState is AuthAuthenticated
                  ? authState.user.displayName
                  : '사용자';

              final result = await sl<ChatRepository>().leaveChatRoom(
                roomId: room.id,
                userId: _currentUserId,
                leaverName: myName,
              );
              if (!context.mounted) return;
              result.fold(
                (failure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('오류: ${failure.message}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                (_) {
                  context.read<ChatRoomsBloc>().add(
                        ChatRoomsLoadRequested(userId: _currentUserId),
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('채팅방을 나갔습니다'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              );
            },
            child: Text(
              '나가기',
              style: TextStyle(color: Colors.red[400]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.w, color: Colors.grey),
          SizedBox(height: 16.h),
          Text(message, style: TextStyle(fontSize: 14.sp, color: Colors.grey)),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              context.read<ChatRoomsBloc>().add(
                    ChatRoomsLoadRequested(userId: _currentUserId),
                  );
            },
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
