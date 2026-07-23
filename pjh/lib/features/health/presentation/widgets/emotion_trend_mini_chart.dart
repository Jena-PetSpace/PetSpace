import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../controllers/health_emotion_loader.dart';
import 'health_pdf_data.dart';

/// 감정 트렌드 차트의 한 점(실제 분석 1건).
class EmotionTrendPoint {
  final DateTime analyzedAt;
  final double positiveRatio; // 0.0~1.0
  final String dominantEmotion;
  final String imageUrl;

  const EmotionTrendPoint({
    required this.analyzedAt,
    required this.positiveRatio,
    required this.dominantEmotion,
    required this.imageUrl,
  });
}

/// 분석 리스트 → 차트 포인트 변환(순수 함수, 테스트 대상).
/// - 분석일(analyzedAt) 오름차순 정렬, 최근 [maxPoints]건만 사용.
/// - y값 = 긍정도(EmotionScores.positiveRatio).
List<EmotionTrendPoint> buildEmotionTrendPoints(
  List<EmotionAnalysis> analyses, {
  int maxPoints = 10,
}) {
  final sorted = [...analyses]
    ..sort((a, b) => a.analyzedAt.compareTo(b.analyzedAt));
  final recent = sorted.length > maxPoints
      ? sorted.sublist(sorted.length - maxPoints)
      : sorted;
  return recent
      .map((a) => EmotionTrendPoint(
            analyzedAt: a.analyzedAt,
            positiveRatio: a.emotions.positiveRatio,
            dominantEmotion: a.emotions.dominantEmotion,
            imageUrl: a.imageUrl,
          ))
      .toList();
}

/// 최근 감정 분석 추이 라인(A-1). 더미 제거 — 실제 emotion_history 조회.
/// 이 위젯은 health 소속이나 emotion 데이터를 읽기 전용으로만 사용한다.
class EmotionTrendMiniChart extends StatefulWidget {
  final String userId;
  final String petId;
  final HealthEmotionLoader loader;

  const EmotionTrendMiniChart({
    super.key,
    required this.userId,
    required this.petId,
    required this.loader,
  });

  @override
  State<EmotionTrendMiniChart> createState() => _EmotionTrendMiniChartState();
}

class _EmotionTrendMiniChartState extends State<EmotionTrendMiniChart> {
  bool _loading = true;
  bool _failed = false;
  List<EmotionTrendPoint> _points = const [];
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EmotionTrendMiniChart old) {
    super.didUpdateWidget(old);
    if (old.petId != widget.petId || old.userId != widget.userId) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final result = await widget.loader.loadHistory(
      userId: widget.userId,
      petId: widget.petId,
      limit: 30,
    );
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _failed = result.isFailure;
      _points = result.isFailure
          ? const []
          : buildEmotionTrendPoints(result.analyses, maxPoints: 10);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: EdgeInsets.all(16.w),
      child: _loading
          ? ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 140),
              child: const Center(child: CircularProgressIndicator()),
            )
          : _failed
              ? _buildError()
              : _points.isEmpty
                  ? _buildEmpty()
                  : _points.length == 1
                      ? _buildSinglePoint(_points.first)
                      : _buildChart(),
    );
  }

  Widget _buildError() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 160),
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.refresh_outlined,
              size: 32.w,
              color: AppTheme.errorColor,
            ),
            SizedBox(height: 8.h),
            Text(
              '건강 변화를 불러오지 못했어요',
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.secondaryTextColor,
              ),
            ),
            SizedBox(height: 8.h),
            TextButton(
              key: const Key('health_emotion_retry'),
              onPressed: _load,
              child: Text(
                '다시 시도',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppTheme.actionBase,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 0건 — 빈 상태
  Widget _buildEmpty() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 140),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '아직 분석 기록이 없어요',
            style:
                TextStyle(fontSize: 13.sp, color: AppTheme.secondaryTextColor),
          ),
          SizedBox(height: 8.h),
          TextButton(
            onPressed: () => context.push('/emotion-analysis'),
            child: Text('AI 분석하러 가기',
                style: TextStyle(
                    fontSize: 13.sp,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // 1건 — 점 1개 + 안내
  Widget _buildSinglePoint(EmotionTrendPoint p) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 140),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${(p.positiveRatio * 100).round()}%',
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '대표 감정: ${healthEmotionLabelKo(p.dominantEmotion)}',
            style:
                TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor),
          ),
          SizedBox(height: 4.h),
          Text(
            '분석이 2건 이상 쌓이면 추이 그래프가 표시돼요',
            style: TextStyle(fontSize: 11.sp, color: AppTheme.hintColor),
          ),
        ],
      ),
    );
  }

  // 2건+ — 추이 라인
  Widget _buildChart() {
    final spots = <FlSpot>[
      for (var i = 0; i < _points.length; i++)
        FlSpot(i.toDouble(), _points[i].positiveRatio),
    ];

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 1,
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= _points.length) {
                    return const SizedBox.shrink();
                  }
                  final d = _points[i].analyzedAt;
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
              getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                final p = _points[s.x.round()];
                final emo = healthEmotionLabelKo(p.dominantEmotion);
                return LineTooltipItem(
                  '${p.analyzedAt.month}/${p.analyzedAt.day}\n'
                  '긍정 ${(p.positiveRatio * 100).round()}% · $emo',
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
    );
  }
}
