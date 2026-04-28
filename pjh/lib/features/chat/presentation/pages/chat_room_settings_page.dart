import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/image_source_picker.dart';
import '../../domain/entities/chat_participant.dart';
import '../../../../config/injection_container.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/search_users_for_chat.dart';
import '../../../../core/usecases/usecase.dart';

class ChatRoomSettingsPage extends StatefulWidget {
  final String roomId;
  final String? roomName;

  const ChatRoomSettingsPage({
    super.key,
    required this.roomId,
    this.roomName,
  });

  @override
  State<ChatRoomSettingsPage> createState() => _ChatRoomSettingsPageState();
}

class _ChatRoomSettingsPageState extends State<ChatRoomSettingsPage> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  List<ChatParticipant> _participants = [];
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  String? _currentPhotoUrl;
  File? _pendingPhotoFile; // 저장 전 대기 중인 사진
  bool _hasNameChanged = false;
  bool _isSaving = false;

  String get _currentUserId => _supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.roomName ?? '';
    _nameController.addListener(_onNameChanged);
    _loadData();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final changed =
        _nameController.text.trim() != (widget.roomName ?? '').trim();
    if (changed != _hasNameChanged) {
      setState(() => _hasNameChanged = changed);
    }
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadParticipants(),
      _loadNotificationSetting(),
      _loadRoomInfo(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadRoomInfo() async {
    final result = await sl<ChatRepository>().getChatRoomInfo(widget.roomId);
    result.fold(
      (failure) => log('[ChatRoomSettings] 채팅방 정보 로드 실패: ${failure.message}',
          name: 'ChatRoomSettings'),
      (info) {
        if (info == null || !mounted) return;
        setState(() {
          _currentPhotoUrl = info['avatar_url'] as String?;
          if (_nameController.text.isEmpty && info['name'] != null) {
            _nameController.text = info['name'] as String;
          }
        });
      },
    );
  }

  Future<void> _loadParticipants() async {
    final result = await sl<ChatRepository>().getRoomParticipants(widget.roomId);
    result.fold(
      (failure) => log('[ChatRoomSettings] 참여자 로드 실패: ${failure.message}',
          name: 'ChatRoomSettings'),
      (participants) {
        if (!mounted) return;
        setState(() => _participants = participants);
      },
    );
  }

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled =
            prefs.getBool('chat_notification_${widget.roomId}') ?? true;
      });
    }
  }

  Future<void> _toggleNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chat_notification_${widget.roomId}', value);
    if (mounted) setState(() => _notificationsEnabled = value);
  }

  Future<void> _pickPhoto() async {
    final pickedFile = await ImageSourcePicker.pickSingle(
      context,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    // 저장 버튼 누를 때까지 대기 — 미리보기만 표시
    setState(() {
      _pendingPhotoFile = file;
    });
  }

  void _goBack({bool saved = false}) {
    if (Navigator.of(context).canPop()) {
      // pop하면서 저장 여부를 결과로 전달
      Navigator.of(context).pop(saved);
    } else {
      context.go('/chat');
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    final repo = sl<ChatRepository>();

    // 이름 저장
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      final nameResult = await repo.updateChatRoomName(
          roomId: widget.roomId, name: newName);
      final nameError = nameResult.fold((f) => f.message, (_) => null);
      if (nameError != null) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장에 실패했습니다: $nameError'),
                backgroundColor: Colors.red),
          );
        }
        return;
      }
    }

    // 사진 업로드 (대기 중인 파일이 있으면)
    if (_pendingPhotoFile != null) {
      final photoResult = await repo.uploadChatRoomPhoto(
        roomId: widget.roomId,
        userId: _currentUserId,
        file: _pendingPhotoFile!,
      );
      final photoError = photoResult.fold((f) => f.message, (_) => null);
      if (photoError != null) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장에 실패했습니다: $photoError'),
                backgroundColor: Colors.red),
          );
        }
        return;
      }
      _pendingPhotoFile = null;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('설정이 저장되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
      _goBack(saved: true);
    }
  }

  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('채팅방 나가기'),
        content: const Text('정말로 이 채팅방을 나가시겠습니까?\n나간 후에는 대화 내용을 볼 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('나가기'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 내 이름: 참여자 목록에서 찾기 (이미 로드됨)
    final me = _participants.firstWhere(
      (p) => p.userId == _currentUserId,
      orElse: () => ChatParticipant(
        id: '',
        roomId: widget.roomId,
        userId: _currentUserId,
        displayName: '사용자',
        photoUrl: null,
        role: ChatRole.member,
        joinedAt: DateTime.now(),
        lastReadAt: DateTime.now(),
        isActive: true,
      ),
    );

    final result = await sl<ChatRepository>().leaveChatRoom(
      roomId: widget.roomId,
      userId: _currentUserId,
      leaverName: me.displayName ?? '사용자',
    );
    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('채팅방 나가기에 실패했습니다: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      (_) {
        if (mounted) context.go('/chat');
      },
    );
  }

  Future<void> _showAddMembersSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) => _AddMembersSheet(
        roomId: widget.roomId,
        existingUserIds: _participants.map((p) => p.userId).toSet(),
        onMembersAdded: () {
          _loadParticipants();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('채팅방 설정', style: TextStyle(fontSize: 16.sp)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 24.h),
                  _buildPhotoSection(),
                  SizedBox(height: 16.h),
                  _buildNameSection(),
                  SizedBox(height: 24.h),
                  _buildParticipantsSection(),
                  SizedBox(height: 8.h),
                  _buildSettingsSection(),
                  SizedBox(height: 8.h),
                  _buildLeaveSection(),
                  SizedBox(height: 16.h),
                  _buildBottomButtons(),
                  SizedBox(height: 32.h),
                ],
              ),
            ),
    );
  }

  Widget _buildPhotoSection() {
    return GestureDetector(
      onTap: _isSaving ? null : _pickPhoto,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 48.r,
            backgroundColor: Colors.grey[200],
            backgroundImage: _pendingPhotoFile != null
                ? FileImage(_pendingPhotoFile!)
                : (_currentPhotoUrl != null
                    ? CachedNetworkImageProvider(_currentPhotoUrl!)
                    : null) as ImageProvider?,
            child: _pendingPhotoFile == null && _currentPhotoUrl == null
                ? Icon(Icons.group, size: 40.w, color: Colors.grey[500])
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                Icons.camera_alt,
                size: 16.w,
                color: Colors.white,
              ),
            ),
          ),
          if (_isSaving)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNameSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: TextField(
        controller: _nameController,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: '채팅방 이름',
          hintStyle: TextStyle(
            fontSize: 18.sp,
            color: AppTheme.hintColor,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: AppTheme.dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: AppTheme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide:
                const BorderSide(color: AppTheme.primaryColor, width: 1.5),
          ),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('저장', style: TextStyle(fontSize: 15.sp)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: OutlinedButton(
              onPressed: _goBack,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                '취소',
                style: TextStyle(fontSize: 15.sp, color: Colors.grey[700]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Text(
            '참여자 (${_participants.length}명)',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ),
        const Divider(height: 1, color: AppTheme.dividerColor),
        ..._participants.map((p) => _buildParticipantTile(p)),
        ListTile(
          leading: CircleAvatar(
            radius: 20.r,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: Icon(Icons.person_add,
                size: 20.w, color: AppTheme.primaryColor),
          ),
          title: Text(
            '멤버 초대',
            style: TextStyle(
              fontSize: 15.sp,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: _showAddMembersSheet,
        ),
        const Divider(height: 1, color: AppTheme.dividerColor),
      ],
    );
  }

  Widget _buildParticipantTile(ChatParticipant participant) {
    final isMe = participant.userId == _currentUserId;
    return ListTile(
      leading: CircleAvatar(
        radius: 20.r,
        backgroundColor: Colors.grey[200],
        backgroundImage: participant.photoUrl != null
            ? CachedNetworkImageProvider(participant.photoUrl!)
            : null,
        child: participant.photoUrl == null
            ? Icon(Icons.person, size: 20.w, color: Colors.grey[500])
            : null,
      ),
      title: Row(
        children: [
          Text(
            participant.displayName ?? '알 수 없는 사용자',
            style: TextStyle(fontSize: 15.sp),
          ),
          if (isMe) ...[
            SizedBox(width: 6.w),
            Text(
              '나',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ],
        ],
      ),
      trailing: null,
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Text(
            '설정',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ),
        const Divider(height: 1, color: AppTheme.dividerColor),
        SwitchListTile(
          title: Text('알림', style: TextStyle(fontSize: 15.sp)),
          subtitle: Text(
            _notificationsEnabled ? '알림을 받고 있습니다' : '알림이 꺼져 있습니다',
            style:
                TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor),
          ),
          secondary: Icon(
            _notificationsEnabled
                ? Icons.notifications_active
                : Icons.notifications_off_outlined,
            color: _notificationsEnabled
                ? AppTheme.primaryColor
                : AppTheme.disabledColor,
          ),
          value: _notificationsEnabled,
          activeTrackColor: AppTheme.primaryColor,
          onChanged: _toggleNotification,
        ),
        const Divider(height: 1, color: AppTheme.dividerColor),
      ],
    );
  }

  Widget _buildLeaveSection() {
    return Column(
      children: [
        const Divider(height: 1, color: AppTheme.dividerColor),
        ListTile(
          leading:
              Icon(Icons.exit_to_app, color: AppTheme.errorColor, size: 24.w),
          title: Text(
            '채팅방 나가기',
            style: TextStyle(
              fontSize: 15.sp,
              color: AppTheme.errorColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '채팅방에서 나갑니다',
            style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.errorColor.withValues(alpha: 0.7)),
          ),
          onTap: _leaveRoom,
        ),
        const Divider(height: 1, color: AppTheme.dividerColor),
      ],
    );
  }
}

// --- Add Members Bottom Sheet ---

class _AddMembersSheet extends StatefulWidget {
  final String roomId;
  final Set<String> existingUserIds;
  final VoidCallback onMembersAdded;

  const _AddMembersSheet({
    required this.roomId,
    required this.existingUserIds,
    required this.onMembersAdded,
  });

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final _searchController = TextEditingController();
  final SearchUsersForChat _searchUsersForChat = sl<SearchUsersForChat>();

  List<ChatParticipant> _searchResults = [];
  final List<ChatParticipant> _selectedUsers = [];
  bool _isSearching = false;
  bool _isAdding = false;

  @override
  void dispose() {
    _searchController.dispose();
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
        if (mounted) setState(() => _isSearching = false);
      },
      (users) {
        if (mounted) {
          setState(() {
            _searchResults = users
                .where((u) => !widget.existingUserIds.contains(u.userId))
                .toList();
            _isSearching = false;
          });
        }
      },
    );
  }

  void _toggleUser(ChatParticipant user) {
    setState(() {
      final index = _selectedUsers.indexWhere((u) => u.userId == user.userId);
      if (index >= 0) {
        _selectedUsers.removeAt(index);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  Future<void> _addMembers() async {
    if (_selectedUsers.isEmpty) return;

    setState(() => _isAdding = true);

    final result = await sl<ChatRepository>().addChatMembers(
      roomId: widget.roomId,
      memberIds: _selectedUsers.map((u) => u.userId).toList(),
    );

    result.fold(
      (failure) {
        if (mounted) {
          setState(() => _isAdding = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('멤버 추가에 실패했습니다: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      (_) {
        widget.onMembersAdded();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_selectedUsers.length}명이 추가되었습니다.'),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          SizedBox(height: 8.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '멤버 초대',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_selectedUsers.isNotEmpty)
                  TextButton(
                    onPressed: _isAdding ? null : _addMembers,
                    child: _isAdding
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child:
                                const CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            '추가 (${_selectedUsers.length})',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
              ],
            ),
          ),
          if (_selectedUsers.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
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
                          ? Icon(Icons.person,
                              size: 12.w, color: Colors.grey[500])
                          : null,
                    ),
                    label: Text(
                      user.displayName ?? '',
                      style: TextStyle(fontSize: 12.sp),
                    ),
                    deleteIcon: Icon(Icons.close, size: 16.w),
                    onDeleted: () => _toggleUser(user),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList(),
              ),
            ),
          Padding(
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
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? '사용자를 검색하세요'
                              : '검색 결과가 없습니다',
                          style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          final isSelected = _selectedUsers
                              .any((u) => u.userId == user.userId);
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 20.r,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: user.photoUrl != null
                                  ? NetworkImage(user.photoUrl!)
                                  : null,
                              child: user.photoUrl == null
                                  ? Icon(Icons.person,
                                      size: 20.w, color: Colors.grey[500])
                                  : null,
                            ),
                            title: Text(
                              user.displayName ?? '알 수 없는 사용자',
                              style: TextStyle(fontSize: 15.sp),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle,
                                    color:
                                        Theme.of(context).colorScheme.primary)
                                : Icon(Icons.circle_outlined,
                                    color: Colors.grey[400]),
                            onTap: () => _toggleUser(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
