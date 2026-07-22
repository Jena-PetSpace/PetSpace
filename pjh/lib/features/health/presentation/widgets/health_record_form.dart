import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/health_record.dart';
import 'health_record_data.dart';

class HealthRecordFormControllers {
  final title = TextEditingController();
  final memo = TextEditingController();
  final weight = TextEditingController();
  final vaccineType = TextEditingController();
  final hospital = TextEditingController();
  final medicationName = TextEditingController();
  final dosage = TextEditingController();
  final checkupResult = TextEditingController();
  final cost = TextEditingController();
  final surgeryName = TextEditingController();

  int? bcs;
  String? frequency;

  HealthRecordFormControllers({HealthRecord? record}) {
    if (record == null) return;
    title.text = record.title;
    memo.text = record.description ?? '';
    final data = record.data;
    final weightValue = data['weight_kg'];
    if (weightValue is num) weight.text = weightValue.toString();
    final bcsValue = data['bcs'];
    if (bcsValue is num) bcs = bcsValue.toInt();
    vaccineType.text = (data['vaccine_type'] as String?) ?? '';
    hospital.text = (data['hospital'] as String?) ?? '';
    medicationName.text = (data['med_name'] as String?) ?? '';
    dosage.text = (data['dosage'] as String?) ?? '';
    frequency = data['frequency'] as String?;
    checkupResult.text = (data['result'] as String?) ?? '';
    final costValue = data['cost'];
    if (costValue is num) cost.text = costValue.toInt().toString();
    surgeryName.text = (data['surgery_name'] as String?) ?? '';
  }

  void dispose() {
    title.dispose();
    memo.dispose();
    weight.dispose();
    vaccineType.dispose();
    hospital.dispose();
    medicationName.dispose();
    dosage.dispose();
    checkupResult.dispose();
    cost.dispose();
    surgeryName.dispose();
  }
}

class HealthRecordFormErrors {
  final String? primary;
  final String? cost;
  final String? nextDate;

  const HealthRecordFormErrors({this.primary, this.cost, this.nextDate});

  bool get hasAny => primary != null || cost != null || nextDate != null;
}

class HealthRecordForm extends StatelessWidget {
  final HealthRecordType selectedType;
  final HealthRecordStatus selectedStatus;
  final HealthRecordFormControllers controllers;
  final DateTime recordDate;
  final DateTime? nextDate;
  final HealthRecordFormErrors errors;
  final ValueChanged<HealthRecordType> onTypeChanged;
  final ValueChanged<HealthRecordStatus> onStatusChanged;
  final ValueChanged<int?> onBcsChanged;
  final ValueChanged<String?> onFrequencyChanged;
  final VoidCallback onRecordDatePressed;
  final VoidCallback onNextDatePressed;
  final VoidCallback onClearNextDate;
  final bool enabled;

  const HealthRecordForm({
    super.key,
    required this.selectedType,
    required this.selectedStatus,
    required this.controllers,
    required this.recordDate,
    required this.nextDate,
    required this.errors,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onBcsChanged,
    required this.onFrequencyChanged,
    required this.onRecordDatePressed,
    required this.onNextDatePressed,
    required this.onClearNextDate,
    this.enabled = true,
  });

  static const _types = <(HealthRecordType, String)>[
    (HealthRecordType.vaccination, '예방접종'),
    (HealthRecordType.checkup, '건강검진'),
    (HealthRecordType.weight, '체중'),
    (HealthRecordType.medication, '투약'),
    (HealthRecordType.surgery, '수술'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, '기록 유형', '필수'),
        SizedBox(height: 8.h),
        SizedBox(
          height: 44,
          child: ListView.separated(
            key: const Key('health_record_type_selector'),
            scrollDirection: Axis.horizontal,
            itemCount: _types.length,
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              final (type, label) = _types[index];
              return ChoiceChip(
                key: Key('health_type_${type.name}'),
                label: Text(label),
                selected: selectedType == type,
                onSelected: enabled ? (_) => onTypeChanged(type) : null,
                showCheckmark: false,
                selectedColor: AppTheme.actionBase,
                labelStyle: TextStyle(
                  color: selectedType == type
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: AppTheme.fontCaption.sp,
                ),
                side: BorderSide(
                  color: selectedType == type
                      ? AppTheme.actionBase
                      : AppTheme.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 22.h),
        _typeFields(context),
        SizedBox(height: 18.h),
        _label(context, '기록 날짜', '필수'),
        SizedBox(height: 8.h),
        _dateField(
          key: const Key('health_record_date_field'),
          context: context,
          value: _formatDate(recordDate),
          onTap: onRecordDatePressed,
        ),
        SizedBox(height: 16.h),
        _label(context, '다음 예정일', '선택'),
        SizedBox(height: 8.h),
        _dateField(
          key: const Key('health_next_date_field'),
          context: context,
          value: nextDate == null ? '날짜 선택' : _formatDate(nextDate!),
          muted: nextDate == null,
          onTap: onNextDatePressed,
          trailing: nextDate == null
              ? const Icon(Icons.chevron_right)
              : IconButton(
                  key: const Key('health_next_date_clear'),
                  tooltip: '다음 예정일 해제',
                  onPressed: enabled ? onClearNextDate : null,
                  icon: const Icon(Icons.close, size: 20),
                ),
        ),
        if (errors.nextDate != null) _errorText(errors.nextDate!),
        SizedBox(height: 18.h),
        _label(context, '상태', '필수'),
        SizedBox(height: 8.h),
        Wrap(
          key: const Key('health_record_status_selector'),
          spacing: 8.w,
          runSpacing: 8.h,
          children: HealthRecordStatus.values.map((status) {
            final selected = status == selectedStatus;
            return ChoiceChip(
              key: Key('health_status_${status.name}'),
              label: Text(_statusLabel(status)),
              selected: selected,
              onSelected: enabled ? (_) => onStatusChanged(status) : null,
              showCheckmark: false,
              selectedColor: AppTheme.actionContainer,
              labelStyle: TextStyle(
                color: selected
                    ? AppTheme.brandDeep
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              side: BorderSide(
                color: selected ? AppTheme.actionBase : AppTheme.border,
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 18.h),
        _label(context, '기록 이름', '선택'),
        SizedBox(height: 8.h),
        _textField(
          key: const Key('health_record_title_field'),
          controller: controllers.title,
          hint: _defaultTitleHint(selectedType),
        ),
        SizedBox(height: 16.h),
        _label(context, '메모', '선택'),
        SizedBox(height: 8.h),
        _textField(
          key: const Key('health_record_memo_field'),
          controller: controllers.memo,
          hint: '특이사항이나 보호자가 기억할 내용을 남겨주세요.',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _typeFields(BuildContext context) {
    switch (selectedType) {
      case HealthRecordType.vaccination:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(context, '백신 종류', '필수'),
            SizedBox(height: 8.h),
            _textField(
              key: const Key('health_vaccine_type_field'),
              controller: controllers.vaccineType,
              hint: '예: 종합 예방접종',
              error: errors.primary,
            ),
            SizedBox(height: 16.h),
            _label(context, '병원', '선택'),
            SizedBox(height: 8.h),
            _textField(
              key: const Key('health_hospital_field'),
              controller: controllers.hospital,
              hint: '동물병원 이름',
            ),
          ],
        );
      case HealthRecordType.checkup:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(context, '병원', '선택'),
            SizedBox(height: 8.h),
            _textField(
              key: const Key('health_hospital_field'),
              controller: controllers.hospital,
              hint: '동물병원 이름',
            ),
            SizedBox(height: 16.h),
            _label(context, '결과·소견', '선택'),
            SizedBox(height: 8.h),
            _textField(
              key: const Key('health_checkup_result_field'),
              controller: controllers.checkupResult,
              hint: '보호자가 확인한 내용을 기록하세요.',
              maxLines: 2,
            ),
            SizedBox(height: 16.h),
            _label(context, '비용', '선택 · 원'),
            SizedBox(height: 8.h),
            _textField(
              key: const Key('health_cost_field'),
              controller: controllers.cost,
              hint: '예: 50000',
              keyboardType: TextInputType.number,
              error: errors.cost,
            ),
          ],
        );
      case HealthRecordType.weight:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(context, '체중', '필수 · kg'),
            SizedBox(height: 8.h),
            _textField(
              key: const Key('health_weight_field'),
              controller: controllers.weight,
              hint: '0보다 큰 숫자',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              error: errors.primary,
            ),
            SizedBox(height: 16.h),
            _label(context, 'BCS', '선택 · 1~9'),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: List.generate(9, (index) {
                final value = index + 1;
                final selected = controllers.bcs == value;
                return ChoiceChip(
                  key: Key('health_bcs_$value'),
                  label: Text('$value'),
                  selected: selected,
                  onSelected: enabled
                      ? (_) => onBcsChanged(selected ? null : value)
                      : null,
                  showCheckmark: false,
                  selectedColor: AppTheme.actionContainer,
                  side: BorderSide(
                    color: selected ? AppTheme.actionBase : AppTheme.border,
                  ),
                );
              }),
            ),
          ],
        );
      case HealthRecordType.medication:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(context, '약 이름', '필수'),
            SizedBox(height: 8.h),
            _textField(
              key: const Key('health_medication_name_field'),
              controller: controllers.medicationName,
              hint: '약 이름',
              error: errors.primary,
            ),
            SizedBox(height: 16.h),
            _label(context, '용량', '선택'),
            SizedBox(height: 8.h),
            _textField(
              key: const Key('health_dosage_field'),
              controller: controllers.dosage,
              hint: '예: 1정',
            ),
            SizedBox(height: 16.h),
            _label(context, '반복 주기', '선택'),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: medicationFrequencies.map((frequency) {
                final selected = controllers.frequency == frequency;
                return ChoiceChip(
                  key: Key('health_frequency_$frequency'),
                  label: Text(frequency),
                  selected: selected,
                  onSelected: enabled
                      ? (_) => onFrequencyChanged(selected ? null : frequency)
                      : null,
                  showCheckmark: false,
                  selectedColor: AppTheme.actionContainer,
                  side: BorderSide(
                    color: selected ? AppTheme.actionBase : AppTheme.border,
                  ),
                );
              }).toList(),
            ),
          ],
        );
      case HealthRecordType.surgery:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(context, '수술명', '필수'),
            SizedBox(height: 8.h),
            _textField(
              key: const Key('health_surgery_name_field'),
              controller: controllers.surgeryName,
              hint: '수술명',
              error: errors.primary,
            ),
            SizedBox(height: 16.h),
            _label(context, '병원', '선택'),
            SizedBox(height: 8.h),
            _textField(
              key: const Key('health_hospital_field'),
              controller: controllers.hospital,
              hint: '동물병원 이름',
            ),
          ],
        );
    }
  }

  Widget _label(BuildContext context, String title, String qualifier) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: AppTheme.fontBody.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
        SizedBox(width: 6.w),
        Text(
          qualifier,
          style: TextStyle(
            fontSize: AppTheme.fontMicro.sp,
            color: qualifier.startsWith('필수')
                ? AppTheme.errorColor
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _textField({
    required Key key,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? error,
    int maxLines = 1,
  }) {
    return TextField(
      key: key,
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      decoration: InputDecoration(
        hintText: hint,
        errorText: error,
        errorMaxLines: 2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
      ),
    );
  }

  Widget _dateField({
    required Key key,
    required BuildContext context,
    required String value,
    required VoidCallback onTap,
    bool muted = false,
    Widget? trailing,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        key: key,
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: EdgeInsets.only(left: 14.w, right: 6.w),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: AppTheme.actionBase,
                  size: 20,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: AppTheme.fontBody.sp,
                      color: muted
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                trailing ?? const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorText(String value) {
    return Padding(
      padding: EdgeInsets.only(left: 12.w, top: 6.h),
      child: Text(
        value,
        style: TextStyle(color: AppTheme.errorColor, fontSize: 12.sp),
      ),
    );
  }

  String _formatDate(DateTime value) =>
      '${value.year}년 ${value.month}월 ${value.day}일';

  String _statusLabel(HealthRecordStatus status) => switch (status) {
        HealthRecordStatus.scheduled => '예정',
        HealthRecordStatus.completed => '완료',
        HealthRecordStatus.overdue => '지남',
        HealthRecordStatus.cancelled => '취소',
      };

  String _defaultTitleHint(HealthRecordType type) => switch (type) {
        HealthRecordType.vaccination => '비워두면 백신 종류로 저장',
        HealthRecordType.checkup => '비워두면 건강검진으로 저장',
        HealthRecordType.weight => '비워두면 체중으로 자동 생성',
        HealthRecordType.medication => '비워두면 약 이름으로 저장',
        HealthRecordType.surgery => '비워두면 수술명으로 저장',
      };
}
