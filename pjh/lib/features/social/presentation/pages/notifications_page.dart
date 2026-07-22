import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/petspace_state_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../domain/entities/notification.dart' as app;
import '../bloc/notifications_bloc.dart';

class NotificationsPage extends StatelessWidget {
  final String userId;
  final NotificationsBloc? bloc;
  final DateTime Function()? nowProvider;

  const NotificationsPage({
    super.key,
    required this.userId,
    this.bloc,
    this.nowProvider,
  });

  @override
  Widget build(BuildContext context) {
    final content = _NotificationsView(
      userId: userId,
      nowProvider: nowProvider ?? DateTime.now,
    );
    final injected = bloc;
    if (injected != null) {
      return BlocProvider<NotificationsBloc>.value(
        value: injected,
        child: content,
      );
    }
    return BlocProvider(
      create: (_) => di.sl<NotificationsBloc>()
        ..add(LoadNotificationsRequested(userId: userId)),
      child: content,
    );
  }
}

class _NotificationsView extends StatelessWidget {
  final String userId;
  final DateTime Function() nowProvider;

  const _NotificationsView({
    required this.userId,
    required this.nowProvider,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NotificationsBloc, NotificationsState>(
      listenWhen: (previous, current) {
        if (current is! NotificationsLoaded) return false;
        if (previous is! NotificationsLoaded) {
          return current.actionError != null || current.allReadSuccessCount > 0;
        }
        return (current.actionError != null &&
                previous.actionError != current.actionError) ||
            current.allReadSuccessCount > previous.allReadSuccessCount;
      },
      listener: (context, state) {
        if (state is! NotificationsLoaded) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        if (state.actionError != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(state.actionError!),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        } else if (state.allReadSuccessCount > 0) {
          messenger.showSnackBar(
            const SnackBar(content: Text('모든 알림을 읽음으로 처리했어요.')),
          );
        }
      },
      builder: (context, state) {
        final loaded = state is NotificationsLoaded ? state : null;
        final hasUnread =
            loaded?.notifications.any((item) => !item.isRead) ?? false;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: '뒤로가기',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
            title: const Text('알림'),
            actions: [
              TextButton(
                key: const Key('notifications_mark_all_read'),
                onPressed: loaded == null ||
                        !hasUnread ||
                        loaded.isMarkingAllRead
                    ? null
                    : () => context.read<NotificationsBloc>().add(
                          MarkAllNotificationsAsReadRequested(userId: userId),
                        ),
                child: loaded?.isMarkingAllRead == true
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('모두 읽음'),
              ),
              SizedBox(width: 8.w),
            ],
          ),
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, NotificationsState state) {
    if (state is NotificationsLoading || state is NotificationsInitial) {
      return const NotificationShimmerLoading();
    }
    if (state is NotificationsError) {
      return PetSpaceStateView.error(
        key: const Key('notifications_initial_error'),
        title: '알림을 불러오지 못했어요',
        message: '연결 상태를 확인하고 다시 시도해주세요.',
        actionLabel: '다시 시도',
        onAction: () => context.read<NotificationsBloc>().add(
              LoadNotificationsRequested(userId: userId),
            ),
      );
    }
    if (state is! NotificationsLoaded) return const SizedBox.shrink();
    if (state.notifications.isEmpty) {
      return EmptyStateWidget(
        key: const Key('notifications_empty'),
        icon: Icons.notifications_none_rounded,
        title: '새로운 알림이 없어요',
        subtitle: '좋아요·댓글·팔로우 소식이 생기면\n여기에 표시됩니다.',
        actionLabel: '피드 보기',
        onAction: () => context.go('/feed'),
      );
    }

    final now = nowProvider();
    final children = <Widget>[];
    var previousGroup = '';
    for (final notification in state.notifications) {
      final group = _isSameDay(notification.createdAt, now) ? '오늘' : '이전 알림';
      if (group != previousGroup) {
        children.add(_groupHeader(context, group));
        previousGroup = group;
      }
      children.add(
        _NotificationListItem(
          notification: _withoutRedundantBody(notification),
          now: now,
          isReadPending: state.pendingReadIds.contains(notification.id),
          onTap: () {
            if (!notification.isRead) {
              context.read<NotificationsBloc>().add(
                    MarkNotificationAsReadRequested(
                      notificationId: notification.id,
                    ),
                  );
            }
            _navigateToContent(context, notification);
          },
        ),
      );
      children.add(const Divider(height: 1));
    }
    if (state.isLoadingMore) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    } else if (state.error != null) {
      children.add(
        Center(
          child: TextButton.icon(
            key: const Key('notifications_load_more_retry'),
            onPressed: () => context.read<NotificationsBloc>().add(
                  LoadMoreNotificationsRequested(userId: userId),
                ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('알림을 더 불러오지 못했어요 · 다시 시도'),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => context.read<NotificationsBloc>().add(
            RefreshNotificationsRequested(userId: userId),
          ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 240.h &&
              !state.hasReachedMax &&
              !state.isLoadingMore) {
            context.read<NotificationsBloc>().add(
                  LoadMoreNotificationsRequested(userId: userId),
                );
          }
          return false;
        },
        child: ListView(
          key: const Key('notifications_list'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: children,
        ),
      ),
    );
  }

  Widget _groupHeader(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 8.h),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTheme.fontCaption.sp,
          fontWeight: FontWeight.w700,
          color: theme.brightness == Brightness.dark
              ? theme.colorScheme.onSurfaceVariant
              : AppTheme.secondaryTextColor,
        ),
      ),
    );
  }

  bool _isSameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  app.Notification _withoutRedundantBody(app.Notification notification) {
    if (notification.type == app.NotificationType.like ||
        notification.type == app.NotificationType.follow) {
      return notification.copyWith(body: '');
    }
    return notification;
  }

  void _navigateToContent(BuildContext context, app.Notification notification) {
    switch (notification.type) {
      case app.NotificationType.like:
      case app.NotificationType.comment:
      case app.NotificationType.mention:
      case app.NotificationType.postShare:
      case app.NotificationType.adminNewPost:
        final postId = notification.postId;
        if (postId == null || postId.isEmpty) {
          _showUnavailable(context);
        } else {
          context.push('/post/$postId');
        }
        break;
      case app.NotificationType.follow:
      case app.NotificationType.friendRequest:
        if (notification.senderId.isEmpty) {
          _showUnavailable(context);
        } else {
          context.push(
            '/user-profile/${notification.senderId}?currentUserId=$userId',
          );
        }
        break;
      case app.NotificationType.emotionAnalysis:
        context.push('/ai-history-page');
        break;
      case app.NotificationType.healthAlert:
        context.push('/health');
        break;
      case app.NotificationType.system:
      case app.NotificationType.unknown:
        _showUnavailable(context);
        break;
    }
  }

  void _showUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('연결된 내용을 열 수 없어요.')),
      );
  }
}

class _NotificationListItem extends StatelessWidget {
  final app.Notification notification;
  final VoidCallback onTap;
  final bool isReadPending;
  final DateTime now;

  const _NotificationListItem({
    required this.notification,
    required this.onTap,
    required this.isReadPending,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppTheme.secondaryTextColor;
    final unreadSurface = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : AppTheme.actionContainer.withValues(alpha: 0.55);

    return Material(
      color: notification.isRead ? Colors.transparent : unreadSurface,
      child: InkWell(
        key: Key('notification_${notification.id}'),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(context),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: notification.senderName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: AppTheme.fontCaption.sp,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          TextSpan(
                            text: _actionText(notification.type),
                            style: TextStyle(
                              fontSize: AppTheme.fontCaption.sp,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (notification.body.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppTheme.fontMicro.sp,
                          color: muted,
                        ),
                      ),
                    ],
                    SizedBox(height: 5.h),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: TextStyle(
                        fontSize: AppTheme.fontMicro.sp,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              if (isReadPending)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (!notification.isRead)
                Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: const BoxDecoration(
                    color: AppTheme.actionBase,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final theme = Theme.of(context);
    final initial = notification.senderName.trim().isEmpty
        ? '?'
        : notification.senderName.trim()[0];
    return Stack(
      children: [
        Semantics(
          label: '${notification.senderName} 프로필 사진',
          image: true,
          child: CircleAvatar(
            radius: 20.r,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: notification.senderProfileImage == null
                ? null
                : NetworkImage(notification.senderProfileImage!),
            child: notification.senderProfileImage == null
                ? Text(
                    initial,
                    style: TextStyle(
                      fontSize: AppTheme.fontCaption.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _typeIcon(notification.type),
              size: 12.w,
              color: notification.type == app.NotificationType.like
                  ? AppTheme.errorColor
                  : AppTheme.actionBase,
            ),
          ),
        ),
      ],
    );
  }

  String _actionText(app.NotificationType type) {
    return switch (type) {
      app.NotificationType.like => '님이 게시물에 좋아요를 눌렀어요.',
      app.NotificationType.comment => '님이 댓글을 남겼어요.',
      app.NotificationType.follow => '님이 팔로우하기 시작했어요.',
      app.NotificationType.mention => '님이 회원님을 언급했어요.',
      app.NotificationType.system => '에서 새 소식을 전했어요.',
      app.NotificationType.adminNewPost => '에서 새 게시물을 알려드려요.',
      app.NotificationType.emotionAnalysis => '님이 AI 분석을 공유했어요.',
      app.NotificationType.healthAlert => '에서 건강 일정을 알려드려요.',
      app.NotificationType.friendRequest => '님이 친구 요청을 보냈어요.',
      app.NotificationType.postShare => '님이 게시물을 공유했어요.',
      app.NotificationType.unknown => '에서 새 알림을 보냈어요.',
    };
  }

  IconData _typeIcon(app.NotificationType type) {
    return switch (type) {
      app.NotificationType.like => Icons.favorite_rounded,
      app.NotificationType.comment => Icons.chat_bubble_rounded,
      app.NotificationType.follow => Icons.person_add_rounded,
      app.NotificationType.mention => Icons.alternate_email_rounded,
      app.NotificationType.system => Icons.campaign_outlined,
      app.NotificationType.adminNewPost => Icons.article_outlined,
      app.NotificationType.emotionAnalysis => Icons.psychology_rounded,
      app.NotificationType.healthAlert => Icons.health_and_safety_outlined,
      app.NotificationType.friendRequest => Icons.person_add_alt_1_rounded,
      app.NotificationType.postShare => Icons.share_rounded,
      app.NotificationType.unknown => Icons.notifications_none_rounded,
    };
  }

  String _relativeTime(DateTime createdAt) {
    final difference = now.difference(createdAt);
    if (difference.inMinutes < 1) return '방금 전';
    if (difference.inHours < 1) return '${difference.inMinutes}분 전';
    if (difference.inDays < 1) return '${difference.inHours}시간 전';
    if (difference.inDays < 7) return '${difference.inDays}일 전';
    return '${createdAt.month}/${createdAt.day}';
  }
}
