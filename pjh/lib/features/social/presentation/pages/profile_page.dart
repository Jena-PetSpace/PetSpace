import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/social_user.dart';
import '../bloc/profile_bloc.dart';
import '../widgets/profile_stats_card.dart';
import '../widgets/user_posts_list.dart';

class ProfilePage extends StatefulWidget {
  final String userId;
  final String? currentUserId;

  const ProfilePage({
    super.key,
    required this.userId,
    this.currentUserId,
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

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          expandedHeight: 300.h,
          floating: false,
          pinned: true,
          backgroundColor: AppTheme.primaryColor,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildProfileHeader(user, state.isFollowing, isOwnProfile),
          ),
        ),
      ],
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '게시물', icon: Icon(Icons.grid_on)),
              Tab(text: '팔로워', icon: Icon(Icons.people)),
              Tab(text: '팔로잉', icon: Icon(Icons.person_add)),
            ],
          ),
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
      ),
    );
  }

  Widget _buildProfileHeader(SocialUser user, bool isFollowing, bool isOwnProfile) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 20.h),
            CircleAvatar(
              radius: 50.r,
              backgroundImage: user.profileImageUrl != null
                  ? CachedNetworkImageProvider(user.profileImageUrl!)
                  : null,
              child: user.profileImageUrl == null
                  ? Text(
                      user.displayName.isNotEmpty ? user.displayName[0] : '?',
                      style: TextStyle(fontSize: 32.sp, color: Colors.white),
                    )
                  : null,
            ),
            SizedBox(height: 16.h),
            Text(
              user.displayName,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '@${user.username}',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.white70,
              ),
            ),
            if (user.bio != null) ...[
              SizedBox(height: 8.h),
              Text(
                user.bio!,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 16.h),
            ProfileStatsCard(
              postsCount: user.postsCount,
              followersCount: user.followersCount,
              followingCount: user.followingCount,
            ),
            SizedBox(height: 16.h),
            _buildActionButtons(user, isFollowing, isOwnProfile),
          ],
        ),
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
      context.read<ProfileBloc>().add(FollowUserRequested(
        followerId: currentUserId,
        followingId: userId,
      ));
    }
  }

  void _editProfile() {
    Navigator.pushNamed(context, '/edit-profile');
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