import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/pet.dart';

class PetCard extends StatelessWidget {
  final Pet pet;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const PetCard({
    super.key,
    required this.pet,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              // Pet Avatar
              _buildAvatar(),
              SizedBox(width: 16.w),

              // Pet Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pet.name,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryTextColor,
                            ),
                          ),
                        ),
                        _buildTypeBadge(),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      pet.breed ?? '품종 미상',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        _buildInfoChip(
                          icon: Icons.cake,
                          label: pet.displayAge,
                        ),
                        SizedBox(width: 12.w),
                        if (pet.genderDisplayName != null)
                          _buildInfoChip(
                            icon: pet.gender == PetGender.male
                                ? Icons.male
                                : Icons.female,
                            label: pet.genderDisplayName!,
                            color: pet.gender == PetGender.male
                                ? Colors.blue
                                : Colors.pink,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Button
              _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 70.w,
      height: 70.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 2.w,
        ),
      ),
      child: pet.avatarUrl != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: pet.avatarUrl!,
                width: 70.w,
                height: 70.w,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.w,
                    color: AppTheme.primaryColor,
                  ),
                ),
                errorWidget: (context, url, error) => Icon(
                  pet.type == PetType.dog ? Icons.pets : Icons.pets,
                  size: 32.w,
                  color: AppTheme.primaryColor,
                ),
              ),
            )
          : Icon(
              pet.type == PetType.dog ? Icons.pets : Icons.pets,
              size: 32.w,
              color: AppTheme.primaryColor,
            ),
    );
  }

  Widget _buildTypeBadge() {
    final isDog = pet.type == PetType.dog;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isDog
            ? Colors.brown.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        pet.typeDisplayName,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: isDog ? Colors.brown : Colors.orange,
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14.w,
          color: color ?? Colors.grey[600],
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: color ?? Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20.w),
              SizedBox(width: 8.w),
              Text('수정', style: TextStyle(fontSize: 14.sp)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 20.w, color: Colors.red),
              SizedBox(width: 8.w),
              Text('삭제', style: TextStyle(color: Colors.red, fontSize: 14.sp)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[100],
        ),
        child: Icon(
          Icons.more_vert,
          size: 20.w,
          color: Colors.grey,
        ),
      ),
    );
  }
}
