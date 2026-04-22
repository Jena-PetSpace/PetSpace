import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../pets/domain/entities/pet.dart';

/// AI 분석 / AI 히스토리 공용 인라인 드롭다운
/// - 터치 시 아래로 옵션 목록이 펼쳐짐
/// - 이미지가 있으면 실제 사진, 없으면 이모지 + 발바닥 fallback
class PetInlineDropdown extends StatefulWidget {
  final List<Pet> pets;
  final Pet? selectedPet;
  final bool showUnregistered;
  final ValueChanged<Pet?> onPetSelected;       // null = 미등록 선택
  final ValueChanged<bool> onUnregisteredChanged;

  const PetInlineDropdown({
    super.key,
    required this.pets,
    required this.selectedPet,
    required this.showUnregistered,
    required this.onPetSelected,
    required this.onUnregisteredChanged,
  });

  @override
  State<PetInlineDropdown> createState() => _PetInlineDropdownState();
}

class _PetInlineDropdownState extends State<PetInlineDropdown> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: _expanded
              ? AppTheme.primaryColor.withValues(alpha: 0.5)
              : AppTheme.dividerColor,
        ),
        boxShadow: _expanded
            ? [BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )]
            : [],
      ),
      child: Column(children: [
        // ── 선택된 항목 (항상 보임) ──────────────────────────
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(12.r),
            bottom: _expanded ? Radius.zero : Radius.circular(12.r),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            child: Row(children: [
              _avatar(widget.showUnregistered ? null : widget.selectedPet, 36.w),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.showUnregistered
                          ? '등록된 반려동물 없이 분석'
                          : (widget.selectedPet?.name ?? '반려동물을 선택해주세요'),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: (widget.selectedPet == null && !widget.showUnregistered)
                            ? AppTheme.secondaryTextColor
                            : AppTheme.primaryTextColor,
                      ),
                    ),
                    if (!widget.showUnregistered && widget.selectedPet != null)
                      Text(
                        '${widget.selectedPet!.typeDisplayName} · '
                        '${widget.selectedPet!.breed ?? '품종 미상'} · '
                        '${widget.selectedPet!.displayAge}',
                        style: TextStyle(
                            fontSize: 10.sp,
                            color: AppTheme.secondaryTextColor),
                      ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down,
                    color: AppTheme.secondaryTextColor, size: 20.w),
              ),
            ]),
          ),
        ),

        // ── 펼쳐지는 옵션 목록 ───────────────────────────────
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(children: [
            const Divider(height: 1),
            ...widget.pets.map((pet) {
              final isSelected =
                  !widget.showUnregistered && widget.selectedPet?.id == pet.id;
              return _optionTile(
                avatar: _avatar(pet, 40.w),
                title: pet.name,
                subtitle: '${pet.typeDisplayName} · '
                    '${pet.breed ?? '품종 미상'} · '
                    '${pet.displayAge}',
                isSelected: isSelected,
                onTap: () {
                  setState(() => _expanded = false);
                  widget.onPetSelected(pet);
                },
              );
            }),
            const Divider(height: 1),
            _optionTile(
              avatar: _avatar(null, 40.w),
              title: '등록된 반려동물 없이 분석',
              subtitle: '특정 반려동물을 선택하지 않고 분석한 경우',
              isSelected: widget.showUnregistered,
              onTap: () {
                setState(() => _expanded = false);
                widget.onUnregisteredChanged(true);
              },
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _optionTile({
    required Widget avatar,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.04)
            : Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        child: Row(children: [
          avatar,
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.primaryTextColor,
                    )),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 10.sp,
                        color: AppTheme.secondaryTextColor)),
              ],
            ),
          ),
          if (isSelected)
            Icon(Icons.check_circle,
                color: AppTheme.primaryColor, size: 18.w),
        ]),
      ),
    );
  }

  Widget _avatar(Pet? pet, double size) {
    if (pet?.avatarUrl != null && pet!.avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          pet.avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarFallback(pet, size),
        ),
      );
    }
    return _avatarFallback(pet, size);
  }

  Widget _avatarFallback(Pet? pet, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: pet == null
            ? Colors.grey.shade100
            : AppTheme.primaryColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: pet == null
            ? Icon(Icons.pets, color: AppTheme.secondaryTextColor, size: size * 0.48)
            : Text(
                pet.type == PetType.dog ? '🐶' : '🐱',
                style: TextStyle(fontSize: size * 0.45),
              ),
      ),
    );
  }
}
