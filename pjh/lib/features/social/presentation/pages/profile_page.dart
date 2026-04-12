import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

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

  Widget _buildProfileHeader(
      SocialUser user, bool isFollowing, bool isOwnProfile) {
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

  Widget _buildActionButtons(
      SocialUser user, bool isFollowing, bool isOwnProfile) {
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
            icon: Icon(isFollowing ? Icons.check : Icons.person_add,
                size: 20.w),
            label: Text(isFollowing ? '팔로우 중' : '팔로우',
                style: TextStyle(fontSize: 14.sp)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing ? Colors.grey : Colors.white,
              foregroundColor:
                  isFollowing ? Colors.white : AppTheme.primaryColor,
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
    return _buildFollowList(isFollowers: true);
  }

  Widget _buildFollowingList() {
    return _buildFollowList(isFollowers: false);
  }

  Widget _buildFollowList({required bool isFollowers}) {
    return FutureBuilder<List<dynamic>>(
      future: _loadFollowData(isFollowers),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 48.w, color: Colors.grey[300]),
                SizedBox(height: 12.h),
                Text(
                  isFollowers ? '아직 팔로워가 없습니다' : '아직 팔로잉이 없습니다',
                  style: TextStyle(
                      fontSize: 14.sp, color: AppTheme.secondaryTextColor),
                ),
              ],
            ),
          );
        }
        final list = snapshot.data!;
        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index] as Map<String, dynamic>;
            final user = isFollowers
                ? item['follower'] as Map<String, dynamic>?
                : item['following'] as Map<String, dynamic>?;
            if (user == null) return const SizedBox.shrink();
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                backgroundImage: user['photo_url'] != null &&
                        (user['photo_url'] as String).isNotEmpty
                    ? CachedNetworkImageProvider(user['photo_url'] as String)
                    : null,
                child: user['photo_url'] == null ||
                        (user['photo_url'] as String).isEmpty
                    ? Icon(Icons.person,
                        color: AppTheme.primaryColor, size: 20.w)
                    : null,
              ),
              title: Text(
                user['display_name'] as String? ?? '사용자',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                final uid = isFollowers
                    ? item['follower_id'] as String
                    : item['following_id'] as String;
                context.push('/user-profile/$uid');
              },
            );
          },
        );
      },
    );
  }

  Future<List<dynamic>> _loadFollowData(bool isFollowers) async {
    try {
      final supabase = Supabase.instance.client;
      if (isFollowers) {
        return await supabase
            .from('follows')
            .select(
                'follower_id, follower:users!follows_follower_id_fkey(display_name, photo_url)')
            .eq('following_id', widget.userId);
      } else {
        return await supabase
            .from('follows')
            .select(
                'following_id, following:users!follows_following_id_fkey(display_name, photo_url)')
            .eq('follower_id', widget.userId);
      }
    } catch (e) {
      log('팔로우 데이터 로드 실패: $e', name: 'ProfilePage');
      return [];
    }
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
    // currentUserId가 없으면 Supabase에서 직접 가져옴
    final currentUserId = widget.currentUserId ??
        Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    if (isCurrentlyFollowing) {
      context.read<ProfileBloc>().add(UnfollowUserRequested(
            followerId: currentUserId,
            followingId: userId,
          ));
    } else {
      final authState = context.read<AuthBloc>().state;
      final myName =
          authState is AuthAuthenticated ? authState.user.displayName : '사용자';
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
    context.push('/settings');
  }

  void _sendMessage(SocialUser user) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final supabase = Supabase.instance.client;

      // 기존 1:1 채팅방 찾기
      final existingRoomId = await supabase.rpc('find_direct_chat', params: {
        'p_user1_id': currentUserId,
        'p_user2_id': user.id,
      });

      String roomId;
      if (existingRoomId != null) {
        roomId = existingRoomId as String;
      } else {
        // 새 채팅방 생성
        final roomRes = await supabase
            .from('chat_rooms')
            .insert({'type': 'direct', 'created_by': currentUserId})
            .select()
            .single();
        roomId = roomRes['id'] as String;

        // 참여자 추가
        await supabase.from('chat_participants').insert([
          {'room_id': roomId, 'user_id': currentUserId, 'role': 'admin'},
          {'room_id': roomId, 'user_id': user.id, 'role': 'member'},
        ]);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/chat/$roomId?name=${Uri.encodeComponent(user.displayName)}');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('채팅방 생성에 실패했습니다.')),
      );
    }
  }
}
