import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/social_user.dart';
import '../bloc/profile_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/profile_stats_card.dart';
import '../widgets/user_posts_list.dart';

class ProfilePage extends StatefulWidget {
  final String userId;
  final String? currentUserId;
  /// true면 상단에 설정 버튼 표시 (내 프로필 진입 시)
  final bool isMyProfile;

  const ProfilePage({
    super.key,
    required this.userId,
    this.currentUserId,
    this.isMyProfile = false,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<ProfileBloc>().add(LoadUserProfileRequested(
      userId: widget.userId,
      currentUserId: widget.currentUserId,
    ));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '프로필',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: widget.isMyProfile
            ? [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.push('/settings'),
                ),
              ]
            : null,
      ),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoaded && state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ProfileLoaded) {
            return _buildProfileContent(state);
          } else if (state is ProfileError) {
            return _buildErrorState(state.message);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildProfileContent(ProfileLoaded state) {
    final user = state.user;
    final isOwnProfile = widget.currentUserId == user.id;

    return Column(
      children: [
        // 프로필 헤더
        _buildProfileHeader(user, state.isFollowing, isOwnProfile),
        // 탭바
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.lightTextColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: '게시물', icon: Icon(Icons.grid_on, size: 20)),
            Tab(text: '팔로워', icon: Icon(Icons.people, size: 20)),
            Tab(text: '팔로잉', icon: Icon(Icons.person_add, size: 20)),
          ],
        ),
        // 탭 내용
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              UserPostsList(userId: user.id),
              _buildFollowersList(),
              _buildFollowingList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(SocialUser user, bool isFollowing, bool isOwnProfile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40.r,
            backgroundImage: user.profileImageUrl != null
                ? CachedNetworkImageProvider(user.profileImageUrl!)
                : null,
            child: user.profileImageUrl == null
                ? Text(
                    user.displayName.isNotEmpty ? user.displayName[0] : '?',
                    style: TextStyle(fontSize: 28.sp, color: Colors.white),
                  )
                : null,
          ),
          SizedBox(height: 10.h),
          Text(
            user.displayName,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (user.username != null && user.username!.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(
              '@${user.username}',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.white70,
              ),
            ),
          ],
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              user.bio!,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: 12.h),
          ProfileStatsCard(
            postsCount: user.postsCount,
            followersCount: user.followersCount,
            followingCount: user.followingCount,
          ),
          SizedBox(height: 12.h),
          _buildActionButtons(user, isFollowing, isOwnProfile),
        ],
      ),
    );
  }

  Widget _buildActionButtons(SocialUser user, bool isFollowing, bool isOwnProfile) {
    if (isOwnProfile) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _editProfile(),
              icon: const Icon(Icons.edit),
              label: Text('프로필 편집', style: TextStyle(fontSize: 14.sp)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          ElevatedButton(
            onPressed: () => _showSettings(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
            ),
            child: Icon(Icons.settings, size: 24.w),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _toggleFollow(user.id, isFollowing),
            icon: Icon(isFollowing ? Icons.person_remove : Icons.person_add, size: 20.w),
            label: Text(isFollowing ? '언팔로우' : '팔로우', style: TextStyle(fontSize: 14.sp)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing ? Colors.grey : Colors.white,
              foregroundColor: isFollowing ? Colors.white : AppTheme.primaryColor,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        ElevatedButton(
          onPressed: () => _sendMessage(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            foregroundColor: Colors.white,
          ),
          child: Icon(Icons.message, size: 24.w),
        ),
      ],
    );
  }

  Widget _buildFollowersList() {
    return Center(
      child: Text('팔로워 목록이 곧 추가됩니다!', style: TextStyle(fontSize: 14.sp)),
    );
  }

  Widget _buildFollowingList() {
    return Center(
      child: Text('팔로잉 목록이 곧 추가됩니다!', style: TextStyle(fontSize: 14.sp)),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.w,
            color: Colors.red,
          ),
          SizedBox(height: 16.h),
          Text(
            '오류가 발생했습니다',
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              context.read<ProfileBloc>().add(
                LoadUserProfileRequested(
                  userId: widget.userId,
                  currentUserId: widget.currentUserId,
                ),
              );
            },
            child: Text('다시 시도', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  void _toggleFollow(String userId, bool isCurrentlyFollowing) {
    final currentUserId = widget.currentUserId;
    if (currentUserId == null) return;

    if (isCurrentlyFollowing) {
      context.read<ProfileBloc>().add(UnfollowUserRequested(
        followerId: currentUserId,
        followingId: userId,
      ));
    } else {
      final authState = context.read<AuthBloc>().state;
      final myName = authState is AuthAuthenticated
          ? authState.user.displayName ?? '사용자'
          : '사용자';
      context.read<ProfileBloc>().add(FollowUserRequested(
        followerId: currentUserId,
        followingId: userId,
        followerName: myName,
      ));
    }
  }

  void _editProfile() async {
    final updated = await context.push<bool>('/profile/edit');
    if (updated == true && mounted) {
      // 프로필 정보 갱신
      context.read<ProfileBloc>().add(LoadUserProfileRequested(
        userId: widget.userId,
        currentUserId: widget.currentUserId,
      ));
    }
  }

  void _showSettings() {
    Navigator.pushNamed(context, '/settings');
  }

  void _sendMessage(SocialUser user) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('메시지 기능이 곧 추가됩니다!')),
    );
  }
}
