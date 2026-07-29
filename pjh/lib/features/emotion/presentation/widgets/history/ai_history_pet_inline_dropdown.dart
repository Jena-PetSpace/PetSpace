import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../shared/themes/app_theme.dart';
import '../../../../pets/domain/entities/pet.dart';
import '../../../domain/entities/ai_history.dart';
import '../pet_selection_primitives.dart';

/// AI 분석 기록에서 사용하는 인라인 반려동물 범위 선택기.
///
/// AI 분석 입력 화면과 동일하게 현재 선택 영역 아래로 옵션이 펼쳐진다.
/// 기록 탭에서는 전체·개별·연결 안 된 범위를 제공하고, 흐름 탭에서는
/// 아이별 흐름만 의미가 있으므로 등록된 반려동물만 제공한다.
class AiHistoryPetInlineDropdown extends StatefulWidget {
  final List<Pet> pets;
  final AiHistoryPetScope scope;
  final bool flowMode;
  final bool enabled;
  final ValueChanged<AiHistoryPetScope> onChanged;

  const AiHistoryPetInlineDropdown({
    super.key,
    required this.pets,
    required this.scope,
    required this.flowMode,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<AiHistoryPetInlineDropdown> createState() =>
      _AiHistoryPetInlineDropdownState();
}

class _AiHistoryPetInlineDropdownState
    extends State<AiHistoryPetInlineDropdown> {
  bool _expanded = false;

  Pet? get _selectedPet {
    if (widget.scope.kind != AiHistoryPetScopeKind.registered) return null;
    for (final pet in widget.pets) {
      if (pet.id == widget.scope.petId) return pet;
    }
    return null;
  }

  bool get _hasFlowSelection =>
      widget.flowMode && widget.scope.kind == AiHistoryPetScopeKind.registered;

  @override
  void didUpdateWidget(covariant AiHistoryPetInlineDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled ||
        oldWidget.flowMode != widget.flowMode ||
        oldWidget.scope != widget.scope) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: _expanded
              ? AppTheme.primaryColor.withValues(alpha: 0.5)
              : AppTheme.border,
        ),
        boxShadow: _expanded
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : const [],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.enabled
                ? () => setState(() => _expanded = !_expanded)
                : null,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(12.r),
              bottom: _expanded ? Radius.zero : Radius.circular(12.r),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Row(
                children: [
                  _headerAvatar(),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _headerTitle(),
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: _hasVisibleSelection
                                ? AppTheme.primaryTextColor
                                : AppTheme.secondaryTextColor,
                          ),
                        ),
                        Text(
                          _headerSubtitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      widget.enabled
                          ? Icons.keyboard_arrow_down
                          : Icons.error_outline,
                      color: AppTheme.secondaryTextColor,
                      size: 20.w,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 320.h),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: _buildOptions(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasVisibleSelection {
    if (_hasFlowSelection) return true;
    if (widget.flowMode) return false;
    return true;
  }

  Widget _headerAvatar() {
    if (_selectedPet != null) {
      return PetSelectionAvatar(pet: _selectedPet, size: 40.w);
    }
    if (widget.flowMode) {
      return PetSelectionAvatar(
        pet: null,
        size: 40.w,
        fallbackIcon: Icons.pets,
      );
    }
    return PetSelectionAvatar(
      pet: null,
      size: 40.w,
      fallbackIcon: widget.scope.kind == AiHistoryPetScopeKind.unlinked
          ? Icons.link_off_rounded
          : Icons.apps_rounded,
      backgroundColor: AppTheme.actionContainer,
    );
  }

  String _headerTitle() {
    if (_selectedPet != null) return _selectedPet!.name;
    if (widget.flowMode) return '반려동물을 선택해주세요';
    return widget.scope.kind == AiHistoryPetScopeKind.unlinked
        ? '연결 안 된 기록'
        : '전체 기록';
  }

  String _headerSubtitle() {
    if (_selectedPet != null) return petSelectionMeta(_selectedPet!);
    if (!widget.enabled) return '반려동물 목록을 불러오지 못했어요';
    if (widget.flowMode) return '아이별 분석 흐름을 확인해요';
    return widget.scope.kind == AiHistoryPetScopeKind.unlinked
        ? '현재 목록과 연결되지 않은 분석 기록'
        : '모든 반려동물의 분석 기록';
  }

  List<Widget> _buildOptions() {
    final options = <Widget>[];

    if (!widget.flowMode) {
      options.add(
        _optionTile(
          avatar: PetSelectionAvatar(
            pet: null,
            size: 44.w,
            fallbackIcon: Icons.apps_rounded,
            backgroundColor: AppTheme.actionContainer,
          ),
          title: '전체 기록',
          subtitle: '모든 반려동물의 분석 기록',
          selected: widget.scope.kind == AiHistoryPetScopeKind.all,
          onTap: () => _select(const AiHistoryPetScope.all()),
        ),
      );
    }

    for (final pet in widget.pets) {
      options.add(
        _optionTile(
          avatar: PetSelectionAvatar(pet: pet, size: 44.w),
          title: pet.name,
          subtitle: petSelectionMeta(pet),
          selected:
              widget.scope.kind == AiHistoryPetScopeKind.registered &&
              widget.scope.petId == pet.id,
          onTap: () => _select(AiHistoryPetScope.registered(pet.id)),
        ),
      );
    }

    if (!widget.flowMode) {
      options.add(
        _optionTile(
          avatar: PetSelectionAvatar(
            pet: null,
            size: 44.w,
            fallbackIcon: Icons.link_off_rounded,
            backgroundColor: AppTheme.actionContainer,
          ),
          title: '연결 안 된 기록',
          subtitle: '현재 반려동물 목록과 연결되지 않은 분석 기록',
          selected: widget.scope.kind == AiHistoryPetScopeKind.unlinked,
          onTap: () => _select(const AiHistoryPetScope.unlinked()),
        ),
      );
    }

    if (options.isEmpty) {
      return [
        const Divider(height: 1, color: AppTheme.dividerColor),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
          child: Text(
            '등록된 반려동물이 없어요.',
            style: TextStyle(
              fontSize: 13.sp,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ),
      ];
    }

    final separated = <Widget>[
      const Divider(height: 1, color: AppTheme.dividerColor),
    ];
    for (var index = 0; index < options.length; index++) {
      separated.add(options[index]);
      if (index < options.length - 1) {
        separated.add(const Divider(height: 1, color: AppTheme.dividerColor));
      }
    }
    return separated;
  }

  Widget _optionTile({
    required Widget avatar,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected
            ? AppTheme.primaryColor.withValues(alpha: 0.04)
            : Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        child: Row(
          children: [
            avatar,
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppTheme.primaryColor
                          : AppTheme.primaryTextColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
                size: 18.w,
              ),
          ],
        ),
      ),
    );
  }

  void _select(AiHistoryPetScope scope) {
    setState(() => _expanded = false);
    widget.onChanged(scope);
  }
}
