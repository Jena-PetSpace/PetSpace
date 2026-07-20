import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../../../shared/widgets/petspace_state_view.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PetSpacePageScaffold(
      title: '채팅',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          tooltip: '새 채팅',
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          onPressed: () => context.push('/chat/new'),
        ),
      ],
      body: BlocConsumer<ChatRoomsBloc, ChatRoomsState>(
        listener: (context, state) {
          if (state is ChatRoomCreated) {
            context.push('/chat/${state.room.id}');
            _refreshRooms();
          }
        },
        builder: (context, state) {
          if (state is ChatRoomsInitial || state is ChatRoomsLoading) {
            return const PetSpaceStateView.loading(
              key: Key('chat_rooms_loading'),
            );
          }

          if (state is ChatRoomsLoaded) {
            return _buildLoadedState(state);
          }

          if (state is ChatRoomsError) {
            return PetSpaceStateView.error(
              key: const Key('chat_rooms_initial_error'),
              icon: Icons.cloud_off_outlined,
              title: '채팅을 불러오지 못했어요',
              message: '인터넷 연결을 확인하고 다시 시도해주세요.',
              actionLabel: '다시 시도',
              onAction: _loadRooms,
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _loadRooms() {
    context.read<ChatRoomsBloc>().add(
          ChatRoomsLoadRequested(userId: _currentUserId),
        );
  }

  Future<void> _refreshRooms() {
    context.read<ChatRoomsBloc>().add(
          ChatRoomsRefreshRequested(userId: _currentUserId),
        );
    // 진행·실패 표시는 ChatRoomsLoaded.isRefreshing/refreshErrorMessage가
    // 화면 안에서 담당한다. RefreshIndicator 콜백은 이벤트 전달까지만 보장한다.
    return Future<void>.value();
  }

  Widget _buildLoadedState(ChatRoomsLoaded state) {
    final normalized = _query.trim().toLowerCase();
    final filteredRooms = normalized.isEmpty
        ? state.rooms
        : state.rooms.where((room) {
            final name = room.displayName(_currentUserId).toLowerCase();
            final preview = (room.lastMessage ?? '').toLowerCase();
            return name.contains(normalized) || preview.contains(normalized);
          }).toList(growable: false);

    return Column(
      children: [
        if (state.isRefreshing)
          const LinearProgressIndicator(
            key: Key('chat_rooms_refreshing'),
            minHeight: 2,
            color: AppTheme.actionBase,
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
          child: TextField(
            key: const Key('chat_rooms_search_field'),
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '채팅방 검색',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '검색어 지우기',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return RefreshIndicator(
                onRefresh: _refreshRooms,
                color: AppTheme.actionBase,
                child: ListView(
                  key: const Key('chat_rooms_list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
                  children: [
                    if (state.refreshErrorMessage != null) ...[
                      _buildRefreshErrorCard(),
                      SizedBox(height: 16.h),
                    ],
                    if (state.rooms.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            normalized.isEmpty ? '최근 대화' : '검색 결과',
                            style: TextStyle(
                              fontSize: AppTheme.fontCaption.sp,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                          Text(
                            '${filteredRooms.length}개',
                            style: TextStyle(
                              fontSize: AppTheme.fontCaption.sp,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                    ],
                    if (filteredRooms.isEmpty)
                      SizedBox(
                        height: math.max(280.h, constraints.maxHeight - 120.h),
                        child: normalized.isEmpty
                            ? PetSpaceStateView.empty(
                                key: const Key('chat_rooms_empty'),
                                icon: Icons.chat_bubble_outline_rounded,
                                title: '아직 채팅이 없어요',
                                message: '새 채팅을 시작해보세요.',
                                actionLabel: '새 채팅',
                                onAction: () => context.push('/chat/new'),
                              )
                            : const PetSpaceStateView.empty(
                                key: Key('chat_rooms_search_empty'),
                                icon: Icons.search_off_rounded,
                                title: '검색 결과가 없어요',
                                message: '다른 채팅방 이름이나 메시지로 검색해보세요.',
                              ),
                      )
                    else
                      for (int index = 0;
                          index < filteredRooms.length;
                          index++) ...[
                        ChatRoomTile(
                          room: filteredRooms[index],
                          currentUserId: _currentUserId,
                          onTap: () async {
                            await context
                                .push('/chat/${filteredRooms[index].id}');
                            if (!context.mounted) return;
                            await _refreshRooms();
                          },
                          onLongPress: () => _showRoomOptions(
                            context,
                            filteredRooms[index],
                          ),
                          onMorePressed: () => _showRoomOptions(
                            context,
                            filteredRooms[index],
                          ),
                        ),
                        if (index < filteredRooms.length - 1)
                          SizedBox(height: 10.h),
                      ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRefreshErrorCard() {
    return Container(
      key: const Key('chat_rooms_refresh_error'),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sync_problem_rounded, color: AppTheme.actionBase),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '새 대화를 확인하지 못했어요',
                  style: TextStyle(
                    fontSize: AppTheme.fontBody.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '기존 대화는 그대로 유지됩니다.',
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
                SizedBox(height: 8.h),
                OutlinedButton(
                  key: const Key('chat_rooms_refresh_retry'),
                  onPressed: _refreshRooms,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
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
                if (!context.mounted) return;
                await _refreshRooms();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.exit_to_app, color: AppTheme.errorColor),
              title: Text(
                '채팅방 나가기',
                style: TextStyle(fontSize: 14.sp, color: AppTheme.errorColor),
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
                    const SnackBar(
                      content: Text('채팅방에서 나가지 못했습니다. 다시 시도해주세요.'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                },
                (_) {
                  _refreshRooms();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('채팅방을 나갔습니다'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              );
            },
            child: const Text(
              '나가기',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}
