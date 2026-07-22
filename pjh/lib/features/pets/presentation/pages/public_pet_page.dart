import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/injection_container.dart' as di;
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../../../shared/widgets/petspace_state_view.dart';
import '../../../social/domain/repositories/social_repository.dart';
import '../../domain/repositories/pet_repository.dart';

typedef PublicPetCurrentUserIdProvider = String? Function();
typedef PublicPetLinkCopier = Future<void> Function(String value);

class PublicPetPage extends StatefulWidget {
  final String petId;
  final PetRepository? petRepository;
  final SocialRepository? socialRepository;
  final PublicPetCurrentUserIdProvider? currentUserIdProvider;
  final PublicPetLinkCopier? linkCopier;

  const PublicPetPage({
    super.key,
    required this.petId,
    this.petRepository,
    this.socialRepository,
    this.currentUserIdProvider,
    this.linkCopier,
  });

  @override
  State<PublicPetPage> createState() => _PublicPetPageState();
}

class _PublicPetPageState extends State<PublicPetPage> {
  Map<String, dynamic>? _pet;
  bool _loading = true;
  bool _loadFailed = false;
  bool _followPending = false;
  bool _isFollowing = false;
  int? _followerCount;
  String? _ownerId;

  PetRepository get _petRepository =>
      widget.petRepository ?? di.sl<PetRepository>();
  SocialRepository get _socialRepository =>
      widget.socialRepository ?? di.sl<SocialRepository>();
  String? get _currentUserId =>
      widget.currentUserIdProvider?.call() ??
      Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });

    final petResult = await _petRepository.getPetDetail(widget.petId);
    final pet =
        petResult.fold<Map<String, dynamic>?>((_) => null, (data) => data);
    if (!mounted) return;
    if (pet == null) {
      setState(() {
        _pet = null;
        _ownerId = null;
        _loading = false;
        _loadFailed = petResult.isLeft();
      });
      return;
    }

    final ownerId = pet['user_id'] as String?;
    int? followerCount;
    bool isFollowing = false;
    if (ownerId != null) {
      final followersResult = await _socialRepository.getFollowers(ownerId);
      followerCount =
          followersResult.fold((_) => null, (items) => items.length);
      final viewerId = _currentUserId;
      if (viewerId != null && viewerId != ownerId) {
        final followingResult =
            await _socialRepository.isFollowing(viewerId, ownerId);
        isFollowing = followingResult.fold((_) => false, (value) => value);
      }
    }

    if (!mounted) return;
    setState(() {
      _pet = pet;
      _ownerId = ownerId;
      _followerCount = followerCount;
      _isFollowing = isFollowing;
      _loading = false;
    });
  }

  Future<void> _toggleFollow() async {
    final viewerId = _currentUserId;
    final ownerId = _ownerId;
    if (_followPending || viewerId == null || ownerId == null) return;
    if (viewerId == ownerId) return;

    setState(() => _followPending = true);
    final wasFollowing = _isFollowing;
    final result = wasFollowing
        ? await _socialRepository.unfollowUser(viewerId, ownerId)
        : await _socialRepository.followUser(viewerId, ownerId);
    if (!mounted) return;
    result.fold(
      (_) {
        setState(() => _followPending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: Key('public_pet_follow_error'),
            content: Text('팔로우 상태를 변경하지 못했어요. 다시 시도해주세요.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      },
      (_) {
        setState(() {
          _followPending = false;
          _isFollowing = !wasFollowing;
          if (_followerCount != null) {
            _followerCount = _followerCount! + (wasFollowing ? -1 : 1);
          }
        });
      },
    );
  }

  Future<void> _shareProfile() async {
    final link = 'https://petspace.app/pet/${widget.petId}';
    try {
      if (widget.linkCopier != null) {
        await widget.linkCopier!(link);
      } else {
        await Clipboard.setData(ClipboardData(text: link));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 링크를 복사했어요.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('링크를 복사하지 못했어요. 다시 시도해주세요.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PetSpacePageScaffold(
      title: '반려동물 프로필',
      actions: [
        IconButton(
          key: const Key('public_pet_share_button'),
          tooltip: '프로필 링크 복사',
          onPressed: _pet == null ? null : _shareProfile,
          icon: const Icon(Icons.ios_share_outlined),
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const PetSpaceStateView.loading(
        key: Key('public_pet_loading'),
      );
    }
    if (_loadFailed) {
      return PetSpaceStateView.error(
        key: const Key('public_pet_error'),
        title: '프로필을 불러오지 못했어요',
        message: '인터넷 연결을 확인하고 다시 시도해주세요.',
        actionLabel: '다시 시도',
        onAction: _load,
      );
    }
    if (_pet == null) {
      return const PetSpaceStateView.empty(
        key: Key('public_pet_not_found'),
        icon: Icons.pets_outlined,
        title: '반려동물을 찾을 수 없어요',
        message: '프로필이 삭제되었거나 공개되지 않았을 수 있어요.',
      );
    }

    final theme = Theme.of(context);
    final name = (_pet!['name'] as String?)?.trim();
    final type = (_pet!['type'] as String?)?.trim() ??
        (_pet!['species'] as String?)?.trim() ??
        '';
    final breed = (_pet!['breed'] as String?)?.trim() ?? '';
    final photoUrl = (_pet!['avatar_url'] as String?)?.trim() ??
        (_pet!['photo_url'] as String?)?.trim();
    final rawOwner = _pet!['users'];
    final ownerName = rawOwner is Map
        ? (rawOwner['display_name'] as String?)?.trim() ?? ''
        : '';
    final isOwnPet = _currentUserId != null && _currentUserId == _ownerId;

    return ListView(
      key: const Key('public_pet_content'),
      padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 40.h),
      children: [
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              _buildAvatar(photoUrl, name ?? '반려동물'),
              SizedBox(height: 14.h),
              Text(
                name?.isNotEmpty == true ? name! : '이름 없는 반려동물',
                key: const Key('public_pet_name'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTheme.fontTitle.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (type.isNotEmpty || breed.isNotEmpty) ...[
                SizedBox(height: 6.h),
                Text(
                  [breed, type].where((value) => value.isNotEmpty).join(' · '),
                  style: TextStyle(
                    fontSize: AppTheme.fontBody.sp,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (ownerName.isNotEmpty) ...[
                SizedBox(height: 6.h),
                Text(
                  '$ownerName님의 반려동물',
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _followerCount == null ? '—' : '$_followerCount',
                      key: const Key('public_pet_follower_count'),
                      style: TextStyle(
                        fontSize: AppTheme.fontHeading.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '보호자 팔로워',
                      style: TextStyle(
                        fontSize: AppTheme.fontCaption.sp,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isOwnPet && _currentUserId != null)
                SizedBox(
                  height: 44.h,
                  child: FilledButton.tonal(
                    key: const Key('public_pet_follow_button'),
                    onPressed: _followPending ? null : _toggleFollow,
                    child: _followPending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isFollowing ? '팔로잉' : '보호자 팔로우'),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Container(
          key: const Key('public_pet_privacy_notice'),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppTheme.subtleBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline, color: AppTheme.actionBase),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  '건강 기록과 AI 분석 결과는 보호자에게만 표시됩니다.',
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    height: 1.45,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String? photoUrl, String name) {
    return Container(
      width: 112.w,
      height: 112.w,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.actionContainer,
      ),
      child: photoUrl != null && photoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: photoUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _avatarFallback(name),
            )
          : _avatarFallback(name),
    );
  }

  Widget _avatarFallback(String name) => Semantics(
        label: '$name 프로필 사진 없음',
        child: const Icon(
          Icons.pets_outlined,
          size: 44,
          color: AppTheme.actionBase,
        ),
      );
}
