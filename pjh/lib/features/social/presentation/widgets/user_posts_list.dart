import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class UserPostsList extends StatelessWidget {
  final String userId;

  const UserPostsList({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.grid_on,
            size: 64.w,
            color: Colors.grey,
          ),
          SizedBox(height: 16.h),
          Text(
            '게시물이 없습니다',
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '첫 번째 게시물을 작성해보세요!',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}