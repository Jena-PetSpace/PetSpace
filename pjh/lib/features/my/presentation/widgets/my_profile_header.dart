import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/themes/app_theme.dart';

class MyProfileHeader extends StatelessWidget {
  final dynamic user;

  const MyProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photoURL as String?;
    final displayName = (user.displayName as String?) ?? '사용자';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          // 프로필 사진
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
            ),
            padding: const EdgeInsets.all(2),
            child: CircleAvatar(
              radius: 30.r,
              backgroundColor: Colors.white,
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(photoUrl)
                  : null,
              child: photoUrl == null || photoUrl.isEmpty
                  ? Icon(Icons.person, size: 30.w, color: AppTheme.primaryColor)
                  : null,
            ),
          ),
          SizedBox(height: 12.h),

          // 닉네임
          Text(
            displayName,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 16.h),

          // 통계 3칸
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat('게시글', '0'),
              _buildDivider(),
              _buildStat('팔로워', '0'),
              _buildDivider(),
              _buildStat('팔로잉', '0'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTextColor,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: AppTheme.secondaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30.h,
      color: const Color(0xFFE0E0E0),
    );
  }
}
