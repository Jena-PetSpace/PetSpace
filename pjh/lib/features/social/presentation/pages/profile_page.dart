import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../chat/domain/repositories/chat_repository.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/domain/repositories/pet_repository.dart';
import '../../domain/entities/follow.dart';
import '../../domain/entities/social_user.dart';
import '../../domain/repositories/social_repository.dart';
import '../bloc/profile_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/profile_cover.dart';
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
  bool _isSendingMessage = false;
  String? _selectedPetId;
  List<Pet> _pets = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<ProfileBloc>().add(LoadUserProfileRequested(
          userId: widget.userId,
          currentUserId: widget.currentUserId,
        ));
    _loadPets();
  }

  Future<void> _loadPets() async {
    final result = await sl<PetRepository>().getUserPets(widget.userId);
    result.fold(
      (_) {},
      (pets) {
        if (mounted) setState(() => _pets = pets);
      },
    );
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
        // 펫 스위처 칩 행
        if (_pets.isNotEmpty) _buildPetSwitcher(),
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
              UserPostsList(
                  userId: user.id,
                  isMyProfile: isOwnProfile,
                  petId: _selectedPetId),
              _buildFollowersList(),
              _buildFollowingList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPetSwitcher() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: _pets.length + 1,
                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                itemBuilder: (context, index) {
                  final isAll = index == 0;
                  final pet = isAll ? null : _pets[index - 1];
                  final selected = isAll
                      ? _selectedPetId == null
                      : pet!.id == _selectedPetId;

                  final label = isAll ? '전체' : (pet!.name);
                  final imageUrl = isAll ? null : pet!.avatarUrl;
                  final petId = isAll ? null : pet!.id;
                  final petName = isAll ? null : pet!.name;

                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedPetId = isAll ? null : petId;
                    }),
                    onLongPress: isAll || petId == null ? null : () {
                      context.push('/emotion-timeline', extra: {
                        'petId': petId,
                        'petName': petName ?? label,
                        'petAvatarUrl': imageUrl,
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primaryColor
                            : AppTheme.subtleBackground,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: selected
                              ? AppTheme.primaryColor
                              : AppTheme.dividerColor,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isAll && imageUrl != null) ...[
                            CircleAvatar(
                              radius: 10.r,
                              backgroundImage: CachedNetworkImageProvider(imageUrl),
                            ),
                            SizedBox(width: 6.w),
                          ] else if (!isAll) ...[
                            Text(
                              pet!.type == PetType.cat ? '🐱' : '🐶',
                              style: const TextStyle(fontSize: 14),
                            ),
                            SizedBox(width: 4.w),
                          ],
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // 선택된 펫의 AI 타임라인 바로가기
          if (_selectedPetId != null)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: GestureDetector(
                onTap: () {
                  final matched =
                      _pets.where((p) => p.id == _selectedPetId).toList();
                  if (matched.isEmpty) return;
                  final pet = matched.first;
                  context.push('/emotion-timeline', extra: {
                    'petId': _selectedPetId!,
                    'petName': pet.name,
                    'petAvatarUrl': pet.avatarUrl,
                  });
                },
                child: Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.analytics_outlined,
                      size: 18.w, color: AppTheme.primaryColor),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
      SocialUser user, bool isFollowing, bool isOwnProfile) {
    // 상대방 프로필 + 커버 이미지 없음 → 빈 공간 숨김
    final hasCover =
        user.coverImageUrl != null && user.coverImageUrl!.isNotEmpty;
    final showCover = isOwnProfile || hasCover;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCover)
          ProfileCover(
            coverImageUrl: user.coverImageUrl,
            canEdit: isOwnProfile,
            onImagePicked: (file) {
              final userId = widget.currentUserId ??
                  Supabase.instance.client.auth.currentUser?.id;
              if (userId == null) return;
              context.read<ProfileBloc>().add(UpdateCoverImageRequested(
                    userId: userId,
                    file: file,
                  ));
            },
          ),
        Container(
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
                  style: TextStyle(fontSize: 12.sp, color: Colors.white70),
                ),
              ],
              if (user.bio != null && user.bio!.isNotEmpty) ...[
                SizedBox(height: 6.h),
                Text(
                  user.bio!,
                  style: TextStyle(fontSize: 12.sp, color: Colors.white70),
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
        ),
      ],
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
              foregroundColor: AppTheme.primaryTextColor,
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
          onPressed: _isSendingMessage ? null : () => _sendMessage(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            foregroundColor: AppTheme.primaryTextColor,
          ),
          child: _isSendingMessage
              ? SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(Icons.message, size: 24.w),
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
    return FutureBuilder<List<Follow>>(
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
            final follow = list[index];
            final uid =
                isFollowers ? follow.followerId : follow.followingId;
            final displayName = isFollowers
                ? follow.followerName
                : follow.followingName;
            final photoUrl = isFollowers
                ? follow.followerProfileImage
                : follow.followingProfileImage;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                backgroundImage:
                    photoUrl != null && photoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(photoUrl)
                        : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? Icon(Icons.person,
                        color: AppTheme.primaryColor, size: 20.w)
                    : null,
              ),
              title: Text(
                displayName.isEmpty ? '사용자' : displayName,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
              onTap: () => context.push('/user-profile/$uid'),
            );
          },
        );
      },
    );
  }

  Future<List<Follow>> _loadFollowData(bool isFollowers) async {
    final repo = sl<SocialRepository>();
    final result = isFollowers
        ? await repo.getFollowers(widget.userId)
        : await repo.getFollowing(widget.userId);
    return result.fold((failure) {
      log('팔로우 데이터 로드 실패: ${failure.message}', name: 'ProfilePage');
      return <Follow>[];
    }, (list) => list);
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

    setState(() => _isSendingMessage = true);

    final result = await sl<ChatRepository>().createDirectChat(
      currentUserId: currentUserId,
      otherUserId: user.id,
    );

    if (!mounted) return;
    setState(() => _isSendingMessage = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('채팅방 생성에 실패했습니다.')),
        );
      },
      (room) {
        context.push(
            '/chat/${room.id}?name=${Uri.encodeComponent(user.displayName)}');
      },
    );
  }
}
