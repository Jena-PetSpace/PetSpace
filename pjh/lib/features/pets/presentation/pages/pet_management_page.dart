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
        listenWhen: (previous, current) {
          if (current is PetOperationSuccess || current is PetError) {
            return true;
          }
          if (previous is PetLoaded && current is PetLoaded) {
            return previous.selectionStatus != current.selectionStatus ||
                previous.selectionMessage != current.selectionMessage;
          }
          return current is PetLoaded &&
              (current.selectionStatus == PetSelectionStatus.success ||
                  current.selectionStatus == PetSelectionStatus.failure);
        },
        listener: (context, state) {
          if (state is PetOperationSuccess) {
            _showFeedback(state.message);
          } else if (state is PetError) {
            _showFeedback(state.message, backgroundColor: AppTheme.errorColor);
          } else if (state is PetLoaded &&
              state.selectionStatus == PetSelectionStatus.success &&
              state.selectionMessage != null) {
            _showFeedback(state.selectionMessage!);
          } else if (state is PetLoaded &&
              state.selectionStatus == PetSelectionStatus.failure &&
              state.selectionMessage != null) {
            _showFeedback(
              state.selectionMessage!,
              backgroundColor: AppTheme.errorColor,
            );
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

            return _buildPetList(
              pets,
              selectedPet,
              state is PetLoaded ? state.pendingSelectedPetId : null,
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildPetList(
    List<Pet> pets,
    Pet? selectedPet,
    String? pendingSelectedPetId,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final addBackground =
        isDark ? theme.colorScheme.primaryContainer : AppTheme.actionContainer;
    final addForeground =
        isDark ? theme.colorScheme.onPrimaryContainer : AppTheme.actionBase;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<PetBloc>().add(LoadUserPets());
      },
      child: ListView(
        key: const Key('pet_management_list'),
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 112.h),
        children: [
          Text(
            '함께하는 반려동물을 관리하고, 앱 전반에 표시할 대표 친구를 선택할 수 있어요.',
            style: TextStyle(
              fontSize: AppTheme.fontBody.sp,
              height: 1.45,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton.icon(
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
              side: BorderSide(
                color: addForeground.withValues(alpha: 0.32),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
          SizedBox(height: 24.h),
          _buildSectionTitle('대표 반려동물'),
          SizedBox(height: 10.h),
          if (selectedPet != null)
            _buildPetCard(selectedPet, selectedPet, pendingSelectedPetId)
          else
            _buildSelectionPrompt(),
          if (pets.any((pet) => pet.id != selectedPet?.id)) ...[
            SizedBox(height: 20.h),
            _buildSectionTitle(
              selectedPet == null ? '함께하는 친구' : '다른 반려동물',
              count: pets.where((pet) => pet.id != selectedPet?.id).length,
            ),
            SizedBox(height: 10.h),
            ...pets.where((pet) => pet.id != selectedPet?.id).map(
                  (pet) => _buildPetCard(
                    pet,
                    selectedPet,
                    pendingSelectedPetId,
                  ),
                ),
          ],
          SizedBox(height: 8.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 18.w,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '대표 반려동물은 MY와 건강, 감정 분석 등 주요 화면의 기본 대상으로 사용됩니다.',
                  style: TextStyle(
                    fontSize: AppTheme.fontCaption.sp,
                    height: 1.45,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {int? count}) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: AppTheme.fontHeading.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (count != null) ...[
          SizedBox(width: 6.w),
          Text(
            '$count',
            style: TextStyle(
              fontSize: AppTheme.fontCaption.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.actionBase,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSelectionPrompt() {
    final theme = Theme.of(context);
    return Container(
      key: const Key('pet_management_selection_prompt'),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_outline, color: AppTheme.actionBase),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              '아래 친구의 더보기 메뉴에서 대표 반려동물을 선택해 주세요.',
              style: TextStyle(
                fontSize: AppTheme.fontBody.sp,
                height: 1.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCard(
    Pet pet,
    Pet? selectedPet,
    String? pendingSelectedPetId,
  ) {
    return PetCard(
      pet: pet,
      isSelected: selectedPet?.id == pet.id,
      isSelectionPending: pendingSelectedPetId == pet.id,
      onTap: () => _showPetDetails(pet),
      onEdit: () => _openEditPetPage(pet),
      onDelete: () => _showDeleteConfirmation(pet),
      onSetPrimary: () {
        context.read<PetBloc>().add(SelectPet(pet));
      },
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${pet.name}의 정보를 삭제하면 다음 항목이 함께 삭제됩니다.',
                style: TextStyle(fontSize: 14.sp, height: 1.5),
              ),
              SizedBox(height: 12.h),
              _buildDeleteImpact(
                icon: Icons.delete_forever_outlined,
                title: '함께 삭제되는 정보',
                description: '반려동물 프로필, 건강 기록, 감정 분석 기록, 성격 결과',
                color: AppTheme.errorColor,
              ),
              SizedBox(height: 10.h),
              _buildDeleteImpact(
                icon: Icons.link_off,
                title: '기록은 유지되고 연결만 해제',
                description: '게시물과 산책 기록',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: 14.h),
              Text(
                '이 작업은 되돌릴 수 없습니다.',
                style: TextStyle(
                  fontSize: 14.sp,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.errorColor,
                ),
              ),
            ],
          ),
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

  Widget _buildDeleteImpact({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20.w, color: color),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2.h),
              Text(
                description,
                style: TextStyle(fontSize: 13.sp, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
