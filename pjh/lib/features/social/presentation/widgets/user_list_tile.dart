import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserListTile extends StatelessWidget {
  final String userId;
  final String userName;
  final String? userProfileImage;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onUserActions;

  const UserListTile({
    super.key,
    required this.userId,
    required this.userName,
    this.userProfileImage,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onUserActions,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = userProfileImage?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final fallback = userName.trim().isEmpty
        ? '?'
        : userName.trim().substring(0, 1).toUpperCase();

    return Semantics(
      button: onTap != null,
      label: '$userName 프로필 보기',
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 64.h),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          leading: Semantics(
            label: '$userName 프로필 사진',
            image: true,
            child: CircleAvatar(
              radius: 22.r,
              backgroundImage:
                  hasImage ? CachedNetworkImageProvider(imageUrl) : null,
              child: !hasImage
                  ? Text(
                      fallback,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14.sp),
                    )
                  : null,
            ),
          ),
          title: Text(
            userName,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailing != null)
                trailing!
              else
                Icon(Icons.chevron_right, size: 20.w),
              if (onUserActions != null)
                IconButton(
                  key: Key('user_actions_$userId'),
                  onPressed: onUserActions,
                  tooltip: '$userName 사용자 신고 및 차단',
                  icon: const Icon(Icons.more_horiz),
                ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
