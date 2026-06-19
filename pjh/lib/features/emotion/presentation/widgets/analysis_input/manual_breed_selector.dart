import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../shared/themes/app_theme.dart';

/// 반려동물 미선택(미등록) 분석 시의 수동 종/품종 선택 위젯.
/// - 종류 칩(강아지/고양이) + 품종 Autocomplete(목록 검색·선택) + '기타' 선택 시 직접 입력
/// 상태(_manualPetType·_manualBreed)는 부모가 관리, 위젯은 표시 + 콜백 전달만.
/// 종류 변경 시 부모는 품종을 리셋(_manualBreed=null·customBreedCtrl.clear())한다.
class ManualBreedSelector extends StatelessWidget {
  final String? selectedType;
  final String? selectedBreed;
  final TextEditingController customBreedCtrl;
  final void Function(String) onTypeSelected;
  final void Function(String?) onBreedSelected;

  const ManualBreedSelector({
    super.key,
    required this.selectedType,
    required this.selectedBreed,
    required this.customBreedCtrl,
    required this.onTypeSelected,
    required this.onBreedSelected,
  });

  // 품종 데이터
  static const Map<String, List<String>> _breedsByType = {
    'dog': [
      '골든 리트리버',
      '래브라도 리트리버',
      '비글',
      '시바견',
      '진돗개',
      '포메라니안',
      '말티즈',
      '푸들',
      '치와와',
      '요크셔테리어',
      '시츄',
      '웰시코기',
      '보더콜리',
      '허스키',
      '사모예드',
      '기타',
    ],
    'cat': [
      '코리안 숏헤어',
      '페르시안',
      '러시안 블루',
      '브리티시 숏헤어',
      '스코티시 폴드',
      '아메리칸 숏헤어',
      '샴',
      '뱅갈',
      '메인쿤',
      '노르웨이 숲',
      '랙돌',
      '터키시 앙고라',
      '기타',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final breeds = selectedType != null
        ? _breedsByType[selectedType] ?? []
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '종류 선택 (선택사항)',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.secondaryTextColor,
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            _TypeChip(
              type: 'dog',
              label: '강아지',
              selectedType: selectedType,
              onSelected: onTypeSelected,
            ),
            SizedBox(width: 8.w),
            _TypeChip(
              type: 'cat',
              label: '고양이',
              selectedType: selectedType,
              onSelected: onTypeSelected,
            ),
          ],
        ),
        if (selectedType != null && breeds.isNotEmpty) ...[
          SizedBox(height: 12.h),
          Autocomplete<String>(
            key: ValueKey('breed_${selectedType}_$selectedBreed'),
            initialValue: TextEditingValue(
              text: (selectedBreed != null && selectedBreed != '기타') ? selectedBreed! : '',
            ),
            optionsBuilder: (textEditingValue) {
              final query = textEditingValue.text.trim();
              if (query.isEmpty) return breeds;
              return breeds.where(
                (b) => b.contains(query),
              );
            },
            displayStringForOption: (b) => b,
            onSelected: (value) {
              onBreedSelected(value);
              customBreedCtrl.clear();
              FocusScope.of(context).unfocus();
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: TextStyle(fontSize: 13.sp),
                decoration: InputDecoration(
                  labelText: '품종',
                  labelStyle: TextStyle(fontSize: 13.sp),
                  hintText: '입력하여 검색하거나 목록에서 선택',
                  hintStyle: TextStyle(fontSize: 12.sp, color: AppTheme.neutral500),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 10.h,
                  ),
                  isDense: true,
                  suffixIcon: selectedBreed != null
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 16.w, color: AppTheme.neutral500),
                          onPressed: () {
                            onBreedSelected(null);
                            customBreedCtrl.clear();
                            controller.clear();
                          },
                        )
                      : Icon(Icons.arrow_drop_down, size: 20.w, color: AppTheme.neutral500),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 64.w,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(10.r),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 200.h),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          final isSelected = selectedBreed == option;
                          return GestureDetector(
                            onTap: () => onSelected(option),
                            child: Container(
                              width: double.infinity,
                              color: isSelected
                                  ? AppTheme.primaryColor.withValues(alpha: 0.08)
                                  : Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 13.h),
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : AppTheme.primaryTextColor,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (selectedBreed == '기타') ...[
            SizedBox(height: 8.h),
            TextField(
              controller: customBreedCtrl,
              style: TextStyle(fontSize: 13.sp),
              decoration: InputDecoration(
                labelText: '품종 직접 입력',
                labelStyle: TextStyle(fontSize: 13.sp),
                hintText: '예: 비숑프리제',
                hintStyle: TextStyle(fontSize: 12.sp, color: AppTheme.neutral500),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w, vertical: 10.h),
                isDense: true,
              ),
            ),
          ],
        ],
        SizedBox(height: 4.h),
        Text(
          '품종을 선택하면 더 정확한 분석이 가능해요',
          style: TextStyle(fontSize: 11.sp, color: AppTheme.neutral500),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String type;
  final String label;
  final String? selectedType;
  final void Function(String) onSelected;

  const _TypeChip({
    required this.type,
    required this.label,
    required this.selectedType,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedType == type;
    return GestureDetector(
      onTap: () => onSelected(type),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : AppTheme.neutral100,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.neutral300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.primaryColor : AppTheme.neutral600,
          ),
        ),
      ),
    );
  }
}
