import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/health_record.dart';
import 'weight_trend.dart';

/// 체중 추이 라인 차트(STEP 3). records에서 weight 기록을 모아 추이를 그린다.
/// 감정 트렌드 차트(STEP 1)와 동일한 fl_chart·상태분기 패턴.
class WeightTrendChart extends StatelessWidget {
  final List<HealthRecord> records;

  const WeightTrendChart({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final points = buildWeightTrendPoints(records);

    return Container(
      // 감정 분석 추이 카드와 동일한 전체 폭 (0건/1건 상태 shrink-wrap 방지)
      width: double.infinity,
      decoration: AppTheme.cardDecoration,
      padding: EdgeInsets.all(16.w),
      child: points.isEmpty
          ? _buildEmpty()
          : points.length == 1
              ? _buildSingle(points.first)
              : _buildChart(points),
    );
  }

  // 0건
  Widget _buildEmpty() {
    return SizedBox(
      height: 120.h,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('체중을 기록하면 추이를 볼 수 있어요',
              style: TextStyle(
                  fontSize: 13.sp, color: AppTheme.secondaryTextColor)),
        ],
      ),
    );
  }

  // 1건
  Widget _buildSingle(WeightTrendPoint p) {
    return SizedBox(
      height: 120.h,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${_fmt(p.weightKg)}kg',
              style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor)),
          if (p.bcs != null) ...[
            SizedBox(height: 2.h),
            Text('BCS ${p.bcs}',
                style: TextStyle(
                    fontSize: 12.sp, color: AppTheme.secondaryTextColor)),
          ],
          SizedBox(height: 4.h),
          Text('2건 이상 쌓이면 추이가 표시돼요',
              style: TextStyle(fontSize: 11.sp, color: AppTheme.hintColor)),
        ],
      ),
    );
  }

  // 2건+
  Widget _buildChart(List<WeightTrendPoint> points) {
    final range = weightAxisRange(points);
    final delta = computeWeightDelta(points);
    final latest = points.last;

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].weightKg),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 현재 체중 + 전 측정 대비 증감
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${_fmt(latest.weightKg)}kg',
                style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor)),
            SizedBox(width: 8.w),
            if (delta != null) _buildDeltaBadge(delta),
          ],
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 140.h,
          child: LineChart(
            LineChartData(
              minY: range.min,
              maxY: range.max,
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34.w,
                    getTitlesWidget: (value, meta) {
                      if (value != meta.min && value != meta.max) {
                        return const SizedBox.shrink();
                      }
                      return Text(_fmt(value),
                          style: TextStyle(
                              fontSize: 9.sp,
                              color: AppTheme.secondaryTextColor));
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 || i >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final d = points[i].recordDate;
                      return Padding(
                        padding: EdgeInsets.only(top: 4.h),
                        child: Text('${d.month}/${d.day}',
                            style: TextStyle(
                                fontSize: 9.sp,
                                color: AppTheme.secondaryTextColor)),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touched) => touched.map((s) {
                    final p = points[s.x.round()];
                    final bcs = p.bcs != null ? ' · BCS ${p.bcs}' : '';
                    return LineTooltipItem(
                      '${p.recordDate.month}/${p.recordDate.day}\n'
                      '${_fmt(p.weightKg)}kg$bcs',
                      TextStyle(fontSize: 11.sp, color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppTheme.primaryColor,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 전 측정 대비 증감 뱃지. 색은 "변화" 환기용(증가=주황, 감소=파랑) —
  // 의학적 좋고나쁨 단정을 피하고 방향만 표시.
  Widget _buildDeltaBadge(WeightDelta delta) {
    if (delta.isFlat) {
      return _badge('변화 없음', AppTheme.secondaryTextColor, null);
    }
    final color =
        delta.isIncrease ? AppTheme.warningColor : AppTheme.primaryColor;
    final arrow = delta.isIncrease ? '▲' : '▼';
    final kg = delta.deltaKg.abs();
    final pct = delta.percent.abs();
    return _badge(
      '$arrow ${_fmt(kg)}kg (${pct.toStringAsFixed(1)}%)',
      color,
      color,
    );
  }

  Widget _badge(String text, Color color, Color? bg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: (bg ?? AppTheme.secondaryTextColor).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11.sp, fontWeight: FontWeight.w600, color: color)),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
