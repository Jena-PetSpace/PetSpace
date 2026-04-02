import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../auth/domain/entities/user.dart';
import 'settings_bottom_sheet.dart';

class MyProfileHeader extends StatefulWidget {
  final User user;
  final VoidCallback? onPostsTapped;

  const MyProfileHeader({super.key, required this.user, this.onPostsTapped});

  @override
  State<MyProfileHeader> createState() => _MyProfileHeaderState();
}

class _MyProfileHeaderState extends State<MyProfileHeader> {
  late Future<Map<String, int>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = sl<ProfileService>().getProfileStats();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final photoUrl = user.photoURL;
    final displayName = user.displayName.isNotEmpty ? user.displayName : '사용자';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor, AppTheme.accentColor],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 Row: MY 타이틀 + 설정 버튼
          Row(
            children: [
              Text('MY',
                  style: TextStyle(
                      fontSize: 15.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              InkWell(
                onTap: () => SettingsBottomSheet.show(context),
                borderRadius: BorderRadius.circular(17.r),
                child: Container(
                  width: 34.w,
                  height: 34.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.settings_outlined, size: 20.w, color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // 아바타 + 정보 Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 아바타
              Container(
                width: 72.w,
                height: 72.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.25),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5), width: 2.5),
                ),
                child: ClipOval(
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _buildInitialAvatar(initial),
                        )
                      : _buildInitialAvatar(initial),
                ),
              ),
              SizedBox(width: 14.w),

              // 이름 + 핸들 + 바이오
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.w500)),
                    SizedBox(height: 3.h),
                    Text(
                      '@${user.email.split('@').first} · 레벨 1 견주',
                      style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '반려동물 이야기를 들려주세요 🐾',
                      style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.white.withValues(alpha: 0.75),
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8.h),
                    // 포인트 배지
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text('0 P',
                          style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),

          // 통계 바 (게시글 | 팔로워 | 팔로잉)
          FutureBuilder<Map<String, int>>(
            future: _statsFuture,
            builder: (context, snapshot) {
              final posts = snapshot.data?['posts'] ?? 0;
              final followers = snapshot.data?['followers'] ?? 0;
              final following = snapshot.data?['following'] ?? 0;
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onPostsTapped,
                        child: _buildStat('$posts', '게시글'),
                      ),
                    ),
                    Container(width: 0.5, height: 36.h,
                        color: Colors.white.withValues(alpha: 0.2)),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/followers/${user.uid}'),
                        child: _buildStat('$followers', '팔로워'),
                      ),
                    ),
                    Container(width: 0.5, height: 36.h,
                        color: Colors.white.withValues(alpha: 0.2)),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/following/${user.uid}'),
                        child: _buildStat('$following', '팔로잉'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 12.h),

          // 프로필 편집 버튼
          GestureDetector(
            onTap: () => context.push('/my/edit-profile'),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Text('프로필 편집',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialAvatar(String initial) {
    return Container(
      color: Colors.white.withValues(alpha: 0.3),
      child: Center(
        child: Text(initial,
            style: TextStyle(
                fontSize: 28.sp,
                color: Colors.white,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 17.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w500)),
          SizedBox(height: 2.h),
          Text(label,
              style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.white.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}
