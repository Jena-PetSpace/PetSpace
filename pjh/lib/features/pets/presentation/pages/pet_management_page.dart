import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/pet.dart';
import '../bloc/pet_bloc.dart';
import '../bloc/pet_event.dart';
import '../bloc/pet_state.dart';
import '../widgets/add_pet_bottom_sheet.dart';
import '../widgets/pet_card.dart';
import 'pet_detail_page.dart';

class PetManagementPage extends StatefulWidget {
  const PetManagementPage({super.key});

  @override
  State<PetManagementPage> createState() => _PetManagementPageState();
}

class _PetManagementPageState extends State<PetManagementPage> {
  @override
  void initState() {
    super.initState();
    context.read<PetBloc>().add(LoadUserPets());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('반려동물 관리', style: TextStyle(fontSize: 18.sp)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: BlocConsumer<PetBloc, PetState>(
        listener: (context, state) {
          if (state is PetOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is PetError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is PetLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is PetError) {
            return _buildErrorState(state.message);
          }

          if (state is PetLoaded || state is PetOperationSuccess) {
            final pets = state is PetLoaded
                ? state.pets
                : (state as PetOperationSuccess).pets;

            if (pets.isEmpty) {
              return _buildEmptyState();
            }

            return _buildPetList(pets);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.w,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16.h),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () {
                context.read<PetBloc>().add(LoadUserPets());
              },
              child: Text('다시 시도', style: TextStyle(fontSize: 14.sp)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.w),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pets,
                size: 64.w,
                color: AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              '등록된 반려동물이 없습니다',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '첫 번째 반려동물을 등록해보세요!\n함께하는 순간을 기록할 수 있어요.',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppTheme.secondaryTextColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32.h),
            ElevatedButton.icon(
              onPressed: _showAddPetBottomSheet,
              icon: Icon(Icons.add, size: 20.w),
              label: Text('반려동물 추가하기', style: TextStyle(fontSize: 14.sp)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: 24.w,
                  vertical: 14.h,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetList(List<Pet> pets) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<PetBloc>().add(LoadUserPets());
      },
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: pets.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: OutlinedButton.icon(
                onPressed: _showAddPetBottomSheet,
                icon: Icon(Icons.add, size: 20.w),
                label: Text('반려동물 추가하기', style: TextStyle(fontSize: 14.sp)),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  side: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  ),
                  foregroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            );
          }

          final pet = pets[index - 1];
          return PetCard(
            pet: pet,
            onTap: () => _showPetDetails(pet),
            onEdit: () => _showEditPetBottomSheet(pet),
            onDelete: () => _showDeleteConfirmation(pet),
          );
        },
      ),
    );
  }

  void _showAddPetBottomSheet() {
    final petBloc = context.read<PetBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPetBottomSheet(
        onPetAdded: (pet) {
          petBloc.add(AddPetEvent(pet));
        },
      ),
    );
  }

  void _showEditPetBottomSheet(Pet pet) {
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

  void _showPetDetails(Pet pet) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: this.context.read<PetBloc>(),
          child: PetDetailPage(pet: pet),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Pet pet) {
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
          '${pet.name}을(를) 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
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
            child: Text('삭제', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }
}
