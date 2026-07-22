import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';

/// 반려동물 추가·수정 시트(UIUX Wave 1B) 전용 표시 컴포넌트.
/// 저장·업로드·라우팅 등 비즈니스 의미를 갖지 않는 UI 전용 위젯만 둔다.

/// 최소 터치 영역(논리 px). ScreenUtil 축소 배율과 무관하게 보장한다.
const double kPetEditorMinTouchTarget = 44.0;

/// 입력 필드 공통 테두리(입력 radius 8 역할).
const OutlineInputBorder petEditorInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
);

/// bottom sheet 상단 드래그 handle.
class PetEditorSheetHandle extends StatelessWidget {
  const PetEditorSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 10.h, bottom: 2.h),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

/// 폼 section 컨테이너.
/// [collapsible]이 false면 heading + children 구성으로,
/// true면 header 탭으로 [onToggle]을 호출하는 접을 수 있는 카드로 렌더링한다.
class PetEditorSection extends StatelessWidget {
  const PetEditorSection({
    super.key,
    required this.title,
    this.caption,
    this.leadingIcon,
    this.collapsible = false,
    this.expanded = true,
    this.onToggle,
    this.toggleKey,
    required this.children,
  });

  final String title;
  final String? caption;
  final IconData? leadingIcon;
  final bool collapsible;
  final bool expanded;
  final VoidCallback? onToggle;
  final Key? toggleKey;
  final List<Widget> children;

  List<Widget> _spacedChildren() {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        spaced.add(SizedBox(height: 16.h));
      }
      spaced.add(children[i]);
    }
    return spaced;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!collapsible) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 16.h),
          ..._spacedChildren(),
        ],
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: toggleKey,
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  child: Row(
                    children: [
                      if (leadingIcon != null) ...[
                        Icon(leadingIcon, size: 20, color: AppTheme.actionBase),
                        SizedBox(width: 10.w),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (caption != null) ...[
                              SizedBox(height: 3.h),
                              Text(
                                caption!,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _spacedChildren(),
              ),
            ),
        ],
      ),
    );
  }
}

/// segmented control 선택지 표시 모델.
class PetEditorSegmentOption<T> {
  const PetEditorSegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// 단일 선택 segmented control. 탭하면 항상 [onSelected]가 호출된다
/// (같은 값 재선택 시에도 호출 — 기존 RadioGroup onChanged 의미 유지).
class PetEditorSegmentedChoice<T> extends StatelessWidget {
  const PetEditorSegmentedChoice({
    super.key,
    required this.options,
    this.selectedValue,
    required this.onSelected,
  });

  final List<PetEditorSegmentOption<T>> options;
  final T? selectedValue;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) SizedBox(width: 8.w),
          Expanded(
            child: _SegmentItem<T>(
              option: options[i],
              selected: options[i].value == selectedValue,
              onSelected: onSelected,
            ),
          ),
        ],
      ],
    );
  }
}

class _SegmentItem<T> extends StatelessWidget {
  const _SegmentItem({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  final PetEditorSegmentOption<T> option;
  final bool selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(8);

    return Semantics(
      button: true,
      selected: selected,
      child: Container(
        key: ValueKey<T>(option.value),
        constraints: const BoxConstraints(minHeight: kPetEditorMinTouchTarget),
        decoration: BoxDecoration(
          color: selected ? AppTheme.actionBase : Colors.transparent,
          borderRadius: borderRadius,
          border: Border.all(
            color: selected ? AppTheme.actionBase : colorScheme.outlineVariant,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: () => onSelected(option.value),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                child: Text(
                  option.label,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Colors.white : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
