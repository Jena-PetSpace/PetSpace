import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class UserProfilePage extends StatelessWidget {
  final String userId;

  const UserProfilePage({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 프로필'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50.r,
              child: Icon(Icons.person, size: 50.w),
            ),
            SizedBox(height: 16.h),
            Text(
              '사용자 ID: $userId',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              '사용자 정보가 여기에 표시됩니다.',
              style: TextStyle(color: Colors.grey, fontSize: 14.sp),
            ),
          ],
        ),
      ),
    );
  }
}