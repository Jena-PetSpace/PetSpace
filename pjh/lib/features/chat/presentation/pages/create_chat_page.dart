import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../social/domain/repositories/social_repository.dart';
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
  List<ChatParticipant> _followingList = [];
  final List<ChatParticipant> _selectedUsers = [];
  bool _isSearching = false;
  bool _isGroupMode = false;
  bool _isLoadingFollowing = true;

  String get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) return authState.user.id;
    return '';
  }

  @override
  void initState() {
    super.initState();
    _loadFollowingList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowingList() async {
    final currentUserId = _currentUserId;
    if (currentUserId.isEmpty) return;

    final result = await sl<SocialRepository>().getFollowing(currentUserId);
    if (!mounted) return;

    result.fold(
      (_) => setState(() => _isLoadingFollowing = false),
      (follows) {
        setState(() {
          _followingList = follows
              .map((f) => ChatParticipant(
                    id: '',
                    roomId: '',
                    userId: f.followingId,
                    displayName: f.followingName,
                    photoUrl: f.followingProfileImage,
                    joinedAt: DateTime.now(),
                    lastReadAt: DateTime.now(),
                  ))
              .toList();
          _isLoadingFollowing = false;
        });
      },
    );
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
            SnackBar(
                content: Text(failure.message), backgroundColor: Colors.red),
          );
          setState(() => _isSearching = false);
        }
      },
      (users) {
        if (mounted) {
          setState(() {
            _searchResults =
                users.where((u) => u.userId != _currentUserId).toList();
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
      _isGroupMode = _selectedUsers.length >= 2;
    });
  }

  void _createChat() {
    if (_selectedUsers.isEmpty) return;

    final chatRoomsBloc = context.read<ChatRoomsBloc>();

    if (_selectedUsers.length == 1 && !_isGroupMode) {
      chatRoomsBloc.add(ChatRoomsCreateDirectRequested(
        currentUserId: _currentUserId,
        otherUserId: _selectedUsers.first.userId,
      ));
    } else {
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

  bool get _isShowingSearchResults =>
      _searchController.text.isNotEmpty || _isSearching;

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
            context.go('/chat/${state.room.id}');
          }
          if (state is ChatRoomsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        child: Column(
          children: [
            if (_selectedUsers.isNotEmpty) _buildSelectedChips(),
            if (_isGroupMode) _buildGroupNameInput(),
            _buildSearchInput(),
            Expanded(
              child: _isShowingSearchResults
                  ? _buildSearchResults()
                  : _buildFollowingList(),
            ),
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
              backgroundImage:
                  user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
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
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
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
          hintText: '닉네임 또는 반려동물 이름으로 검색',
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
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        ),
      ),
    );
  }

  Widget _buildFollowingList() {
    if (_isLoadingFollowing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_followingList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 48.w, color: Colors.grey[300]),
            SizedBox(height: 12.h),
            Text(
              '팔로잉한 사용자가 없습니다',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey),
            ),
            SizedBox(height: 4.h),
            Text(
              '닉네임 또는 반려동물 이름으로 검색하세요',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            '팔로잉',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: ListView.builder(
            itemCount: _followingList.length,
            itemBuilder: (context, index) {
              final user = _followingList[index];
              return _buildUserTile(user);
            },
          ),
        ),
      ],
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

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(ChatParticipant user) {
    final isSelected = _selectedUsers.any((u) => u.userId == user.userId);

    return ListTile(
      leading: CircleAvatar(
        radius: 20.r,
        backgroundColor: Colors.grey[200],
        backgroundImage:
            user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
        child: user.photoUrl == null
            ? Icon(Icons.person, size: 20.w, color: Colors.grey[500])
            : null,
      ),
      title: Text(
        user.displayName ?? '알 수 없는 사용자',
        style: TextStyle(fontSize: 15.sp),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle,
              color: Theme.of(context).colorScheme.primary)
          : Icon(Icons.circle_outlined, color: Colors.grey[400]),
      onTap: () => _toggleUserSelection(user),
    );
  }
}
