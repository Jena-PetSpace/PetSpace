import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPrivateAccount = prefs.getBool('privacy_private_account') ?? false;
      _showOnlineStatus = prefs.getBool('privacy_show_online') ?? true;
      _allowSearchByEmail = prefs.getBool('privacy_search_by_email') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

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
              _saveSetting('privacy_private_account', value);
            },
          ),
          SwitchListTile(
            title: Text('온라인 상태 표시', style: TextStyle(fontSize: 14.sp)),
            subtitle: Text('다른 사용자에게 온라인 상태를 보여줍니다',
                style: TextStyle(fontSize: 12.sp)),
            value: _showOnlineStatus,
            onChanged: (value) {
              setState(() => _showOnlineStatus = value);
              _saveSetting('privacy_show_online', value);
            },
          ),
          SwitchListTile(
            title: Text('이메일로 검색 허용', style: TextStyle(fontSize: 14.sp)),
            subtitle: Text('다른 사용자가 이메일로 나를 찾을 수 있습니다',
                style: TextStyle(fontSize: 12.sp)),
            value: _allowSearchByEmail,
            onChanged: (value) {
              setState(() => _allowSearchByEmail = value);
              _saveSetting('privacy_search_by_email', value);
            },
          ),
        ],
      ),
    );
  }
}
