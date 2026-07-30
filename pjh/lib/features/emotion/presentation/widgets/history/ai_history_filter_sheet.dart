import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../shared/themes/app_theme.dart';
import '../../../domain/entities/ai_history.dart';

class AiHistoryFilterSelection {
  final AiHistoryTypeFilter type;
  final AiHistoryDateRange dateRange;
  final bool healthAttentionOnly;

  const AiHistoryFilterSelection({
    required this.type,
    required this.dateRange,
    required this.healthAttentionOnly,
  });
}

class AiHistoryFilterSheet extends StatefulWidget {
  final AiHistoryFilterSelection initial;
  final bool emotionOnly;

  const AiHistoryFilterSheet({
    super.key,
    required this.initial,
    this.emotionOnly = false,
  });

  static Future<AiHistoryFilterSelection?> show(
    BuildContext context, {
    required AiHistoryFilterSelection initial,
    bool emotionOnly = false,
  }) {
    return showModalBottomSheet<AiHistoryFilterSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => SafeArea(
        top: false,
        minimum: EdgeInsets.only(bottom: 12.h),
        child: SingleChildScrollView(
          child: AiHistoryFilterSheet(
            initial: initial,
            emotionOnly: emotionOnly,
          ),
        ),
      ),
    );
  }

  @override
  State<AiHistoryFilterSheet> createState() => _AiHistoryFilterSheetState();
}

class _AiHistoryFilterSheetState extends State<AiHistoryFilterSheet> {
  late AiHistoryTypeFilter _type;
  late AiHistoryDateRange _dateRange;
  late bool _attentionOnly;

  @override
  void initState() {
    super.initState();
    _type =
        widget.emotionOnly ? AiHistoryTypeFilter.emotion : widget.initial.type;
    _dateRange = widget.initial.dateRange;
    _attentionOnly =
        widget.emotionOnly ? false : widget.initial.healthAttentionOnly;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '기록 필터',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 22.h),
          if (!widget.emotionOnly) ...[
            _label('분석 유형'),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _choiceChip(
                  '전체',
                  _type == AiHistoryTypeFilter.all,
                  () => _setType(AiHistoryTypeFilter.all),
                ),
                _choiceChip(
                  '감정',
                  _type == AiHistoryTypeFilter.emotion,
                  () => _setType(AiHistoryTypeFilter.emotion),
                ),
                _choiceChip(
                  '건강',
                  _type == AiHistoryTypeFilter.health,
                  () => _setType(AiHistoryTypeFilter.health),
                ),
              ],
            ),
            SizedBox(height: 22.h),
          ],
          _label('기간'),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _choiceChip(
                '전체 기간',
                _dateRange == AiHistoryDateRange.all,
                () => _setDate(AiHistoryDateRange.all),
              ),
              _choiceChip(
                '7일',
                _dateRange == AiHistoryDateRange.last7Days,
                () => _setDate(AiHistoryDateRange.last7Days),
              ),
              _choiceChip(
                '30일',
                _dateRange == AiHistoryDateRange.last30Days,
                () => _setDate(AiHistoryDateRange.last30Days),
              ),
              _choiceChip(
                '90일',
                _dateRange == AiHistoryDateRange.last90Days,
                () => _setDate(AiHistoryDateRange.last90Days),
              ),
            ],
          ),
          if (!widget.emotionOnly) ...[
            SizedBox(height: 16.h),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _attentionOnly,
              activeTrackColor: AppTheme.primaryColor,
              title: Text(
                '확인할 건강 기록만',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              subtitle: Text(
                '지켜보기·확인 필요 상태를 모아봐요',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _attentionOnly = value;
                  _type = value
                      ? AiHistoryTypeFilter.health
                      : AiHistoryTypeFilter.all;
                });
              },
            ),
          ],
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: 52.h),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  AiHistoryFilterSelection(
                    type: _type,
                    dateRange: _dateRange,
                    healthAttentionOnly: _attentionOnly,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.actionBase,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 18.w,
                    vertical: 14.h,
                  ),
                ),
                child: Text(
                  '적용하기',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String value) => Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryTextColor,
          ),
        ),
      );

  Widget _choiceChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? AppTheme.primaryColor : AppTheme.dividerColor,
      ),
      labelStyle: TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppTheme.primaryTextColor,
      ),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
    );
  }

  void _setType(AiHistoryTypeFilter value) => setState(() {
        _type = value;
        if (value == AiHistoryTypeFilter.emotion) _attentionOnly = false;
      });

  void _setDate(AiHistoryDateRange value) => setState(() => _dateRange = value);
}
