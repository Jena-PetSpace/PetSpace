import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/health_analysis.dart';
import '../../theme/emotion_result_tokens.dart';

/// 건강 분석 발견 사항 리스트 카드.
/// - 헤더: 라벨 + "발견 사항 N개"
/// - 본문: findings 각각을 행으로 표시
///   - 좌측 아이콘 (analysis.area 기준)
///   - 중앙 상단: item(제목) + severity 칩
///   - 중앙 하단: result (한 줄 결과)
///
/// 종합(overall) 케이스에서 findings가 많을 때 (>_collapseThreshold) 5개만 표시 + "전체 보기".
class HealthFindingsCard extends StatefulWidget {
  final HealthArea area;
  final List<HealthFinding> findings;

  /// 이 개수를 초과하면 접기/펴기 토글 표시.
  static const int _collapseThreshold = 7;
  static const int _initialVisibleCount = 5;

  const HealthFindingsCard({
    super.key,
    required this.area,
    required this.findings,
  });

  @override
  State<HealthFindingsCard> createState() => _HealthFindingsCardState();
}

class _HealthFindingsCardState extends State<HealthFindingsCard> {
  bool _expanded = false;

  IconData _iconFor(HealthArea area) {
    switch (area) {
      case HealthArea.eyes:
        return Icons.visibility_outlined;
      case HealthArea.nose:
        return Icons.air_outlined;
      case HealthArea.skin:
        return Icons.healing_outlined;
      case HealthArea.body:
        return Icons.accessibility_outlined;
      case HealthArea.posture:
        return Icons.accessibility_new;
      case HealthArea.overall:
        return Icons.pets;
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: EmotionResultTokens.greenLight,
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text(
            // TODO(copy): HealthFindingsCard 작은 라벨
            'AI가 살펴본 항목',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
              color: EmotionResultTokens.greenDark,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          // TODO(copy): HealthFindingsCard 메인 라벨
          '발견 사항 ${widget.findings.length}개',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            color: EmotionResultTokens.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSeverityChip(String severity) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: EmotionResultTokens.severityBg(severity),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        EmotionResultTokens.severityLabel(severity),
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w500,
          color: EmotionResultTokens.severityDark(severity),
        ),
      ),
    );
  }

  Widget _buildFindingRow(HealthFinding f) {
    final bg = EmotionResultTokens.severityBg(f.severity);
    final iconColor = EmotionResultTokens.severityColor(f.severity);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.r,
            height: 32.r,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(_iconFor(widget.area), size: 18.r, color: iconColor),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        f.item.isNotEmpty ? f.item : '항목 없음',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: EmotionResultTokens.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    _buildSeverityChip(f.severity),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  f.result.isNotEmpty ? f.result : '결과 없음',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: EmotionResultTokens.grayText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(int hiddenCount) {
    return Padding(
      padding: EdgeInsets.only(top: 4.h),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // TODO(copy): HealthFindingsCard 접기/펴기 라벨
                  _expanded ? '접기' : '전체 보기 ($hiddenCount개 더)',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: EmotionResultTokens.navy,
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16.r,
                  color: EmotionResultTokens.navy,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.findings.isEmpty) return const SizedBox.shrink();

    final total = widget.findings.length;
    final shouldCollapse =
        total > HealthFindingsCard._collapseThreshold && !_expanded;
    final visible = shouldCollapse
        ? widget.findings.take(HealthFindingsCard._initialVisibleCount).toList()
        : widget.findings;
    final hiddenCount = total - visible.length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: EmotionResultTokens.cardSurface,
        borderRadius: BorderRadius.circular(EmotionResultTokens.radiusCard.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          SizedBox(height: 4.h),
          for (int i = 0; i < visible.length; i++) ...[
            _buildFindingRow(visible[i]),
            if (i < visible.length - 1)
              Divider(
                height: 1.h,
                thickness: 1,
                color: EmotionResultTokens.dividerLight,
              ),
          ],
          if (total > HealthFindingsCard._collapseThreshold)
            _buildToggleButton(hiddenCount > 0
                ? hiddenCount
                : total - HealthFindingsCard._initialVisibleCount),
        ],
      ),
    );
  }
}
