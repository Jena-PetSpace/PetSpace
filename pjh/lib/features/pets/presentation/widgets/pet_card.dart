import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/pet.dart';

class PetCard extends StatelessWidget {
  final Pet pet;
  final bool isSelected;
  final bool isSelectionPending;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSetPrimary;

  const PetCard({
    super.key,
    required this.pet,
    this.isSelected = false,
    this.isSelectionPending = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onSetPrimary,
  });

  @override
  Widget build(BuildContext context) {
    // 다크모드는 Theme의 surface/text/경계를 우선하고,
    // 라이트모드 시각값과 brand/action/error 의미 토큰은 유지한다.
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color cardSurface =
        isDark ? theme.colorScheme.surface : AppTheme.surfaceColor;
    final Color edgeColor =
        isDark ? theme.colorScheme.outlineVariant : AppTheme.border;
    final Color nameColor =
        isDark ? theme.colorScheme.onSurface : AppTheme.primaryTextColor;
    final Color mutedColor = theme.colorScheme.onSurfaceVariant;

    return Container(
      key: Key('pet_card_${pet.id}'),
      margin: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: cardSurface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
          side: isSelected
              ? const BorderSide(color: AppTheme.actionBase, width: 1.5)
              : BorderSide(color: edgeColor, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                _buildAvatar(edgeColor),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              key: Key('pet_card_name_${pet.id}'),
                              pet.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppTheme.fontHeading.sp,
                                fontWeight: FontWeight.w700,
                                color: nameColor,
                              ),
                            ),
                          ),
                          if (isSelected) ...[
                            SizedBox(width: 6.w),
                            Container(
                              key: Key('pet_card_primary_badge_${pet.id}'),
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.brandDeep,
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                '대표',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        pet.breed ?? '품종 미상',
                        style: TextStyle(
                          fontSize: AppTheme.fontCaption.sp,
                          color: mutedColor,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Wrap(
                        spacing: 12.w,
                        runSpacing: 4.h,
                        children: [
                          _buildInfoChip(
                            icon: Icons.cake_outlined,
                            label: pet.displayAge,
                            color: mutedColor,
                          ),
                          if (pet.genderDisplayName != null)
                            _buildInfoChip(
                              icon: pet.gender == PetGender.male
                                  ? Icons.male
                                  : Icons.female,
                              label: pet.genderDisplayName!,
                              color: mutedColor,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                _buildTypeBadge(),
                _buildActionButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Color edgeColor) {
    return Container(
      key: Key('pet_card_avatar_${pet.id}'),
      width: 64.w,
      height: 64.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.actionContainer,
        border: Border.all(color: edgeColor, width: 1),
      ),
      child: pet.avatarUrl != null
          ? Semantics(
              label: '${pet.name} 프로필 사진',
              image: true,
              child: ClipOval(
                child: CachedNetworkImage(
                  key: Key('pet_card_network_image_${pet.id}'),
                  imageUrl: pet.avatarUrl!,
                  width: 64.w,
                  height: 64.w,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                      key: Key('pet_card_image_loading_${pet.id}'),
                      strokeWidth: 2.w,
                      color: AppTheme.actionBase,
                    ),
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.pets,
                    key: Key('pet_card_image_error_${pet.id}'),
                    size: 28.w,
                    color: AppTheme.actionBase,
                  ),
                ),
              ),
            )
          : Icon(
              Icons.pets,
              key: Key('pet_card_avatar_fallback_${pet.id}'),
              size: 28.w,
              color: AppTheme.actionBase,
            ),
    );
  }

  Widget _buildTypeBadge() {
    return Container(
      key: Key('pet_card_type_badge_${pet.id}'),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppTheme.actionContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
      ),
      child: Text(
        pet.typeDisplayName,
        style: TextStyle(
          fontSize: AppTheme.fontMicro.sp,
          fontWeight: FontWeight.w600,
          color: AppTheme.brandDeep,
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.w, color: color),
        SizedBox(width: 4.w),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.sp, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color triggerIcon =
        isDark ? theme.colorScheme.onSurfaceVariant : AppTheme.textMuted;
    final Color editIcon =
        isDark ? theme.colorScheme.onSurface : AppTheme.textBody;

    if (isSelectionPending) {
      return Semantics(
        label: '${pet.name} 대표 반려동물 변경 중',
        liveRegion: true,
        child: Container(
          key: Key('pet_card_selection_pending_${pet.id}'),
          width: 44.w,
          height: 44.w,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          alignment: Alignment.center,
          child: SizedBox(
            width: 20.w,
            height: 20.w,
            child: CircularProgressIndicator(
              strokeWidth: 2.w,
              color: AppTheme.actionBase,
            ),
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      key: Key('pet_card_menu_${pet.id}'),
      onSelected: (value) {
        switch (value) {
          case 'primary':
            onSetPrimary?.call();
            break;
          case 'edit':
            onEdit?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        if (!isSelected)
          PopupMenuItem(
            value: 'primary',
            child: Row(
              children: [
                Icon(
                  Icons.star_outline,
                  size: 20.w,
                  color: AppTheme.actionBase,
                ),
                SizedBox(width: 8.w),
                Text('대표 설정', style: TextStyle(fontSize: 14.sp)),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20.w, color: editIcon),
              SizedBox(width: 8.w),
              Text('수정', style: TextStyle(fontSize: 14.sp)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                size: 20.w,
                color: AppTheme.errorColor,
              ),
              SizedBox(width: 8.w),
              Text(
                '삭제',
                style: TextStyle(color: AppTheme.errorColor, fontSize: 14.sp),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        key: Key('pet_card_menu_trigger_${pet.id}'),
        // ScreenUtil 축소와 무관하게 최소 44×44 논리 픽셀 터치 영역 보장.
        width: 44.w,
        height: 44.w,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        color: Colors.transparent,
        child: Icon(Icons.more_vert, size: 20.w, color: triggerIcon),
      ),
    );
  }
}
