import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../health/domain/entities/health_record.dart';
import '../../../health/domain/repositories/health_repository.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_event.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../controllers/my_next_health_loader.dart';

typedef LoadMyNextHealth = Future<HealthRecord?> Function({
  required String userId,
  required String petId,
});

/// MY 탭의 대표 반려동물 단일 요약.
/// 건강 일정 실패는 카드 안에서만 처리해 프로필과 게시물 탐색을 막지 않는다.
class MyPetSummarySection extends StatelessWidget {
  final String userId;
  final LoadMyNextHealth? loadNextHealth;
  final bool embedded;

  const MyPetSummarySection({
    super.key,
    required this.userId,
    this.loadNextHealth,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, state) {
        return Container(
          key: const Key('my_pet_summary_section'),
          color: Theme.of(context).colorScheme.surface,
          padding: embedded
              ? EdgeInsets.symmetric(vertical: 4.h)
              : EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '대표 반려동물',
                    style: TextStyle(
                      fontSize: AppTheme.fontHeading.sp,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('my_pet_manage_button'),
                    onPressed: () => context.push('/pets'),
                    child: const Text('관리'),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              _buildState(context, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildState(BuildContext context, PetState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (state is PetInitial || state is PetLoading) {
      return Container(
        key: const Key('my_pet_summary_loading'),
        height: 116.h,
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest
              : AppTheme.subtleBackground,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
        ),
        alignment: Alignment.center,
        child: CircularProgressIndicator(
          color: isDark ? theme.colorScheme.primary : AppTheme.actionBase,
        ),
      );
    }

    if (state is PetError) {
      return _InlineMessage(
        key: const Key('my_pet_summary_error'),
        icon: Icons.cloud_off_outlined,
        title: '반려동물 정보를 불러오지 못했어요',
        description: '프로필과 게시물은 계속 이용할 수 있어요.',
        actionLabel: '다시 시도',
        onAction: () => context.read<PetBloc>().add(LoadUserPets()),
      );
    }

    if (state is! PetLoaded || state.pets.isEmpty) {
      return _InlineMessage(
        key: const Key('my_pet_summary_empty'),
        icon: Icons.pets_outlined,
        title: '첫 반려동물을 등록해보세요',
        description: '건강 일정과 함께한 기록을 MY에서 한눈에 볼 수 있어요.',
        actionLabel: '등록하기',
        onAction: () => context.push('/pets'),
      );
    }

    final selectedPet = state.selectedPet;
    if (selectedPet == null) {
      return _InlineMessage(
        key: const Key('my_pet_summary_selection_required'),
        icon: Icons.star_outline,
        title: '대표 반려동물을 선택해 주세요',
        description: '여러 친구 중 MY에 먼저 보여줄 반려동물을 정할 수 있어요.',
        actionLabel: '선택하기',
        onAction: () => context.push('/pets'),
      );
    }

    final loader =
        loadNextHealth ?? MyNextHealthLoader(sl<HealthRepository>()).call;
    return _SelectedPetHero(
      key: ValueKey('my_selected_pet_${selectedPet.id}'),
      pet: selectedPet,
      userId: userId,
      loadNextHealth: loader,
    );
  }
}

class _SelectedPetHero extends StatefulWidget {
  final Pet pet;
  final String userId;
  final LoadMyNextHealth loadNextHealth;

  const _SelectedPetHero({
    super.key,
    required this.pet,
    required this.userId,
    required this.loadNextHealth,
  });

  @override
  State<_SelectedPetHero> createState() => _SelectedPetHeroState();
}

class _SelectedPetHeroState extends State<_SelectedPetHero> {
  late Future<HealthRecord?> _healthFuture;

  @override
  void initState() {
    super.initState();
    _loadHealth();
  }

  @override
  void didUpdateWidget(covariant _SelectedPetHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pet.id != widget.pet.id ||
        oldWidget.userId != widget.userId) {
      _loadHealth();
    }
  }

  void _loadHealth() {
    _healthFuture = widget.loadNextHealth(
      userId: widget.userId,
      petId: widget.pet.id,
    );
  }

  void _retryHealth() {
    setState(_loadHealth);
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final theme = Theme.of(context);
    return InkWell(
      key: const Key('my_selected_pet_hero'),
      onTap: () => context.push('/pets'),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
      child: Ink(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? theme.colorScheme.surfaceContainerHighest
              : AppTheme.actionContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
          border: Border.all(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.outlineVariant
                : AppTheme.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PetAvatar(pet: pet),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTheme.fontHeading.sp,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.brandDeep,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm.r),
                        ),
                        child: Text(
                          '대표',
                          style: TextStyle(
                            fontSize: AppTheme.fontMicro.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    [
                      pet.breed ?? pet.typeDisplayName,
                      pet.displayAge,
                      if (pet.genderDisplayName != null) pet.genderDisplayName!,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTheme.fontCaption.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildHealth(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealth(BuildContext context) {
    return FutureBuilder<HealthRecord?>(
      future: _healthFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            key: const Key('my_next_health_loading'),
            children: [
              SizedBox(
                width: 14.w,
                height: 14.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.w,
                  color: AppTheme.featureHealth,
                ),
              ),
              SizedBox(width: 8.w),
              const Expanded(
                child: Text(
                  '다가오는 건강 일정을 확인하고 있어요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return Row(
            key: const Key('my_next_health_error'),
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 18,
                color: AppTheme.featureHealth,
              ),
              SizedBox(width: 6.w),
              const Expanded(child: Text('건강 일정을 불러오지 못했어요')),
              TextButton(
                key: const Key('my_next_health_retry'),
                onPressed: _retryHealth,
                child: const Text('다시 시도'),
              ),
            ],
          );
        }

        final record = snapshot.data;
        if (record == null) {
          return const Row(
            key: Key('my_next_health_empty'),
            children: [
              Icon(
                Icons.event_available_outlined,
                size: 18,
                color: AppTheme.featureHealth,
              ),
              SizedBox(width: 6),
              Expanded(child: Text('다가오는 건강 일정이 없어요')),
            ],
          );
        }

        return Row(
          key: const Key('my_next_health_value'),
          children: [
            const Icon(
              Icons.health_and_safety_outlined,
              size: 18,
              color: AppTheme.featureHealth,
            ),
            SizedBox(width: 6.w),
            Expanded(
              child: Text(
                '${_formatDate(record.dueDate!)} · ${record.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTheme.fontCaption.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) => '${date.month}월 ${date.day}일';
}

class _PetAvatar extends StatelessWidget {
  final Pet pet;

  const _PetAvatar({required this.pet});

  @override
  Widget build(BuildContext context) {
    final url = pet.avatarUrl;
    return Container(
      width: 72.w,
      height: 72.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() => const Icon(
        Icons.pets,
        size: 30,
        color: AppTheme.actionBase,
      );
}

class _InlineMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  const _InlineMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.subtleBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
      ),
      child: Row(
        children: [
          Icon(icon, size: 26.w, color: AppTheme.actionBase),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: AppTheme.fontBody.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
