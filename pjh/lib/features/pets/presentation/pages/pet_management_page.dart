import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_page_scaffold.dart';
import '../../../../shared/widgets/petspace_state_view.dart';
import '../../../../shared/widgets/petspace_uiux_v3.dart';
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
  Pet? _pendingDeleteAfterPrimaryChange;
  String? _pendingPrimaryForDeletionId;

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
            _showFeedback(publicErrorMessage(state.message));
          } else if (state is PetError) {
            _showFeedback(
              publicErrorMessage(
                state.message,
                fallback: ErrorMessages.petDeleteFailed,
              ),
              backgroundColor: AppTheme.errorColor,
            );
          } else if (state is PetLoaded &&
              state.selectionStatus == PetSelectionStatus.success) {
            if (state.selectionMessage != null) {
              _showFeedback(publicErrorMessage(state.selectionMessage!));
            }
            _resumePendingDeletion(state);
          } else if (state is PetLoaded &&
              state.selectionStatus == PetSelectionStatus.failure) {
            _pendingDeleteAfterPrimaryChange = null;
            _pendingPrimaryForDeletionId = null;
            if (state.selectionMessage != null) {
              _showFeedback(
                publicErrorMessage(
                  state.selectionMessage!,
                  fallback: ErrorMessages.petUpdateFailed,
                ),
                backgroundColor: AppTheme.errorColor,
              );
            }
          }
        },
        builder: (context, state) {
          if (state is PetLoading) {
            return const PetSpaceStateView.loading();
          }

          if (state is PetError) {
            return PetSpaceStateView.error(
              message: publicErrorMessage(
                state.message,
                fallback: ErrorMessages.petNotFound,
              ),
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
              return PetSpaceV3StateView(
                kind: PetSpaceV3StateKind.initial,
                title: '등록된 반려동물이 없어요',
                message: '첫 번째 반려동물을 등록하면 함께하는 순간을 기록할 수 있어요.',
                primaryActionLabel: '반려동물 추가하기',
                onPrimaryAction: _openAddPetPage,
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
      onDelete: () => _requestPetDeletion(pet, selectedPet),
      onSetPrimary: () => _showPrimaryPetConfirmation(pet),
    );
  }

  Future<void> _showPrimaryPetConfirmation(Pet pet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        key: const Key('pet_primary_confirmation_dialog'),
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.sizeOf(dialogContext).height - 32,
          ),
          child: Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '대표 반려동물 변경',
                          style: TextStyle(
                            fontSize: AppTheme.fontHeading.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          '대표로 선택할 반려동물',
                          style: TextStyle(
                            fontSize: AppTheme.fontCaption.sp,
                            color: Theme.of(
                              dialogContext,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Semantics(
                          label: '대표로 선택할 반려동물: ${pet.name}',
                          child: ExcludeSemantics(
                            child: Text(
                              pet.name,
                              style: TextStyle(
                                fontSize: AppTheme.fontHeading.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'MY와 건강, 감정 분석 등 주요 화면의 기본 대상으로 사용돼요.',
                          style: TextStyle(
                            fontSize: AppTheme.fontBody.sp,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                FilledButton(
                  key: const Key('pet_primary_confirmation_confirm'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('대표로 변경'),
                ),
                SizedBox(height: 8.h),
                TextButton(
                  key: const Key('pet_primary_confirmation_cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('취소'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<PetBloc>().add(SelectPet(pet));
  }

  Future<void> _requestPetDeletion(Pet pet, Pet? selectedPet) async {
    final petBloc = context.read<PetBloc>();
    final currentState = petBloc.state;
    final pets = switch (currentState) {
      PetLoaded(:final pets) => pets,
      PetOperationSuccess(:final pets) => pets,
      _ => const <Pet>[],
    };
    final hasAnotherPet = pets.any((candidate) => candidate.id != pet.id);
    if (selectedPet?.id == pet.id && hasAnotherPet) {
      final candidates =
          pets.where((candidate) => candidate.id != pet.id).toList();
      final replacement = await _showPrimaryReplacementDialog(
        deletionTarget: pet,
        candidates: candidates,
      );
      if (replacement == null || !mounted) return;
      _pendingDeleteAfterPrimaryChange = pet;
      _pendingPrimaryForDeletionId = replacement.id;
      petBloc.add(SelectPet(replacement));
      return;
    }
    _showDeleteConfirmation(pet);
  }

  Future<Pet?> _showPrimaryReplacementDialog({
    required Pet deletionTarget,
    required List<Pet> candidates,
  }) {
    return showDialog<Pet>(
      context: context,
      builder: (dialogContext) {
        var selectedId = candidates.first.id;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => Dialog(
            key: const Key('pet_primary_delete_gate_dialog'),
            insetPadding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: MediaQuery.sizeOf(dialogContext).height - 32,
              ),
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '새 대표 반려동물을 선택해 주세요',
                              style: TextStyle(
                                fontSize: AppTheme.fontHeading.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              '대표 반려동물을 삭제하기 전에 다른 반려동물을 대표로 설정해야 해요.',
                              style: TextStyle(
                                fontSize: AppTheme.fontBody.sp,
                                height: 1.45,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              '삭제할 반려동물',
                              style: TextStyle(
                                fontSize: AppTheme.fontCaption.sp,
                                color: Theme.of(
                                  dialogContext,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              deletionTarget.name,
                              key: const Key('pet_pending_delete_target'),
                              style: TextStyle(
                                fontSize: AppTheme.fontHeading.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 18.h),
                            ...candidates.map(
                              (candidate) => Padding(
                                padding: EdgeInsets.only(bottom: 8.h),
                                child: Semantics(
                                  label: '대표로 선택할 반려동물: ${candidate.name}',
                                  button: true,
                                  selected: selectedId == candidate.id,
                                  inMutuallyExclusiveGroup: true,
                                  child: Material(
                                    color: selectedId == candidate.id
                                        ? AppTheme.actionContainer
                                        : Theme.of(
                                            dialogContext,
                                          ).colorScheme.surface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMd.r,
                                      ),
                                      side: BorderSide(
                                        color: selectedId == candidate.id
                                            ? AppTheme.actionBase
                                            : Theme.of(
                                                dialogContext,
                                              ).colorScheme.outlineVariant,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      key: Key(
                                        'pet_primary_candidate_${candidate.id}',
                                      ),
                                      excludeFromSemantics: true,
                                      onTap: () => setDialogState(
                                        () => selectedId = candidate.id,
                                      ),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minHeight: 56,
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 14.w,
                                            vertical: 10.h,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                selectedId == candidate.id
                                                    ? Icons.radio_button_checked
                                                    : Icons
                                                        .radio_button_unchecked,
                                                color: AppTheme.actionBase,
                                              ),
                                              SizedBox(width: 10.w),
                                              Expanded(
                                                child: Text(
                                                  candidate.name,
                                                  style: TextStyle(
                                                    fontSize:
                                                        AppTheme.fontBody.sp,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    FilledButton(
                      key: const Key('pet_primary_delete_gate_confirm'),
                      onPressed: () => Navigator.of(dialogContext).pop(
                        candidates.firstWhere(
                          (candidate) => candidate.id == selectedId,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('대표로 선택하고 계속'),
                    ),
                    SizedBox(height: 8.h),
                    TextButton(
                      key: const Key('pet_primary_delete_gate_cancel'),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('취소'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _resumePendingDeletion(PetLoaded state) {
    final target = _pendingDeleteAfterPrimaryChange;
    final expectedPrimaryId = _pendingPrimaryForDeletionId;
    if (target == null ||
        expectedPrimaryId == null ||
        state.selectedPet?.id != expectedPrimaryId) {
      return;
    }
    Pet? freshTarget;
    for (final pet in state.pets) {
      if (pet.id == target.id) {
        freshTarget = pet;
        break;
      }
    }
    _pendingDeleteAfterPrimaryChange = null;
    _pendingPrimaryForDeletionId = null;
    if (freshTarget == null || freshTarget.id == state.selectedPet?.id) {
      _showFeedback(
        '삭제할 반려동물 정보를 다시 확인해 주세요.',
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showDeleteConfirmation(freshTarget!);
    });
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
    final currentState = petBloc.state;
    final pets = switch (currentState) {
      PetLoaded(:final pets) => pets,
      PetOperationSuccess(:final pets) => pets,
      _ => const <Pet>[],
    };
    final isLastPet = pets.length == 1 && pets.single.id == pet.id;

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
              if (isLastPet) ...[
                SizedBox(height: 10.h),
                _buildDeleteImpact(
                  icon: Icons.person_off_outlined,
                  title: '마지막 반려동물이에요',
                  description: '삭제하면 대표 반려동물이 해제되고 홈·건강 화면에서 선택할 반려동물이 없어집니다.',
                  color: AppTheme.errorColor,
                ),
              ],
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
