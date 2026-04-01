import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../social/presentation/pages/followers_page.dart';

class MyProfileHeader extends StatefulWidget {
  final dynamic user;

  const MyProfileHeader({super.key, required this.user});

  @override
  State<MyProfileHeader> createState() => _MyProfileHeaderState();
}

class _MyProfileHeaderState extends State<MyProfileHeader> {
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = sl<ProfileService>().getProfileStats();
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.user.photoURL as String?;
    final displayName = (widget.user.displayName as String?) ?? '사용자';

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
            decoration: const BoxDecoration(
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
          SizedBox(height: 8.h),

          // 프로필 편집 버튼
          OutlinedButton(
            onPressed: () => context.push('/profile/edit'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primaryColor, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 6.h),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '프로필 편집',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // 통계 3칸 — 실데이터
          FutureBuilder<Map<String, dynamic>>(
            future: _statsFuture,
            builder: (context, snapshot) {
              final posts = snapshot.data?['posts'] ?? 0;
              final followers = snapshot.data?['followers'] ?? 0;
              final following = snapshot.data?['following'] ?? 0;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat('게시글', '$posts'),
                  _buildDivider(),
                  GestureDetector(
                    onTap: () => _navigateToFollowers(context, 0),
                    child: _buildStat('팔로워', '$followers'),
                  ),
                  _buildDivider(),
                  GestureDetector(
                    onTap: () => _navigateToFollowers(context, 1),
                    child: _buildStat('팔로잉', '$following'),
                  ),
                ],
              );
            },
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

  void _navigateToFollowers(BuildContext context, int initialTab) {
    final userId = widget.user.uid as String? ?? '';
    final userName = (widget.user.displayName as String?) ?? '사용자';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FollowersPage(
          userId: userId,
          userName: userName,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30.h,
      color: AppTheme.dividerColor,
    );
  }
}
