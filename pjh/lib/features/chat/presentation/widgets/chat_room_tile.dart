import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/chat_room.dart';

class ChatRoomTile extends StatelessWidget {
  final ChatRoom room;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMorePressed;

  const ChatRoomTile({
    super.key,
    required this.room,
    required this.currentUserId,
    required this.onTap,
    this.onLongPress,
    this.onMorePressed,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = room.displayName(currentUserId);
    final avatarUrl = room.displayAvatarUrl(currentUserId);
    final memberCount = room.participants.length;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? theme.colorScheme.surface : AppTheme.surfaceColor;
    final border = isDark ? theme.colorScheme.outlineVariant : AppTheme.border;
    final body = isDark
        ? theme.colorScheme.onSurface
        : AppTheme.primaryTextColor;
    final muted = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppTheme.secondaryTextColor;

    return Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 4.w, 12.h),
          child: Row(
            children: [
              _buildAvatar(context, avatarUrl),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: AppTheme.fontBody.sp,
                                    fontWeight: FontWeight.w600,
                                    color: body,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (memberCount > 2)
                                Padding(
                                  padding: EdgeInsets.only(left: 4.w),
                                  child: Text(
                                    '$memberCount',
                                    style: TextStyle(
                                      fontSize: AppTheme.fontCaption.sp,
                                      color: muted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (room.lastMessageAt != null)
                          Padding(
                            padding: EdgeInsets.only(left: 8.w),
                            child: Text(
                              _formatTime(room.lastMessageAt!),
                              style: TextStyle(
                                fontSize: AppTheme.fontMicro.sp,
                                color: muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 5.h),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            room.lastMessage?.isNotEmpty == true
                                ? room.lastMessage!
                                : '아직 메시지가 없습니다',
                            style: TextStyle(
                              fontSize: AppTheme.fontCaption.sp,
                              color: muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (room.unreadCount > 0)
                          Container(
                            margin: EdgeInsets.only(left: 8.w),
                            constraints: const BoxConstraints(minWidth: 22),
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(11.r),
                            ),
                            child: Text(
                              room.unreadCount > 99
                                  ? '99+'
                                  : '${room.unreadCount}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontSize: AppTheme.fontMicro.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onMorePressed != null)
                IconButton(
                  key: Key('chat_room_more_${room.id}'),
                  onPressed: onMorePressed,
                  tooltip: '$displayName 채팅방 메뉴',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: Icon(Icons.more_horiz_rounded, color: muted),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String? avatarUrl) {
    final theme = Theme.of(context);
    if (room.type == ChatRoomType.group) {
      return CircleAvatar(
        radius: 24.r,
        backgroundColor: AppTheme.actionContainer,
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null
            ? Icon(Icons.group, size: 24.w, color: AppTheme.actionBase)
            : null,
      );
    }

    return CircleAvatar(
      radius: 24.r,
      backgroundColor: theme.brightness == Brightness.dark
          ? theme.colorScheme.surfaceContainerHighest
          : AppTheme.actionContainer,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
      child: avatarUrl == null
          ? Icon(Icons.person, size: 24.w, color: AppTheme.actionBase)
          : null,
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 0) {
      if (diff.inDays == 1) return '어제';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dateTime.month}/${dateTime.day}';
    }

    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    if (hour < 12) {
      return '오전 ${hour == 0 ? 12 : hour}:$minute';
    } else {
      return '오후 ${hour == 12 ? 12 : hour - 12}:$minute';
    }
  }
}
