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
import '../widgets/notification_card.dart';

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
        children.add(_groupHeader(group));
        previousGroup = group;
      }
      children.add(
        NotificationCard(
          notification: notification,
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

  Widget _groupHeader(String label) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 8.h),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppTheme.fontCaption.sp,
          fontWeight: FontWeight.w700,
          color: AppTheme.secondaryTextColor,
        ),
      ),
    );
  }

  bool _isSameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

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
