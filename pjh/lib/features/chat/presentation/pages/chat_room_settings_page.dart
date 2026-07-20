import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/services/block_service.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/image_source_picker.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../../../shared/widgets/petspace_settings_components.dart';
import '../../../../shared/widgets/petspace_state_view.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/chat_room.dart';
import '../../domain/entities/chat_participant.dart';
import '../../../../config/injection_container.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/report_chat_target.dart';
import '../../domain/usecases/search_users_for_chat.dart';
import '../../../../core/usecases/usecase.dart';
import '../widgets/chat_report_sheet.dart';

class ChatRoomSettingsPage extends StatefulWidget {
  final String roomId;
  final String? roomName;
  final Future<File?> Function(BuildContext context)? photoPicker;

  const ChatRoomSettingsPage({
    super.key,
    required this.roomId,
    this.roomName,
    this.photoPicker,
  });

  @override
  State<ChatRoomSettingsPage> createState() => _ChatRoomSettingsPageState();
}

class _ChatRoomSettingsPageState extends State<ChatRoomSettingsPage> {
  final _nameController = TextEditingController();
  List<ChatParticipant> _participants = [];
  bool _isLoading = true;
  String? _currentPhotoUrl;
  File? _pendingPhotoFile; // 저장 전 대기 중인 사진
  bool _hasNameChanged = false;
  bool _isSaving = false;
  bool _loadFailed = false;
  ChatRoomType? _roomType;
  String _initialName = '';

  String get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated ? authState.user.id : '';
  }

  ChatParticipant? get _currentParticipant {
    for (final participant in _participants) {
      if (participant.userId == _currentUserId) return participant;
    }
    return null;
  }

  bool get _isAdmin => _currentParticipant?.role == ChatRole.admin;
  bool get _hasSaveableChanges {
    final hasValidNameChange =
        _hasNameChanged && _nameController.text.trim().isNotEmpty;
    return _isAdmin &&
        !_isSaving &&
        (hasValidNameChange || _pendingPhotoFile != null);
  }

  @override
  void initState() {
    super.initState();
    _initialName = (widget.roomName ?? '').trim();
    _nameController.text = _initialName;
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
    final changed = _nameController.text.trim() != _initialName;
    if (changed != _hasNameChanged) {
      setState(() => _hasNameChanged = changed);
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    final results = await Future.wait([
      _loadParticipants(),
      _loadRoomInfo(),
    ]);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _loadFailed = results.any((succeeded) => !succeeded);
      });
    }
  }

  Future<bool> _loadRoomInfo() async {
    final result = await sl<ChatRepository>().getChatRoomInfo(widget.roomId);
    return result.fold(
      (failure) {
        log('[ChatRoomSettings] 채팅방 정보 로드 실패: ${failure.message}',
            name: 'ChatRoomSettings');
        return false;
      },
      (info) {
        if (info == null || !mounted) return false;
        final serverName =
            (info['name'] as String? ?? widget.roomName ?? '').trim();
        setState(() {
          _currentPhotoUrl = info['avatar_url'] as String?;
          _roomType = switch (info['type']) {
            'direct' => ChatRoomType.direct,
            'group' => ChatRoomType.group,
            _ => _roomType,
          };
          _initialName = serverName;
          _nameController.text = serverName;
          _hasNameChanged = false;
        });
        return true;
      },
    );
  }

  Future<bool> _loadParticipants() async {
    final result =
        await sl<ChatRepository>().getRoomParticipants(widget.roomId);
    return result.fold(
      (failure) {
        log('[ChatRoomSettings] 참여자 로드 실패: ${failure.message}',
            name: 'ChatRoomSettings');
        return false;
      },
      (participants) {
        if (!mounted) return false;
        setState(() => _participants = participants);
        return true;
      },
    );
  }

  Future<void> _pickPhoto() async {
    if (!_isAdmin) return;
    final picker = widget.photoPicker;
    File? file;
    if (picker != null) {
      file = await picker(context);
    } else {
      final pickedFile = await ImageSourcePicker.pickSingle(
        context,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      file = pickedFile == null ? null : File(pickedFile.path);
    }
    if (!mounted || file == null) return;

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
    if (!_isAdmin || _isSaving || !_hasSaveableChanges) return;
    final newName = _nameController.text.trim();
    if (_hasNameChanged && newName.isEmpty) {
      _showMessage('채팅방 이름을 입력해주세요.');
      return;
    }
    setState(() => _isSaving = true);
    final repo = sl<ChatRepository>();

    // 실제 이름 변경이 있을 때만 저장한다.
    if (_hasNameChanged) {
      final nameResult =
          await repo.updateChatRoomName(roomId: widget.roomId, name: newName);
      final nameError = nameResult.fold((f) => f.message, (_) => null);
      if (nameError != null) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('저장에 실패했습니다. 다시 시도해주세요.'),
                backgroundColor: AppTheme.errorColor),
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
            const SnackBar(
                content: Text('저장에 실패했습니다. 다시 시도해주세요.'),
                backgroundColor: AppTheme.errorColor),
          );
        }
        return;
      }
      _pendingPhotoFile = null;
    }

    if (mounted) {
      setState(() {
        _initialName = newName;
        _hasNameChanged = false;
        _isSaving = false;
      });
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
            const SnackBar(
              content: Text('채팅방에서 나가지 못했습니다. 다시 시도해주세요.'),
              backgroundColor: AppTheme.errorColor,
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
    if (!_isAdmin || _roomType != ChatRoomType.group) return;
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

  Future<void> _reportParticipant(ChatParticipant participant) async {
    final reason = await showChatReportSheet(context, title: '사용자 신고');
    if (reason == null || !mounted) return;
    final result = await sl<ReportChatTarget>()(
      ReportChatTargetParams(
        target: ChatReportTarget.user,
        targetId: participant.userId,
        reporterId: _currentUserId,
        reason: reason,
      ),
    );
    if (!mounted) return;
    result.fold(
      (_) => _showMessage('신고 접수에 실패했습니다. 다시 시도해주세요.'),
      (_) => _showMessage('신고가 접수되었습니다. 검토 후 조치하겠습니다.'),
    );
  }

  Future<void> _blockParticipant(ChatParticipant participant) async {
    final name = participant.displayName ?? '이 사용자';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용자 차단'),
        content: Text('$name님의 메시지를 더 이상 표시하지 않을까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.highlightColor,
            ),
            child: const Text('차단'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final succeeded = await sl<BlockService>().blockUser(participant.userId);
    if (!mounted) return;
    if (!succeeded) {
      _showMessage('차단에 실패했습니다. 다시 시도해주세요.');
      return;
    }
    await sl<BlockService>().getBlockedUserIds(forceRefresh: true);
    if (mounted) _showMessage('$name님을 차단했습니다.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PetSpacePageScaffold(
      title: '채팅방 정보',
      body: _isLoading
          ? const PetSpaceStateView.loading(
              key: Key('chat_room_settings_loading'),
            )
          : _loadFailed
              ? PetSpaceStateView.error(
                  key: const Key('chat_room_settings_error'),
                  icon: Icons.cloud_off_outlined,
                  title: '채팅방 정보를 불러오지 못했어요',
                  message: '인터넷 연결을 확인하고 다시 시도해주세요.',
                  actionLabel: '다시 시도',
                  onAction: _loadData,
                )
              : ListView(
                  key: const Key('chat_room_settings_content'),
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
                  children: [
                    _buildSummaryCard(),
                    SizedBox(height: 24.h),
                    _buildEditSection(),
                    SizedBox(height: 24.h),
                    _buildParticipantsSection(),
                    SizedBox(height: 24.h),
                    _buildLeaveSection(),
                  ],
                ),
      bottomNavigationBar:
          !_isLoading && !_loadFailed && _isAdmin ? _buildSaveBar() : null,
    );
  }

  Widget _buildSummaryCard() {
    final displayName = _initialName.isNotEmpty ? _initialName : '이름 없는 채팅방';
    return Container(
      key: const Key('chat_room_summary_card'),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28.r,
            backgroundColor: AppTheme.actionContainer,
            backgroundImage: _pendingPhotoFile != null
                ? FileImage(_pendingPhotoFile!)
                : (_currentPhotoUrl != null
                    ? CachedNetworkImageProvider(_currentPhotoUrl!)
                    : null) as ImageProvider?,
            child: _pendingPhotoFile == null && _currentPhotoUrl == null
                ? Icon(
                    _roomType == ChatRoomType.group
                        ? Icons.group_rounded
                        : Icons.person_rounded,
                    color: AppTheme.actionBase,
                  )
                : null,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTheme.fontHeading.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brandDeep,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '참여자 ${_participants.length}명',
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          if (_isAdmin)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: AppTheme.actionContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
              ),
              child: Text(
                '관리자',
                style: TextStyle(
                  fontSize: AppTheme.fontMicro.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.actionBase,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditSection() {
    return PetSpaceSettingsSection(
      title: '채팅방 꾸미기',
      children: [
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            children: [
              _buildPhotoSection(),
              SizedBox(height: 16.h),
              _buildNameSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return GestureDetector(
      key: const Key('chat_room_photo_picker'),
      onTap: _isSaving || !_isAdmin ? null : _pickPhoto,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 48.r,
            backgroundColor: AppTheme.actionContainer,
            backgroundImage: _pendingPhotoFile != null
                ? FileImage(_pendingPhotoFile!)
                : (_currentPhotoUrl != null
                    ? CachedNetworkImageProvider(_currentPhotoUrl!)
                    : null) as ImageProvider?,
            child: _pendingPhotoFile == null && _currentPhotoUrl == null
                ? Icon(
                    Icons.group,
                    size: 40.w,
                    color: AppTheme.actionBase,
                  )
                : null,
          ),
          if (_isAdmin)
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
        key: const Key('chat_room_name_field'),
        controller: _nameController,
        enabled: _isAdmin,
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

  Widget _buildSaveBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: ElevatedButton(
          key: const Key('chat_room_save_button'),
          onPressed: _hasSaveableChanges ? _saveChanges : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppTheme.actionBase,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('변경사항 저장'),
        ),
      ),
    );
  }

  Widget _buildParticipantsSection() {
    return PetSpaceSettingsSection(
      title: '참여자',
      description: '${_participants.length}명이 함께하고 있어요.',
      children: [
        ..._participants.map(_buildParticipantTile),
        if (_isAdmin && _roomType == ChatRoomType.group)
          PetSpaceSettingsTile(
            icon: Icons.person_add_alt_1_rounded,
            title: '멤버 초대',
            subtitle: '새로운 참여자를 채팅방에 초대합니다.',
            onTap: _showAddMembersSheet,
          ),
      ],
    );
  }

  Widget _buildParticipantTile(ChatParticipant participant) {
    final isMe = participant.userId == _currentUserId;
    return ListTile(
      key: Key('chat_participant_${participant.userId}'),
      minTileHeight: 64,
      leading: CircleAvatar(
        radius: 20.r,
        backgroundColor: AppTheme.actionContainer,
        backgroundImage: participant.photoUrl != null
            ? CachedNetworkImageProvider(participant.photoUrl!)
            : null,
        child: participant.photoUrl == null
            ? Icon(Icons.person, size: 20.w, color: AppTheme.actionBase)
            : null,
      ),
      title: Text(
        participant.displayName ?? '알 수 없는 사용자',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: AppTheme.fontBody.sp),
      ),
      subtitle: Text(
        [
          if (isMe) '나',
          participant.role == ChatRole.admin ? '관리자' : '참여자',
        ].join(' · '),
        style: TextStyle(
          fontSize: AppTheme.fontCaption.sp,
          color: AppTheme.secondaryTextColor,
        ),
      ),
      trailing: !isMe && _roomType == ChatRoomType.group
          ? PopupMenuButton<String>(
              key: Key('chat_participant_menu_${participant.userId}'),
              tooltip: '${participant.displayName ?? '참여자'} 메뉴',
              constraints: const BoxConstraints(minWidth: 44),
              onSelected: (value) {
                if (value == 'report') {
                  _reportParticipant(participant);
                } else if (value == 'block') {
                  _blockParticipant(participant);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('신고하기')),
                PopupMenuItem(value: 'block', child: Text('차단하기')),
              ],
            )
          : null,
    );
  }

  Widget _buildLeaveSection() {
    return PetSpaceSettingsSection(
      title: '채팅방 관리',
      children: [
        PetSpaceSettingsTile(
          icon: Icons.logout_rounded,
          title: '채팅방 나가기',
          subtitle: '나간 후에는 대화 내용을 볼 수 없습니다.',
          destructive: true,
          onTap: _leaveRoom,
        ),
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
  String? _searchError;
  Timer? _searchDebounce;
  int _searchGeneration = 0;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String query) {
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
      (failure) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _searchError = failure.message;
        });
      },
      (users) {
        setState(() {
          _searchResults = users
              .where((u) => !widget.existingUserIds.contains(u.userId))
              .toList();
          _isSearching = false;
          _searchError = null;
        });
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
            const SnackBar(
              content: Text('멤버 추가에 실패했습니다. 다시 시도해주세요.'),
              backgroundColor: AppTheme.errorColor,
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
              onChanged: _scheduleSearch,
              decoration: InputDecoration(
                hintText: '닉네임 또는 반려동물 이름으로 검색',
                hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
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
                : _searchError != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('검색 결과를 불러오지 못했습니다'),
                            SizedBox(height: 12.h),
                            OutlinedButton(
                              onPressed: () {
                                final query = _searchController.text.trim();
                                if (query.isNotEmpty) _scheduleSearch(query);
                              },
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isEmpty
                                  ? '사용자를 검색하세요'
                                  : '검색 결과가 없습니다',
                              style: TextStyle(
                                  fontSize: 14.sp, color: Colors.grey),
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary)
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
