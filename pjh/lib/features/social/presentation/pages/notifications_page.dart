import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_screenutil/flutter_screenutil.dart";
import "package:go_router/go_router.dart";

import "../../../../config/injection_container.dart" as di;
import "../bloc/notifications_bloc.dart";

class NotificationsPage extends StatelessWidget {
  final String userId;

  const NotificationsPage({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => di.sl<NotificationsBloc>()
        ..add(LoadNotificationsRequested(userId: userId)),
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/home');
          },
        ),
        title: const Text("알림"),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            tooltip: "모두 읽음",
            onPressed: () {
              context.read<NotificationsBloc>().add(
                    MarkAllNotificationsAsReadRequested(userId: userId),
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("모든 알림을 읽음으로 처리했습니다"),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationsBloc, NotificationsState>(
        builder: (context, state) {
          if (state is NotificationsLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (state is NotificationsLoaded) {
            if (state.notifications.isEmpty) {
              return Center(
                child: Text("새로운 알림이 없습니다.", style: TextStyle(fontSize: 14.sp)),
              );
            }
            return ListView.builder(
              itemCount: state.notifications.length,
              itemBuilder: (context, index) {
                final notification = state.notifications[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 20.r,
                      backgroundImage: notification.senderProfileImage != null
                          ? NetworkImage(notification.senderProfileImage!)
                          : null,
                      child: notification.senderProfileImage == null
                          ? Text(notification.senderName.substring(0, 1), style: TextStyle(fontSize: 14.sp))
                          : null,
                    ),
                    title: Text(notification.title, style: TextStyle(fontSize: 14.sp)),
                    subtitle: Text(notification.body, style: TextStyle(fontSize: 12.sp)),
                    trailing: notification.isRead
                        ? null
                        : Container(
                            width: 8.w,
                            height: 8.w,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                    onTap: () {
                      if (!notification.isRead) {
                        context.read<NotificationsBloc>().add(
                              MarkNotificationAsReadRequested(
                                notificationId: notification.id,
                              ),
                            );
                      }
                    },
                  ),
                );
              },
            );
          } else if (state is NotificationsError) {
            return Center(
              child: Text("오류: ${state.message}", style: TextStyle(fontSize: 14.sp)),
            );
          }
          return Center(
            child: Text("알림을 로드해주세요.", style: TextStyle(fontSize: 14.sp)),
          );
        },
      ),
      ),
    );
  }
}
