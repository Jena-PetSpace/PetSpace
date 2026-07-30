import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_state_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
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
import '../widgets/social_user_actions_sheet.dart';

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
    result.fold((_) {}, (pets) {
      if (mounted) setState(() => _pets = pets);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('프로필'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isOwnProfile)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: '설정',
              onPressed: () => context.push('/settings/my'),
            )
          else
            IconButton(
              key: const Key('profile_user_actions'),
              icon: const Icon(Icons.more_horiz),
              tooltip: '사용자 신고 및 차단',
              onPressed: _showProfileUserActions,
            ),
        ],
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
            return const ProfileShimmerLoading();
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
    final theme = Theme.of(context);
    final user = state.user;
    final isOwn = _isOwnProfile || widget.currentUserId == user.id;
    return Column(
      children: [
        _buildProfileHeader(user, state.isFollowing, isOwn),
        if (isOwn && _pets.isNotEmpty) _buildPetSwitcher(),
        Expanded(
          child: Container(
            color: theme.colorScheme.surface,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final identityColor =
        isDark ? theme.colorScheme.onSurface : AppTheme.primaryTextColor;
    final mutedColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppTheme.secondaryTextColor;
    final accentColor =
        isDark ? theme.colorScheme.primary : AppTheme.actionBase;
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
          color: theme.colorScheme.surface,
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
                      backgroundColor: isDark
                          ? theme.colorScheme.surfaceContainerHighest
                          : AppTheme.subtleBackground,
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
                                color: accentColor,
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
                            color: identityColor,
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
                              color: accentColor,
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
                              color: mutedColor,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor =
        isDark ? theme.colorScheme.primary : AppTheme.actionBase;
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
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              child: const Icon(Icons.settings_outlined),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
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
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(48.h),
              backgroundColor: isFollowing
                  ? theme.colorScheme.surfaceContainerHighest
                  : accentColor,
              foregroundColor: isFollowing ? accentColor : Colors.white,
              disabledBackgroundColor: accentColor.withValues(
                alpha: 0.7,
              ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor =
        isDark ? theme.colorScheme.primary : AppTheme.actionBase;
    final mutedColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppTheme.secondaryTextColor;
    return Container(
      color: theme.colorScheme.surface,
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
                              ? accentColor
                              : (isDark
                                  ? theme.colorScheme.surfaceContainerHighest
                                  : AppTheme.subtleBackground),
                          borderRadius: BorderRadius.circular(19.r),
                          border: Border.all(
                            color: selected
                                ? accentColor
                                : (isDark
                                    ? theme.colorScheme.outlineVariant
                                    : AppTheme.dividerColor),
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
                                            : accentColor,
                                      ),
                              ),
                            if (!isAll) SizedBox(width: 6.w),
                            Text(
                              isAll ? '전체' : pet!.name,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : mutedColor,
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
              color: accentColor,
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
    return PetSpaceStateView.error(
      key: const Key('profile_error_state'),
      icon: Icons.cloud_off_outlined,
      title: '프로필을 불러오지 못했어요',
      message: '연결 상태를 확인하고 다시 시도해주세요.',
      actionLabel: '다시 시도',
      onAction: () {
        context.read<ProfileBloc>().add(
              LoadUserProfileRequested(
                userId: widget.userId,
                currentUserId: widget.currentUserId,
              ),
            );
      },
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
                followerId: currentUserId, followingId: userId),
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

  Future<void> _showProfileUserActions() async {
    final currentUserId =
        widget.currentUserId ?? Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;
    final state = context.read<ProfileBloc>().state;
    final targetName =
        state is ProfileLoaded ? state.user.displayName : '이 사용자';
    final repository = widget.socialRepository ?? sl<SocialRepository>();
    await SocialUserActionsSheet.show(
      context,
      targetUserId: widget.userId,
      targetUserName: targetName,
      currentUserId: currentUserId,
      repository: repository,
      onBlocked: () {
        if (mounted && context.canPop()) context.pop(true);
      },
    );
  }

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
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }
}
