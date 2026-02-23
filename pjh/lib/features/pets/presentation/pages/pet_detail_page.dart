import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/pet.dart';
import '../bloc/pet_bloc.dart';
import '../bloc/pet_event.dart';
import '../bloc/pet_state.dart';
import '../widgets/add_pet_bottom_sheet.dart';

class PetDetailPage extends StatelessWidget {
  final Pet pet;

  const PetDetailPage({
    super.key,
    required this.pet,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<PetBloc, PetState>(
      listener: (context, state) {
        if (state is PetOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
          if (state.message.contains('삭제')) {
            Navigator.of(context).pop();
          }
        } else if (state is PetError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(context),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection(),
                    SizedBox(height: 24.h),
                    _buildStatsSection(),
                    SizedBox(height: 24.h),
                    if (pet.description != null && pet.description!.isNotEmpty)
                      _buildDescriptionSection(),
                    SizedBox(height: 24.h),
                    _buildActionButtons(context),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300.h,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: pet.avatarUrl != null
            ? CachedNetworkImage(
                imageUrl: pet.avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.w,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildDefaultAvatar(),
              )
            : _buildDefaultAvatar(),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Icon(Icons.more_vert, color: Colors.white, size: 20.w),
          ),
          onSelected: (value) {
            if (value == 'edit') {
              _showEditBottomSheet(context);
            } else if (value == 'delete') {
              _showDeleteConfirmation(context);
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
                  Icon(Icons.delete, color: Colors.red, size: 20.w),
                  SizedBox(width: 8.w),
                  Text('삭제', style: TextStyle(color: Colors.red, fontSize: 14.sp)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: AppTheme.primaryColor.withValues(alpha: 0.3),
      child: Center(
        child: Icon(
          pet.type == PetType.dog ? Icons.pets : Icons.pets,
          size: 80.w,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                pet.name,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: pet.type == PetType.dog
                    ? Colors.brown.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    pet.type == PetType.dog ? Icons.pets : Icons.pets,
                    size: 16.w,
                    color: pet.type == PetType.dog ? Colors.brown : Colors.orange,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    pet.typeDisplayName,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: pet.type == PetType.dog ? Colors.brown : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        if (pet.breed != null)
          Text(
            pet.breed!,
            style: TextStyle(
              fontSize: 16.sp,
              color: AppTheme.secondaryTextColor,
            ),
          ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.cake,
            label: '나이',
            value: pet.displayAge,
            color: Colors.pink,
          ),
          _buildDivider(),
          _buildStatItem(
            icon: pet.gender == PetGender.male ? Icons.male : Icons.female,
            label: '성별',
            value: pet.genderDisplayName ?? '미상',
            color: pet.gender == PetGender.male ? Colors.blue : Colors.pink,
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.calendar_today,
            label: '함께한 날',
            value: _getDaysTogether(),
            color: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24.w),
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTextColor,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: AppTheme.secondaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 50.h,
      color: Colors.grey[300],
    );
  }

  String _getDaysTogether() {
    final days = DateTime.now().difference(pet.createdAt).inDays;
    if (days < 1) return '오늘';
    if (days < 30) return '$days일';
    if (days < 365) return '${days ~/ 30}개월';
    return '${days ~/ 365}년';
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '소개',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTextColor,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            pet.description!,
            style: TextStyle(
              fontSize: 14.sp,
              height: 1.5,
              color: AppTheme.primaryTextColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // 감정 분석 페이지로 이동 (GoRouter 사용)
              context.push('/emotion?petId=${pet.id}&petName=${Uri.encodeComponent(pet.name)}');
            },
            icon: Icon(Icons.psychology, size: 20.w),
            label: Text('감정 분석하기', style: TextStyle(fontSize: 14.sp)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // 게시물 작성 페이지로 이동 (GoRouter 사용)
              context.push('/create-post?petId=${pet.id}&petName=${Uri.encodeComponent(pet.name)}');
            },
            icon: Icon(Icons.add_photo_alternate, size: 20.w),
            label: Text('게시물 작성', style: TextStyle(fontSize: 14.sp)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              side: const BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showEditBottomSheet(BuildContext context) {
    final petBloc = context.read<PetBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPetBottomSheet(
        pet: pet,
        onPetAdded: (updatedPet) {
          petBloc.add(UpdatePetEvent(updatedPet));
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final petBloc = context.read<PetBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28.w),
            SizedBox(width: 8.w),
            Text('반려동물 삭제', style: TextStyle(fontSize: 18.sp)),
          ],
        ),
        content: Text(
          '${pet.name}을(를) 삭제하시겠습니까?\n\n관련된 모든 데이터가 함께 삭제되며,\n이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(fontSize: 14.sp, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('취소', style: TextStyle(fontSize: 14.sp)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              petBloc.add(DeletePetEvent(pet.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
