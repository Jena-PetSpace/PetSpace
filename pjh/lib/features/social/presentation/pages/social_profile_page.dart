import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SocialProfilePage extends StatelessWidget {
  final String userId;

  const SocialProfilePage({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50.r,
              child: Text(userId.substring(0, 1).toUpperCase(), style: TextStyle(fontSize: 32.sp)),
            ),
            SizedBox(height: 16.h),
            Text(
              '사용자 ID: $userId',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            Text('프로필 정보가 여기에 표시됩니다.', style: TextStyle(fontSize: 14.sp)),
          ],
        ),
      ),
    );
  }
}