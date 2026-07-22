import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../../../shared/widgets/petspace_state_view.dart';
import '../../domain/entities/pet.dart';
import '../bloc/pet_bloc.dart';
import '../bloc/pet_event.dart';
import '../bloc/pet_state.dart';
import '../widgets/pet_card.dart';
import 'pet_detail_page.dart';
import 'pet_editor_page.dart';

class PetManagementPage extends StatefulWidget {
  const PetManagementPage({super.key});

  @override
  State<PetManagementPage> createState() => _PetManagementPageState();
}

class _PetManagementPageState extends State<PetManagementPage> {
  static const double _navigationOverlapClearance = 64;

  @override
  void initState() {
    super.initState();
    context.read<PetBloc>().add(LoadUserPets());
  }

  @override
  Widget build(BuildContext context) {
    return PetSpacePageScaffold(
      title: '반려동물 관리',
      body: BlocConsumer<PetBloc, PetState>(
        listener: (context, state) {
          if (state is PetOperationSuccess) {
            _showFeedback(state.message);
          } else if (state is PetError) {
            _showFeedback(state.message, backgroundColor: AppTheme.errorColor);
          }
        },
        builder: (context, state) {
          if (state is PetLoading) {
            return const PetSpaceStateView.loading();
          }

          if (state is PetError) {
            return PetSpaceStateView.error(
              message: state.message,
              actionLabel: '다시 시도',
              onAction: () {
                context.read<PetBloc>().add(LoadUserPets());
              },
            );
          }

          if (state is PetLoaded || state is PetOperationSuccess) {
            final pets = state is PetLoaded
                ? state.pets
                : (state as PetOperationSuccess).pets;
            final selectedPet = state is PetLoaded ? state.selectedPet : null;

            if (pets.isEmpty) {
              return PetSpaceStateView.empty(
                icon: Icons.pets,
                title: '등록된 반려동물이 없습니다',
                message: '첫 번째 반려동물을 등록해보세요!\n함께하는 순간을 기록할 수 있어요.',
                actionLabel: '반려동물 추가하기',
                onAction: _openAddPetPage,
              );
            }

            return _buildPetList(pets, selectedPet);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildPetList(List<Pet> pets, Pet? selectedPet) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final addBackground = isDark
        ? theme.colorScheme.primaryContainer
        : AppTheme.actionContainer;
    final addForeground = isDark
        ? theme.colorScheme.onPrimaryContainer
        : AppTheme.actionBase;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<PetBloc>().add(LoadUserPets());
      },
      child: ListView.builder(
        key: const Key('pet_management_list'),
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 112.h),
        itemCount: pets.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: ElevatedButton.icon(
                key: const Key('pet_management_add_button'),
                onPressed: _openAddPetPage,
                icon: Icon(Icons.add, size: 20.w),
                label: Text('반려동물 추가하기', style: TextStyle(fontSize: 14.sp)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  minimumSize: const Size(0, 48),
                  backgroundColor: addBackground,
                  foregroundColor: addForeground,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
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
            isSelected: selectedPet?.id == pet.id,
            onTap: () => _showPetDetails(pet),
            onEdit: () => _openEditPetPage(pet),
            onDelete: () => _showDeleteConfirmation(pet),
            onSetPrimary: () {
              context.read<PetBloc>().add(SelectPet(pet));
              _showFeedback('${pet.name}이(가) 대표 반려동물로 설정되었습니다.');
            },
          );
        },
      ),
    );
  }

  void _showFeedback(String message, {Color? backgroundColor}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('pet_management_feedback_snackbar'),
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            16.w,
            0,
            16.w,
            _navigationOverlapClearance.h,
          ),
        ),
      );
  }

  void _openAddPetPage() {
    context.pushNamed(
      PetEditorRoutes.createName,
      extra: PetEditorRouteData(petBloc: context.read<PetBloc>()),
    );
  }

  void _openEditPetPage(Pet pet) {
    context.pushNamed(
      PetEditorRoutes.editName,
      pathParameters: {'petId': pet.id},
      extra: PetEditorRouteData(petBloc: context.read<PetBloc>(), pet: pet),
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
            Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.errorColor,
              size: 28.w,
            ),
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
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text('삭제', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }
}
