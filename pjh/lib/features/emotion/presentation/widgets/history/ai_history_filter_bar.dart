import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../shared/themes/app_theme.dart';
import '../../../domain/entities/ai_history.dart';

/// 기록 목록의 모든 필터 진입점을 하나로 모은 요약 행.
class AiHistoryFilterBar extends StatelessWidget {
  final AiHistoryTypeFilter type;
  final AiHistoryDateRange dateRange;
  final bool healthAttentionOnly;
  final bool emotionOnly;
  final VoidCallback onTap;

  const AiHistoryFilterBar({
    super.key,
    required this.type,
    required this.dateRange,
    required this.healthAttentionOnly,
    required this.emotionOnly,
    required this.onTap,
  });

  bool get _active =>
      dateRange != AiHistoryDateRange.all ||
      (!emotionOnly && type != AiHistoryTypeFilter.all) ||
      (!emotionOnly && healthAttentionOnly);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '기록 필터, ${_summary()}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            constraints: BoxConstraints(minHeight: 58.h),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: _active ? AppTheme.actionBase : AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: const BoxDecoration(
                    color: AppTheme.actionContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: AppTheme.primaryColor,
                    size: 19.w,
                  ),
                ),
                SizedBox(width: 11.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '기록 필터',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _summary(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.secondaryTextColor,
                  size: 22.w,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _summary() {
    final values = <String>[];
    if (!emotionOnly) {
      values.add(switch (type) {
        AiHistoryTypeFilter.all => '전체 유형',
        AiHistoryTypeFilter.emotion => '감정',
        AiHistoryTypeFilter.health => '건강',
      });
    }
    values.add(switch (dateRange) {
      AiHistoryDateRange.all => '전체 기간',
      AiHistoryDateRange.last7Days => '최근 7일',
      AiHistoryDateRange.last30Days => '최근 30일',
      AiHistoryDateRange.last90Days => '최근 90일',
    });
    if (!emotionOnly && healthAttentionOnly) {
      values.add('확인 필요');
    }
    return values.join(' · ');
  }
}
