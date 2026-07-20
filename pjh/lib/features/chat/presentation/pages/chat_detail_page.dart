import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/services/block_service.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../../../shared/widgets/petspace_state_view.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_participant.dart';
import '../../domain/entities/chat_room.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/report_chat_target.dart';
import '../bloc/chat_detail/chat_detail_bloc.dart';
import '../bloc/chat_rooms/chat_rooms_bloc.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_report_sheet.dart';

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
  final TextEditingController _messageController = TextEditingController();
  StreamSubscription<ChatMessage>? _messageSubscription;
  Timer? _readReceiptTimer;
  Timer? _participantsRefreshTimer;

  List<ChatParticipant> _participants = [];
  String? _roomName;
  ChatRoomType? _roomType;

  String get _currentUserId {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) return authState.user.id;
    return '';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _roomName = widget.roomName;

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
        // DB에서 최신 방 이름 로드
        _refreshRoomName();
        // 실시간 구독
        _subscribeToMessages();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _readReceiptTimer?.cancel();
    _participantsRefreshTimer?.cancel();
    _unsubscribeFromMessages();
    super.dispose();
  }

  Future<void> _loadParticipants() async {
    final result =
        await sl<ChatRepository>().getRoomParticipants(widget.roomId);
    result.fold(
      (failure) => log('Failed to load participants: ${failure.message}',
          name: 'ChatDetail'),
      (participants) {
        if (mounted) setState(() => _participants = participants);
      },
    );
  }

  Future<void> _refreshRoomName() async {
    final result = await sl<ChatRepository>().getChatRoomInfo(widget.roomId);
    result.fold(
      (failure) => log('Failed to refresh room name: ${failure.message}',
          name: 'ChatDetail'),
      (info) {
        if (!mounted || info == null) return;
        setState(() {
          _roomName = info['name'] as String? ?? _roomName;
          _roomType = switch (info['type']) {
            'direct' => ChatRoomType.direct,
            'group' => ChatRoomType.group,
            _ => _roomType,
          };
        });
      },
    );
  }

  /// 1:1 채팅 상대 참여자(없으면 null — 그룹/미로딩).
  ChatParticipant? get _otherParticipant {
    if (_roomType != ChatRoomType.direct) return null;
    for (final p in _participants) {
      if (p.userId != _currentUserId) return p;
    }
    return null;
  }

  /// 신고하기: 사유 선택 → ReportChatTarget(reportChatUser) → 접수 안내.
  Future<void> _reportUser() async {
    final other = _otherParticipant;
    if (other == null) {
      _showSnack('신고할 상대를 찾을 수 없습니다.');
      return;
    }
    final reason = await showChatReportSheet(context, title: '사용자 신고');
    if (reason == null || !mounted) return;

    final result = await sl<ReportChatTarget>()(ReportChatTargetParams(
      target: ChatReportTarget.user,
      targetId: other.userId,
      reporterId: _currentUserId,
      reason: reason,
    ));
    if (!mounted) return;
    result.fold(
      (failure) => _showSnack('신고 접수에 실패했습니다. 다시 시도해주세요.'),
      (_) => _showSnack('신고가 접수되었습니다. 검토 후 조치하겠습니다.'),
    );
  }

  /// 개별 메시지 신고: 사유 선택 → ReportChatTarget(reportChatMessage) → 접수 안내.
  Future<void> _reportMessage(ChatMessage message) async {
    final reason = await showChatReportSheet(context, title: '메시지 신고');
    if (reason == null || !mounted) return;

    final result = await sl<ReportChatTarget>()(ReportChatTargetParams(
      target: ChatReportTarget.message,
      targetId: message.id,
      reporterId: _currentUserId,
      reason: reason,
    ));
    if (!mounted) return;
    result.fold(
      (failure) => _showSnack('신고 접수에 실패했습니다. 다시 시도해주세요.'),
      (_) => _showSnack('신고가 접수되었습니다. 검토 후 조치하겠습니다.'),
    );
  }

  /// 차단하기: 확인 다이얼로그 → blockUser → 캐시 무효화 → 즉시 반영(현재 방 재로드 +
  /// 방 목록 refresh) → 목록으로 복귀.
  Future<void> _blockUser() async {
    final other = _otherParticipant;
    if (other == null) {
      _showSnack('차단할 상대를 찾을 수 없습니다.');
      return;
    }
    final name = other.displayName ?? '이 사용자';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사용자 차단'),
        content: Text(
          '$name님을 차단하시겠어요?\n대화와 메시지가 더 이상 표시되지 않습니다.',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.highlightColor),
            child: const Text('차단'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await sl<BlockService>().blockUser(other.userId);
    if (!mounted) return;
    if (!ok) {
      _showSnack('차단에 실패했습니다. 잠시 후 다시 시도해주세요.');
      return;
    }

    // 캐시 무효화 후 최신 차단 목록 반영(즉시 반영의 전제).
    await sl<BlockService>().getBlockedUserIds(forceRefresh: true);
    if (!mounted) return;

    // 현재 방 즉시 재그리기(차단 상대 기존 메시지 비표시).
    context.read<ChatDetailBloc>().add(
          ChatDetailBlockApplied(roomId: widget.roomId),
        );
    // 채팅방 목록에서 차단 방 숨김 갱신(목록 BLoC이 트리에 없으면 다음 자연 로드에서 반영).
    try {
      context.read<ChatRoomsBloc>().add(
            ChatRoomsRefreshRequested(userId: _currentUserId),
          );
    } catch (_) {
      // ChatRoomsBloc 미제공 컨텍스트 — getChatRooms 필터가 다음 로드 시 적용됨.
    }

    _showSnack('$name님을 차단했습니다.');
    // 차단 후엔 대화가 비므로 목록으로 복귀.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/chat');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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
    _messageSubscription = sl<ChatRepository>()
        .subscribeToRoomMessages(widget.roomId)
        .listen((message) {
      if (!mounted) return;
      final sender = _participants.cast<ChatParticipant?>().firstWhere(
            (participant) => participant?.userId == message.senderId,
            orElse: () => null,
          );
      final hydratedMessage = sender == null
          ? message
          : message.copyWith(
              senderName: sender.displayName,
              senderPhotoUrl: sender.photoUrl,
            );
      // 본인이 보낸 메시지는 이미 UI에 반영됨 - 중복 방지는 BLoC에서 처리
      context.read<ChatDetailBloc>().add(
            ChatDetailNewMessageReceived(message: hydratedMessage),
          );
      _scheduleReadAndParticipantsRefresh();
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
    }, onError: (e) {
      log('Failed to parse realtime message: $e', name: 'ChatDetail');
    });
  }

  void _scheduleReadAndParticipantsRefresh() {
    _readReceiptTimer?.cancel();
    _participantsRefreshTimer?.cancel();
    _readReceiptTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      context.read<ChatDetailBloc>().add(
            ChatDetailMarkAsReadRequested(
              roomId: widget.roomId,
              userId: _currentUserId,
            ),
          );
    });
    _participantsRefreshTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) _loadParticipants();
    });
  }

  void _unsubscribeFromMessages() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatDetailBloc, ChatDetailState>(
      listenWhen: (previous, current) {
        if (previous is! ChatDetailLoaded || current is! ChatDetailLoaded) {
          return false;
        }
        return previous.sendOutcome != current.sendOutcome ||
            previous.loadMoreError != current.loadMoreError;
      },
      listener: (context, state) {
        if (state is! ChatDetailLoaded) return;
        final outcome = state.sendOutcome;
        if (outcome?.status == ChatSendStatus.success &&
            outcome?.kind == ChatSendKind.text &&
            _messageController.text.trim() == outcome?.text?.trim()) {
          _messageController.clear();
        }
      },
      child: PetSpacePageScaffold(
        title: _roomName ?? '채팅',
        resizeToAvoidBottomInset: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/chat');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: '채팅방 정보',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () async {
              await context.push<bool>(
                '/chat/${widget.roomId}/settings?name=${Uri.encodeComponent(_roomName ?? '')}',
              );
              if (mounted) {
                _loadParticipants();
                _refreshRoomName();
              }
            },
          ),
          if (_roomType == ChatRoomType.direct)
            PopupMenuButton<String>(
              key: const Key('chat_direct_user_menu'),
              tooltip: '대화 상대 메뉴',
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (value) {
                if (value == 'report') {
                  _reportUser();
                } else if (value == 'block') {
                  _blockUser();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('신고하기')),
                PopupMenuItem(value: 'block', child: Text('차단하기')),
              ],
            ),
        ],
        body: Column(
          children: [
            Expanded(
              child: BlocBuilder<ChatDetailBloc, ChatDetailState>(
                builder: (context, state) {
                  if (state is ChatDetailInitial ||
                      state is ChatDetailLoading) {
                    return const PetSpaceStateView.loading(
                      key: Key('chat_detail_loading'),
                    );
                  }
                  if (state is ChatDetailError) {
                    return PetSpaceStateView.error(
                      key: const Key('chat_detail_initial_error'),
                      icon: Icons.cloud_off_outlined,
                      title: '대화를 불러오지 못했어요',
                      message: '인터넷 연결을 확인하고 다시 시도해주세요.',
                      actionLabel: '다시 시도',
                      onAction: () {
                        context.read<ChatDetailBloc>().add(
                              ChatDetailLoadRequested(roomId: widget.roomId),
                            );
                      },
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
              buildWhen: (previous, current) {
                if (previous is! ChatDetailLoaded ||
                    current is! ChatDetailLoaded) {
                  return true;
                }
                return previous.sendOutcome != current.sendOutcome;
              },
              builder: (context, state) {
                if (state is! ChatDetailLoaded ||
                    state.sendOutcome?.status != ChatSendStatus.failure) {
                  return const SizedBox.shrink();
                }
                return _buildSendFailureCard(state.sendOutcome!);
              },
            ),
            BlocBuilder<ChatDetailBloc, ChatDetailState>(
              builder: (context, state) {
                final isSending = state is ChatDetailLoaded && state.isSending;
                return ChatInputBar(
                  controller: _messageController,
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
                    context.read<ChatDetailBloc>().add(
                          ChatDetailSendMultipleImagesRequested(
                            roomId: widget.roomId,
                            senderId: _currentUserId,
                            images: images,
                          ),
                        );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatDetailLoaded state) {
    if (state.messages.isEmpty) {
      return const PetSpaceStateView.empty(
        key: Key('chat_detail_empty'),
        icon: Icons.waving_hand_outlined,
        title: '첫 메시지를 보내보세요',
        message: '안부를 건네며 대화를 시작해보세요.',
      );
    }

    final hasPaginationStatus =
        state.isLoadingMore || state.loadMoreError != null;
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
      itemCount: state.messages.length + (hasPaginationStatus ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasPaginationStatus && index == state.messages.length) {
          if (state.loadMoreError != null) {
            return _buildLoadMoreError();
          }
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
              onLongPress: isMine ? null : () => _reportMessage(message),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    String text;

    if (_isSameDay(local, now)) {
      text = '오늘';
    } else if (_isSameDay(local, now.subtract(const Duration(days: 1)))) {
      text = '어제';
    } else if (local.year == now.year) {
      text = '${local.month}월 ${local.day}일';
    } else {
      text = '${local.year}년 ${local.month}월 ${local.day}일';
    }

    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: AppTheme.actionContainer,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: AppTheme.fontMicro.sp,
            color: AppTheme.secondaryTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSendFailureCard(ChatSendOutcome outcome) {
    final detail = switch (outcome.kind) {
      ChatSendKind.text => '입력 내용은 성공할 때까지 그대로 유지됩니다.',
      ChatSendKind.image => '선택한 사진을 다시 보낼 수 있습니다.',
      ChatSendKind.multiImage =>
        '선택한 사진 ${outcome.images.length}장을 다시 보낼 수 있습니다.',
    };
    return Container(
      key: const Key('chat_send_failure_card'),
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 12.h),
      decoration: BoxDecoration(
        color: AppTheme.highlightColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.highlightColor,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '메시지를 보내지 못했어요.',
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: AppTheme.fontMicro.sp,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: const Key('chat_send_retry'),
            onPressed: () {
              context.read<ChatDetailBloc>().add(
                    const ChatDetailRetryLastSendRequested(),
                  );
            },
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: AppTheme.highlightColor,
            ),
            child: const Text('다시 보내기'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreError() {
    return Container(
      key: const Key('chat_load_more_error'),
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(
            '이전 메시지를 불러오지 못했어요.',
            style: TextStyle(
              fontSize: AppTheme.fontCaption.sp,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          SizedBox(height: 8.h),
          OutlinedButton(
            key: const Key('chat_load_more_retry'),
            onPressed: () {
              context.read<ChatDetailBloc>().add(
                    ChatDetailLoadMoreRequested(roomId: widget.roomId),
                  );
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
