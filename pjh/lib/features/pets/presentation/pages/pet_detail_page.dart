import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../domain/entities/pet.dart';
import '../bloc/pet_bloc.dart';
import '../bloc/pet_event.dart';
import '../bloc/pet_state.dart';
import 'pet_editor_page.dart';

class PetDetailPage extends StatefulWidget {
  final Pet pet;

  const PetDetailPage({
    super.key,
    required this.pet,
  });

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  late Pet pet;

  @override
  void initState() {
    super.initState();
    pet = widget.pet;
  }

  @override
  void didUpdateWidget(covariant PetDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pet != widget.pet) pet = widget.pet;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PetBloc, PetState>(
      listener: (context, state) {
        if (state is PetOperationSuccess) {
          _updateDisplayedPet(state.pets);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          // PetBloc에 operation type이 없는 기존 계약을 유지한다.
          if (state.message.contains('삭제')) {
            Navigator.of(context).pop();
          }
        } else if (state is PetError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('반려동물 정보를 처리하지 못했어요. 잠시 후 다시 시도해주세요.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        } else if (state is PetLoaded) {
          _updateDisplayedPet(state.pets);
        }
      },
      child: PetSpacePageScaffold(
        title: '반려동물 정보',
        actions: [_buildOverflowMenu(context)],
        body: SafeArea(
          top: false,
          child: ListView(
            key: const Key('pet_detail_scroll'),
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
            children: [
              _buildIdentityCard(),
              SizedBox(height: 18.h),
              _buildInformationCard(),
              if (pet.description?.trim().isNotEmpty == true) ...[
                SizedBox(height: 18.h),
                _buildDescriptionCard(),
              ],
              SizedBox(height: 24.h),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverflowMenu(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('pet_detail_overflow'),
      tooltip: '더보기',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'edit') {
          _openEditPage(context);
        } else if (value == 'delete') {
          _showDeleteConfirmation(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20.w),
              SizedBox(width: 10.w),
              const Text('정보 수정'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline,
                  color: AppTheme.errorColor, size: 20.w),
              SizedBox(width: 10.w),
              const Text(
                '삭제',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdentityCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? theme.colorScheme.surface : AppTheme.surfaceColor;
    final titleColor =
        isDark ? theme.colorScheme.onSurface : AppTheme.primaryTextColor;
    final muted =
        isDark ? theme.colorScheme.onSurfaceVariant : AppTheme.textMuted;

    return Container(
      key: const Key('pet_detail_identity'),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
        border: Border.all(
          color: isDark ? theme.dividerColor : AppTheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  key: const Key('pet_detail_name'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTheme.fontTitle.sp,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  pet.breed?.trim().isNotEmpty == true ? pet.breed! : '품종 미상',
                  key: const Key('pet_detail_breed'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    color: muted,
                  ),
                ),
                SizedBox(height: 10.h),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: AppTheme.actionContainer,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Text(
                    pet.typeDisplayName,
                    style: TextStyle(
                      fontSize: AppTheme.fontMicro.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.brandDeep,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      key: const Key('pet_detail_avatar'),
      width: 96.w,
      height: 96.w,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppTheme.actionContainer,
        shape: BoxShape.circle,
      ),
      child: pet.avatarUrl?.isNotEmpty == true
          ? CachedNetworkImage(
              imageUrl: pet.avatarUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.actionBase,
                ),
              ),
              errorWidget: (_, __, ___) => _buildDefaultAvatar(),
            )
          : _buildDefaultAvatar(),
    );
  }

  Widget _buildDefaultAvatar() {
    return Center(
      child: Icon(
        Icons.pets_outlined,
        size: 42.w,
        color: AppTheme.actionBase,
      ),
    );
  }

  Widget _buildInformationCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? theme.colorScheme.surface : AppTheme.surfaceColor;

    return Container(
      key: const Key('pet_detail_information'),
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
        border: Border.all(
          color: isDark ? theme.dividerColor : AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.cake_outlined,
            label: '나이',
            value: pet.displayAge,
          ),
          _buildInfoDivider(theme, isDark),
          _buildInfoRow(
            icon: pet.gender == PetGender.male
                ? Icons.male_rounded
                : pet.gender == PetGender.female
                    ? Icons.female_rounded
                    : Icons.question_mark_rounded,
            label: '성별',
            value: pet.genderDisplayName ?? '미상',
          ),
          _buildInfoDivider(theme, isDark),
          _buildInfoRow(
            icon: Icons.calendar_today_outlined,
            label: '등록한 날',
            value: _formatDate(pet.createdAt),
            valueKey: const Key('pet_detail_registered_date'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Key? valueKey,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final text =
        isDark ? theme.colorScheme.onSurface : AppTheme.primaryTextColor;
    final muted =
        isDark ? theme.colorScheme.onSurfaceVariant : AppTheme.textMuted;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 56.h),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.actionBase, size: 21.w),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.fontCaption.sp,
                color: muted,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Flexible(
            child: Text(
              value,
              key: valueKey,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppTheme.fontBody.sp,
                fontWeight: FontWeight.w600,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoDivider(ThemeData theme, bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? theme.dividerColor : AppTheme.dividerColor,
    );
  }

  Widget _buildDescriptionCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      key: const Key('pet_detail_description'),
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
        border: Border.all(
          color: isDark ? theme.dividerColor : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '소개',
            style: TextStyle(
              fontSize: AppTheme.fontHeading.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? theme.colorScheme.onSurface : AppTheme.brandDeep,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            pet.description!.trim(),
            style: TextStyle(
              fontSize: AppTheme.fontBody.sp,
              height: 1.55,
              color: isDark
                  ? theme.colorScheme.onSurfaceVariant
                  : AppTheme.primaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52.h,
          child: ElevatedButton.icon(
            key: const Key('pet_detail_edit_button'),
            onPressed: () => _openEditPage(context),
            icon: Icon(Icons.edit_outlined, size: 20.w),
            label: Text(
              '정보 수정',
              style: TextStyle(
                fontSize: AppTheme.fontBody.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.actionBase,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
              ),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          width: double.infinity,
          height: 50.h,
          child: OutlinedButton.icon(
            key: const Key('pet_detail_emotion_button'),
            onPressed: () => context.push(
              '/emotion?petId=${pet.id}&petName=${Uri.encodeComponent(pet.name)}',
            ),
            icon: Icon(Icons.psychology_outlined, size: 20.w),
            label: Text(
              'AI 분석하기',
              style: TextStyle(fontSize: AppTheme.fontBody.sp),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          width: double.infinity,
          height: 50.h,
          child: OutlinedButton.icon(
            key: const Key('pet_detail_create_post_button'),
            onPressed: () => context.push(
              '/create-post?petId=${pet.id}&petName=${Uri.encodeComponent(pet.name)}',
            ),
            icon: Icon(Icons.add_photo_alternate_outlined, size: 20.w),
            label: Text(
              '게시물 작성',
              style: TextStyle(fontSize: AppTheme.fontBody.sp),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}.$month.$day';
  }

  void _openEditPage(BuildContext context) {
    context.pushNamed(
      PetEditorRoutes.editName,
      pathParameters: {'petId': pet.id},
      extra: PetEditorRouteData(
        petBloc: context.read<PetBloc>(),
        pet: pet,
      ),
    );
  }

  void _updateDisplayedPet(List<Pet> pets) {
    Pet? updatedPet;
    for (final candidate in pets) {
      if (candidate.id == pet.id) {
        updatedPet = candidate;
        break;
      }
    }
    if (updatedPet != null && updatedPet != pet && mounted) {
      setState(() => pet = updatedPet!);
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    final petBloc = context.read<PetBloc>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg.r),
        ),
        title: const Text('반려동물 삭제'),
        content: Text(
          '${pet.name}을(를) 삭제하면 복구할 수 없습니다. 계속할까요?',
          style: TextStyle(fontSize: AppTheme.fontBody.sp, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            key: const Key('pet_detail_delete_confirm'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              petBloc.add(DeletePetEvent(pet.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
