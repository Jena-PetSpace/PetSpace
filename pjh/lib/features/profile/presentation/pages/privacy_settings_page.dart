import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _isPrivateAccount = false;
  bool _showOnlineStatus = true;
  bool _allowSearchByEmail = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('개인정보 보호'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('비공개 계정', style: TextStyle(fontSize: 14.sp)),
            subtitle: Text('승인된 팔로워만 내 게시물을 볼 수 있습니다',
                style: TextStyle(fontSize: 12.sp)),
            value: _isPrivateAccount,
            onChanged: (value) {
              setState(() => _isPrivateAccount = value);
            },
          ),
          SwitchListTile(
            title: Text('온라인 상태 표시', style: TextStyle(fontSize: 14.sp)),
            subtitle: Text('다른 사용자에게 온라인 상태를 보여줍니다',
                style: TextStyle(fontSize: 12.sp)),
            value: _showOnlineStatus,
            onChanged: (value) {
              setState(() => _showOnlineStatus = value);
            },
          ),
          SwitchListTile(
            title: Text('이메일로 검색 허용', style: TextStyle(fontSize: 14.sp)),
            subtitle: Text('다른 사용자가 이메일로 나를 찾을 수 있습니다',
                style: TextStyle(fontSize: 12.sp)),
            value: _allowSearchByEmail,
            onChanged: (value) {
              setState(() => _allowSearchByEmail = value);
            },
          ),
          const Divider(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Text(
              '데이터 관리',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.download, size: 24.w),
            title: Text('내 데이터 다운로드', style: TextStyle(fontSize: 14.sp)),
            subtitle: Text('게시물, 댓글 등 내 데이터를 다운로드합니다',
                style: TextStyle(fontSize: 12.sp)),
            trailing: Icon(Icons.chevron_right, size: 20.w),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('데이터 다운로드 기능은 준비 중입니다')),
              );
            },
          ),
        ],
      ),
    );
  }
}
