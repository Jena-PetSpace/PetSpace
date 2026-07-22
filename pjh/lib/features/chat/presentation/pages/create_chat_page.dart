import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../../../shared/widgets/petspace_state_view.dart';
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
  bool _isCreatingChat = false;
  String? _searchError;
  String? _followingError;
  Timer? _searchDebounce;
  int _searchGeneration = 0;

  Color get _mutedColor => Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : AppTheme.secondaryTextColor;

  Color get _avatarSurface => Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.surfaceContainerHighest
      : AppTheme.neutral200;

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
    _searchDebounce?.cancel();
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowingList() async {
    final currentUserId = _currentUserId;
    if (currentUserId.isEmpty) {
      setState(() {
        _isLoadingFollowing = false;
        _followingError = '로그인 정보를 확인할 수 없습니다.';
      });
      return;
    }

    setState(() {
      _isLoadingFollowing = true;
      _followingError = null;
    });

    final result = await sl<SocialRepository>().getFollowing(currentUserId);
    if (!mounted) return;

    result.fold(
      (_) => setState(() {
        _isLoadingFollowing = false;
        _followingError = '팔로잉 목록을 불러오지 못했습니다.';
      }),
      (follows) {
        setState(() {
          _followingList = follows
              .map(
                (f) => ChatParticipant(
                  id: '',
                  roomId: '',
                  userId: f.followingId,
                  displayName: f.followingName,
                  photoUrl: f.followingProfileImage,
                  joinedAt: DateTime.now(),
                  lastReadAt: DateTime.now(),
                ),
              )
              .toList();
          _isLoadingFollowing = false;
          _followingError = null;
        });
      },
    );
  }

  void _scheduleSearch(String query) {
    if (_isCreatingChat) return;
    _searchDebounce?.cancel();
    final normalized = query.trim();
    final generation = ++_searchGeneration;
    if (normalized.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _searchUsers(normalized, generation),
    );
  }

  Future<void> _searchUsers(String query, int generation) async {
    final result = await _searchUsersForChat(StringParams(value: query));
    if (!mounted ||
        generation != _searchGeneration ||
        query != _searchController.text.trim()) {
      return;
    }
    result.fold(
      (_) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _searchError = '사용자를 검색하지 못했습니다.';
        });
      },
      (users) {
        setState(() {
          _searchResults =
              users.where((u) => u.userId != _currentUserId).toList();
          _isSearching = false;
          _searchError = null;
        });
      },
    );
  }

  void _toggleUserSelection(ChatParticipant user) {
    if (_isCreatingChat) return;
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
    if (_selectedUsers.isEmpty || _isCreatingChat) return;

    final chatRoomsBloc = context.read<ChatRoomsBloc>();
    setState(() => _isCreatingChat = true);

    if (_selectedUsers.length == 1 && !_isGroupMode) {
      chatRoomsBloc.add(
        ChatRoomsCreateDirectRequested(
          currentUserId: _currentUserId,
          otherUserId: _selectedUsers.first.userId,
        ),
      );
    } else {
      final groupName = _groupNameController.text.trim().isEmpty
          ? _selectedUsers.map((u) => u.displayName ?? '').join(', ')
          : _groupNameController.text.trim();

      chatRoomsBloc.add(
        ChatRoomsCreateGroupRequested(
          name: groupName,
          creatorId: _currentUserId,
          memberIds: _selectedUsers.map((u) => u.userId).toList(),
        ),
      );
    }
  }

  bool get _isShowingSearchResults =>
      _searchController.text.isNotEmpty || _isSearching;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isCreatingChat,
      child: PetSpacePageScaffold(
        title: '새 채팅',
        body: BlocListener<ChatRoomsBloc, ChatRoomsState>(
          listener: (context, state) {
            if (state is ChatRoomCreated) {
              if (mounted) setState(() => _isCreatingChat = false);
              context.go('/chat/${state.room.id}');
            }
            if (state is ChatRoomCreateFailure) {
              if (mounted) setState(() => _isCreatingChat = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('채팅방을 만들지 못했습니다. 다시 시도해주세요.'),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          },
          child: SafeArea(
            bottom: false,
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
        ),
        bottomNavigationBar:
            _selectedUsers.isEmpty ? null : _buildPrimaryAction(),
      ),
    );
  }

  Widget _buildSelectedChips() {
    return Container(
      key: const Key('chat_selected_summary'),
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedUsers.length}명 선택',
            style: TextStyle(
              fontSize: AppTheme.fontCaption.sp,
              fontWeight: FontWeight.w700,
              color: _mutedColor,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            _selectedUsers.length == 1 ? '1:1 채팅을 시작합니다' : '그룹 채팅을 만듭니다',
            key: const Key('chat_selected_mode'),
            style: TextStyle(
              fontSize: AppTheme.fontMicro.sp,
              color: _mutedColor,
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: _selectedUsers.map((user) {
              return Chip(
                avatar: CircleAvatar(
                  radius: 12.r,
                  backgroundColor: AppTheme.actionContainer,
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Icon(
                          Icons.person,
                          size: 12.w,
                          color: AppTheme.actionBase,
                        )
                      : null,
                ),
                label: Text(
                  user.displayName ?? '사용자',
                  style: TextStyle(fontSize: AppTheme.fontCaption.sp),
                ),
                deleteIcon: Icon(Icons.close, size: 16.w),
                onDeleted:
                    _isCreatingChat ? null : () => _toggleUserSelection(user),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupNameInput() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: TextField(
        key: const Key('chat_group_name_field'),
        controller: _groupNameController,
        enabled: !_isCreatingChat,
        decoration: InputDecoration(
          labelText: '그룹 이름',
          helperText: '선택 · 비워두면 참여자 이름으로 만들어요.',
          helperStyle: TextStyle(
            fontSize: AppTheme.fontCaption.sp,
            color: _mutedColor,
          ),
          prefixIcon: const Icon(Icons.group),
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: TextField(
        key: const Key('chat_user_search_field'),
        controller: _searchController,
        enabled: !_isCreatingChat,
        onChanged: _scheduleSearch,
        decoration: InputDecoration(
          hintText: '닉네임 또는 반려동물 이름으로 검색',
          hintStyle: TextStyle(
            fontSize: AppTheme.fontCaption.sp,
            color: _mutedColor,
          ),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _isCreatingChat
                      ? null
                      : () {
                          _searchController.clear();
                          _searchDebounce?.cancel();
                          _searchGeneration++;
                          setState(() {
                            _searchResults = [];
                            _isSearching = false;
                            _searchError = null;
                          });
                        },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFollowingList() {
    if (_isLoadingFollowing) {
      return const PetSpaceStateView.loading();
    }

    if (_followingError != null) {
      return PetSpaceStateView.error(
        key: const Key('chat_following_error'),
        icon: Icons.cloud_off_outlined,
        title: '팔로잉 목록을 불러오지 못했어요',
        message: '잠시 후 다시 시도해주세요.',
        actionLabel: '다시 시도',
        onAction: _loadFollowingList,
      );
    }

    if (_followingList.isEmpty) {
      return const PetSpaceStateView.empty(
        key: Key('chat_following_empty'),
        icon: Icons.people_outline_rounded,
        title: '팔로잉한 사용자가 없어요',
        message: '위 검색창에서 닉네임이나 반려동물 이름을 찾아보세요.',
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
              color: _mutedColor,
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
      return const PetSpaceStateView.loading();
    }

    if (_searchError != null) {
      return PetSpaceStateView.error(
        key: const Key('chat_user_search_error'),
        icon: Icons.cloud_off_outlined,
        title: '검색 결과를 불러오지 못했어요',
        message: '인터넷 연결을 확인하고 다시 시도해주세요.',
        actionLabel: '다시 시도',
        onAction: () {
          final query = _searchController.text.trim();
          if (query.isNotEmpty) _scheduleSearch(query);
        },
      );
    }

    if (_searchController.text.isNotEmpty && _searchResults.isEmpty) {
      return const PetSpaceStateView.empty(
        key: Key('chat_user_search_empty'),
        icon: Icons.search_off_rounded,
        title: '검색 결과가 없어요',
        message: '다른 이름으로 검색해보세요.',
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
      key: Key('chat_user_${user.userId}'),
      enabled: !_isCreatingChat,
      leading: CircleAvatar(
        radius: 20.r,
        backgroundColor: _avatarSurface,
        backgroundImage:
            user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
        child: user.photoUrl == null
            ? Icon(Icons.person, size: 20.w, color: _mutedColor)
            : null,
      ),
      title: Text(
        user.displayName ?? '알 수 없는 사용자',
        style: TextStyle(fontSize: 15.sp),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : Icon(Icons.circle_outlined, color: _mutedColor),
      onTap: () => _toggleUserSelection(user),
    );
  }

  Widget _buildPrimaryAction() {
    final selectedName = _selectedUsers.first.displayName?.trim();
    final label = _selectedUsers.length >= 2
        ? '그룹 만들기'
        : '${selectedName?.isNotEmpty == true ? selectedName : '선택한 사용자'}와 채팅 시작';
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.outlineVariant
                  : AppTheme.border,
            ),
          ),
        ),
        child: ElevatedButton(
          key: const Key('chat_create_primary_action'),
          onPressed: _isCreatingChat ? null : _createChat,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppTheme.actionBase,
            foregroundColor: Colors.white,
          ),
          child: _isCreatingChat
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: AppTheme.fontBody.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
