import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/chat_participant.dart';
import '../../domain/usecases/search_users_for_chat.dart';
import '../../../../core/usecases/usecase.dart';
import '../bloc/chat_rooms/chat_rooms_bloc.dart';

class CreateChatPage extends StatefulWidget {
  const CreateChatPage({super.key});

  @override
  State<CreateChatPage> createState() => _CreateChatPageState();
}

class _CreateChatPageState extends State<CreateChatPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final SearchUsersForChat _searchUsersForChat = sl<SearchUsersForChat>();

  List<ChatParticipant> _searchResults = [];
  final List<ChatParticipant> _selectedUsers = [];
  bool _isSearching = false;
  bool _isGroupMode = false;

  String get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) return authState.user.id;
    return '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final result = await _searchUsersForChat(StringParams(value: query.trim()));
    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message), backgroundColor: Colors.red),
          );
          setState(() => _isSearching = false);
        }
      },
      (users) {
        if (mounted) {
          setState(() {
            _searchResults = users.where((u) => u.userId != _currentUserId).toList();
            _isSearching = false;
          });
        }
      },
    );
  }

  void _toggleUserSelection(ChatParticipant user) {
    setState(() {
      final index = _selectedUsers.indexWhere((u) => u.userId == user.userId);
      if (index >= 0) {
        _selectedUsers.removeAt(index);
      } else {
        _selectedUsers.add(user);
      }
      // 2명 이상 선택하면 그룹 모드
      _isGroupMode = _selectedUsers.length >= 2;
    });
  }

  void _createChat() {
    if (_selectedUsers.isEmpty) return;

    final chatRoomsBloc = context.read<ChatRoomsBloc>();

    if (_selectedUsers.length == 1 && !_isGroupMode) {
      // 1:1 채팅
      chatRoomsBloc.add(ChatRoomsCreateDirectRequested(
        currentUserId: _currentUserId,
        otherUserId: _selectedUsers.first.userId,
      ));
    } else {
      // 그룹 채팅
      final groupName = _groupNameController.text.trim().isEmpty
          ? _selectedUsers.map((u) => u.displayName ?? '').join(', ')
          : _groupNameController.text.trim();

      chatRoomsBloc.add(ChatRoomsCreateGroupRequested(
        name: groupName,
        creatorId: _currentUserId,
        memberIds: _selectedUsers.map((u) => u.userId).toList(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('새 채팅', style: TextStyle(fontSize: 18.sp)),
        centerTitle: true,
        actions: [
          if (_selectedUsers.isNotEmpty)
            TextButton(
              onPressed: _createChat,
              child: Text(
                _isGroupMode ? '그룹 생성' : '확인',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: BlocListener<ChatRoomsBloc, ChatRoomsState>(
        listener: (context, state) {
          if (state is ChatRoomCreated) {
            // 생성된 채팅방으로 이동 (이전 페이지 제거)
            context.go('/chat/${state.room.id}');
          }
          if (state is ChatRoomsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        child: Column(
          children: [
            // 선택된 사용자 칩
            if (_selectedUsers.isNotEmpty) _buildSelectedChips(),
            // 그룹 이름 입력 (그룹 모드일 때)
            if (_isGroupMode) _buildGroupNameInput(),
            // 검색 입력
            _buildSearchInput(),
            // 검색 결과
            Expanded(child: _buildSearchResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedChips() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 4.h,
        children: _selectedUsers.map((user) {
          return Chip(
            avatar: CircleAvatar(
              radius: 12.r,
              backgroundColor: Colors.grey[200],
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: user.photoUrl == null
                  ? Icon(Icons.person, size: 12.w, color: Colors.grey[500])
                  : null,
            ),
            label: Text(
              user.displayName ?? '',
              style: TextStyle(fontSize: 12.sp),
            ),
            deleteIcon: Icon(Icons.close, size: 16.w),
            onDeleted: () => _toggleUserSelection(user),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGroupNameInput() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: TextField(
        controller: _groupNameController,
        decoration: InputDecoration(
          hintText: '그룹 채팅방 이름 (선택)',
          hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey),
          prefixIcon: const Icon(Icons.group),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => _searchUsers(value),
        decoration: InputDecoration(
          hintText: '사용자 검색 (이름 또는 이메일)',
          hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                      _isSearching = false;
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.isNotEmpty && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48.w, color: Colors.grey[300]),
            SizedBox(height: 12.h),
            Text(
              '검색 결과가 없습니다',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          '사용자를 검색하세요',
          style: TextStyle(fontSize: 14.sp, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final isSelected = _selectedUsers.any((u) => u.userId == user.userId);

        return ListTile(
          leading: CircleAvatar(
            radius: 20.r,
            backgroundColor: Colors.grey[200],
            backgroundImage: user.photoUrl != null
                ? NetworkImage(user.photoUrl!)
                : null,
            child: user.photoUrl == null
                ? Icon(Icons.person, size: 20.w, color: Colors.grey[500])
                : null,
          ),
          title: Text(
            user.displayName ?? '알 수 없는 사용자',
            style: TextStyle(fontSize: 15.sp),
          ),
          trailing: isSelected
              ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
              : Icon(Icons.circle_outlined, color: Colors.grey[400]),
          onTap: () => _toggleUserSelection(user),
        );
      },
    );
  }
}
