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

  const UserListTile({
    super.key,
    required this.userId,
    required this.userName,
    this.userProfileImage,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20.r,
        backgroundImage: userProfileImage != null
            ? CachedNetworkImageProvider(userProfileImage!)
            : null,
        child: userProfileImage == null
            ? Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
              )
            : null,
      ),
      title: Text(
        userName,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp),
      ),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 12.sp)) : null,
      trailing: trailing ?? Icon(Icons.chevron_right, size: 20.w),
      onTap: onTap,
    );
  }
}
