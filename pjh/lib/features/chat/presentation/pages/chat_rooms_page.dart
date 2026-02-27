import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
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
                    onTap: () => context.push('/chat/${room.id}'),
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
