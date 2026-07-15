import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../chat/domain/repositories/chat_repository.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/domain/repositories/pet_repository.dart';
import '../../domain/entities/social_user.dart';
import '../../domain/repositories/social_repository.dart';
import '../bloc/profile_bloc.dart';
import '../widgets/profile_cover.dart';
import '../widgets/profile_stats_card.dart';
import '../widgets/user_posts_list.dart';

class ProfilePage extends StatefulWidget {
  final String userId;
  final String? currentUserId;
  final bool isMyProfile;
  final PetRepository? petRepository;
  final ChatRepository? chatRepository;
  final SocialRepository? socialRepository;

  const ProfilePage({
    super.key,
    required this.userId,
    this.currentUserId,
    this.isMyProfile = false,
    this.petRepository,
    this.chatRepository,
    this.socialRepository,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isSendingMessage = false;
  bool _isFollowPending = false;
  String? _selectedPetId;
  List<Pet> _pets = [];

  bool get _isOwnProfile =>
      widget.isMyProfile ||
      (widget.currentUserId != null && widget.currentUserId == widget.userId);

  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(
          LoadUserProfileRequested(
            userId: widget.userId,
            currentUserId: widget.currentUserId,
          ),
        );
    if (_isOwnProfile) {
      _loadPets();
    }
  }

  Future<void> _loadPets() async {
    final repository = widget.petRepository ?? sl<PetRepository>();
    final result = await repository.getUserPets(widget.userId);
    result.fold(
      (_) {},
      (pets) {
        if (mounted) setState(() => _pets = pets);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('프로필'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryTextColor,
        elevation: 0,
        actions: _isOwnProfile
            ? [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: '설정',
                  onPressed: () => context.push('/settings/my'),
                ),
              ]
            : null,
      ),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoaded) {
            if (_isFollowPending) {
              setState(() => _isFollowPending = false);
            }
            if (state.error != null) {
              _showSafeMessage('요청을 완료하지 못했어요. 잠시 후 다시 시도해주세요.');
            }
          } else if (state is ProfileError && _isFollowPending) {
            setState(() => _isFollowPending = false);
          }
        },
        builder: (context, state) {
          if (state is ProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ProfileLoaded) {
            return _buildProfileContent(state);
          }
          if (state is ProfileError) {
            return _buildErrorState();
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildProfileContent(ProfileLoaded state) {
    final user = state.user;
    final isOwn = _isOwnProfile || widget.currentUserId == user.id;
    return Column(
      children: [
        _buildProfileHeader(user, state.isFollowing, isOwn),
        if (isOwn && _pets.isNotEmpty) _buildPetSwitcher(),
        Expanded(
          child: Container(
            color: Colors.white,
            child: UserPostsList(
              userId: user.id,
              isMyProfile: isOwn,
              petId: isOwn ? _selectedPetId : null,
              repository: widget.socialRepository,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(
    SocialUser user,
    bool isFollowing,
    bool isOwnProfile,
  ) {
    final profileImage = user.profileImageUrl?.trim();
    final hasProfileImage = profileImage != null && profileImage.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isOwnProfile)
          ProfileCover(
            coverImageUrl: user.coverImageUrl,
            canEdit: true,
            onImagePicked: (file) {
              final userId = widget.currentUserId ??
                  Supabase.instance.client.auth.currentUser?.id;
              if (userId == null) return;
              context.read<ProfileBloc>().add(
                    UpdateCoverImageRequested(userId: userId, file: file),
                  );
            },
          ),
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 16.h),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Semantics(
                    image: true,
                    label: '${user.displayName} 프로필 사진',
                    child: CircleAvatar(
                      radius: 36.r,
                      backgroundColor: AppTheme.subtleBackground,
                      backgroundImage: hasProfileImage
                          ? CachedNetworkImageProvider(profileImage)
                          : null,
                      child: hasProfileImage
                          ? null
                          : Text(
                              user.displayName.trim().isEmpty
                                  ? '?'
                                  : user.displayName.trim().substring(0, 1),
                              style: TextStyle(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                        if (user.username?.trim().isNotEmpty == true) ...[
                          SizedBox(height: 3.h),
                          Text(
                            '@${user.username!.trim()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                        if (user.bio?.trim().isNotEmpty == true) ...[
                          SizedBox(height: 8.h),
                          Text(
                            user.bio!.trim(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.sp,
                              height: 1.45,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              ProfileStatsCard(
                postsCount: user.postsCount,
                followersCount: user.followersCount,
                followingCount: user.followingCount,
                onFollowersTap: () => _openFollowList(user, initialTab: 0),
                onFollowingTap: () => _openFollowList(user, initialTab: 1),
              ),
              SizedBox(height: 12.h),
              _buildActionButtons(user, isFollowing, isOwnProfile),
            ],
          ),
        ),
      ],
    );
  }

  void _openFollowList(SocialUser user, {required int initialTab}) {
    final route = initialTab == 0 ? '/followers/' : '/following/';
    context.push(
      '$route${user.id}?name=${Uri.encodeComponent(user.displayName)}',
    );
  }

  Widget _buildActionButtons(
    SocialUser user,
    bool isFollowing,
    bool isOwnProfile,
  ) {
    if (isOwnProfile) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('프로필 편집'),
              style: OutlinedButton.styleFrom(
                minimumSize: Size.fromHeight(48.h),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          SizedBox(
            width: 52.w,
            height: 48.h,
            child: OutlinedButton(
              onPressed: _showSettings,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.settings_outlined),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            key: const Key('profile_follow_button'),
            onPressed: _isFollowPending
                ? null
                : () => _toggleFollow(user.id, isFollowing),
            icon: _isFollowPending
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isFollowing ? Icons.check : Icons.person_add_alt_1,
                    size: 19.w,
                  ),
            label: Text(isFollowing ? '팔로우 중' : '팔로우'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size.fromHeight(48.h),
              elevation: 0,
              backgroundColor: isFollowing
                  ? AppTheme.subtleBackground
                  : AppTheme.primaryColor,
              foregroundColor:
                  isFollowing ? AppTheme.primaryColor : Colors.white,
              disabledBackgroundColor:
                  AppTheme.primaryColor.withValues(alpha: 0.7),
              disabledForegroundColor: Colors.white,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        SizedBox(
          width: 52.w,
          height: 48.h,
          child: OutlinedButton(
            key: const Key('profile_message_button'),
            onPressed: _isSendingMessage ? null : () => _sendMessage(user),
            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
            child: _isSendingMessage
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chat_bubble_outline),
          ),
        ),
      ],
    );
  }

  Widget _buildPetSwitcher() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38.h,
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
                  final imageUrl = pet?.avatarUrl?.trim();
                  final hasImage = imageUrl != null && imageUrl.isNotEmpty;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: isAll ? '전체 반려동물' : pet!.name,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(19.r),
                      onTap: () => setState(
                        () => _selectedPetId = isAll ? null : pet!.id,
                      ),
                      onLongPress:
                          isAll ? null : () => _openEmotionTimeline(pet!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primaryColor
                              : AppTheme.subtleBackground,
                          borderRadius: BorderRadius.circular(19.r),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primaryColor
                                : AppTheme.dividerColor,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isAll)
                              CircleAvatar(
                                radius: 10.r,
                                backgroundColor: selected
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : Colors.white,
                                backgroundImage: hasImage
                                    ? CachedNetworkImageProvider(imageUrl)
                                    : null,
                                child: hasImage
                                    ? null
                                    : Icon(
                                        Icons.pets,
                                        size: 12.w,
                                        color: selected
                                            ? Colors.white
                                            : AppTheme.primaryColor,
                                      ),
                              ),
                            if (!isAll) SizedBox(width: 6.w),
                            Text(
                              isAll ? '전체' : pet!.name,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppTheme.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_selectedPetId != null)
            IconButton(
              tooltip: '선택한 반려동물 감정 타임라인',
              onPressed: () {
                final matches =
                    _pets.where((pet) => pet.id == _selectedPetId).toList();
                if (matches.isNotEmpty) _openEmotionTimeline(matches.first);
              },
              icon: const Icon(Icons.analytics_outlined),
              color: AppTheme.primaryColor,
            ),
        ],
      ),
    );
  }

  void _openEmotionTimeline(Pet pet) {
    context.push(
      '/emotion-timeline',
      extra: {
        'petId': pet.id,
        'petName': pet.name,
        'petAvatarUrl': pet.avatarUrl,
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48.w,
              color: AppTheme.lightTextColor,
            ),
            SizedBox(height: 14.h),
            Text(
              '프로필을 불러오지 못했어요',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '연결 상태를 확인하고 다시 시도해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.secondaryTextColor,
              ),
            ),
            SizedBox(height: 16.h),
            OutlinedButton.icon(
              key: const Key('profile_retry_button'),
              onPressed: () {
                context.read<ProfileBloc>().add(
                      LoadUserProfileRequested(
                        userId: widget.userId,
                        currentUserId: widget.currentUserId,
                      ),
                    );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFollow(String userId, bool isCurrentlyFollowing) {
    final currentUserId =
        widget.currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || _isFollowPending) return;
    setState(() => _isFollowPending = true);

    if (isCurrentlyFollowing) {
      context.read<ProfileBloc>().add(
            UnfollowUserRequested(
              followerId: currentUserId,
              followingId: userId,
            ),
          );
    } else {
      final authState = context.read<AuthBloc>().state;
      final myName =
          authState is AuthAuthenticated ? authState.user.displayName : '사용자';
      context.read<ProfileBloc>().add(
            FollowUserRequested(
              followerId: currentUserId,
              followingId: userId,
              followerName: myName,
            ),
          );
    }
  }

  Future<void> _editProfile() async {
    final updated = await context.push<bool>('/my/edit-profile');
    if (updated == true && mounted) {
      context.read<ProfileBloc>().add(
            LoadUserProfileRequested(
              userId: widget.userId,
              currentUserId: widget.currentUserId,
            ),
          );
    }
  }

  void _showSettings() => context.push('/settings/my');

  Future<void> _sendMessage(SocialUser user) async {
    final currentUserId =
        widget.currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || _isSendingMessage) return;
    setState(() => _isSendingMessage = true);

    final repository = widget.chatRepository ?? sl<ChatRepository>();
    final result = await repository.createDirectChat(
      currentUserId: currentUserId,
      otherUserId: user.id,
    );
    if (!mounted) return;
    setState(() => _isSendingMessage = false);
    result.fold(
      (_) => _showSafeMessage('채팅방을 열지 못했어요. 잠시 후 다시 시도해주세요.'),
      (room) => context.push(
        '/chat/${room.id}?name=${Uri.encodeComponent(user.displayName)}',
      ),
    );
  }

  void _showSafeMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }
}
