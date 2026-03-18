import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _pushEnabled = true;
  bool _likeNotification = true;
  bool _commentNotification = true;
  bool _followNotification = true;
  bool _chatNotification = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림 설정'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('푸시 알림', style: TextStyle(fontSize: 14.sp)),
            subtitle:
                Text('전체 푸시 알림을 켜거나 끕니다', style: TextStyle(fontSize: 12.sp)),
            value: _pushEnabled,
            onChanged: (value) {
              setState(() => _pushEnabled = value);
            },
          ),
          const Divider(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Text(
              '알림 유형',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          SwitchListTile(
            title: Text('좋아요', style: TextStyle(fontSize: 14.sp)),
            subtitle:
                Text('내 게시물에 좋아요가 달리면 알림', style: TextStyle(fontSize: 12.sp)),
            value: _likeNotification && _pushEnabled,
            onChanged: _pushEnabled
                ? (value) => setState(() => _likeNotification = value)
                : null,
          ),
          SwitchListTile(
            title: Text('댓글', style: TextStyle(fontSize: 14.sp)),
            subtitle:
                Text('내 게시물에 댓글이 달리면 알림', style: TextStyle(fontSize: 12.sp)),
            value: _commentNotification && _pushEnabled,
            onChanged: _pushEnabled
                ? (value) => setState(() => _commentNotification = value)
                : null,
          ),
          SwitchListTile(
            title: Text('팔로우', style: TextStyle(fontSize: 14.sp)),
            subtitle:
                Text('누군가 나를 팔로우하면 알림', style: TextStyle(fontSize: 12.sp)),
            value: _followNotification && _pushEnabled,
            onChanged: _pushEnabled
                ? (value) => setState(() => _followNotification = value)
                : null,
          ),
          SwitchListTile(
            title: Text('채팅', style: TextStyle(fontSize: 14.sp)),
            subtitle:
                Text('새 채팅 메시지가 오면 알림', style: TextStyle(fontSize: 12.sp)),
            value: _chatNotification && _pushEnabled,
            onChanged: _pushEnabled
                ? (value) => setState(() => _chatNotification = value)
                : null,
          ),
        ],
      ),
    );
  }
}
