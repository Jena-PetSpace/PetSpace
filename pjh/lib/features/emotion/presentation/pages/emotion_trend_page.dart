import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../data/services/emotion_trend_service.dart';
import '../../domain/entities/emotion_analysis.dart';

class EmotionTrendPage extends StatefulWidget {
  final List<EmotionAnalysis> analyses;

  const EmotionTrendPage({
    super.key,
    required this.analyses,
  });

  @override
  State<EmotionTrendPage> createState() => _EmotionTrendPageState();
}

class _EmotionTrendPageState extends State<EmotionTrendPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late EmotionTrend _trend;
  final EmotionTrendService _trendService = EmotionTrendService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _trend = _trendService.analyzeTrend(widget.analyses);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('감정 트렌드 분석'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '개요', icon: Icon(Icons.analytics)),
            Tab(text: '차트', icon: Icon(Icons.show_chart)),
            Tab(text: '패턴', icon: Icon(Icons.pattern)),
            Tab(text: '추천', icon: Icon(Icons.lightbulb)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildChartTab(),
          _buildPatternsTab(),
          _buildRecommendationsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTrendOverview(),
          SizedBox(height: 24.h),
          _buildDominantEmotion(),
          SizedBox(height: 24.h),
          _buildInsights(),
        ],
      ),
    );
  }

  Widget _buildTrendOverview() {
    IconData trendIcon;
    Color trendColor;
    String trendText;

    switch (_trend.trendDirection) {
      case TrendDirection.improving:
        trendIcon = Icons.trending_up;
        trendColor = Colors.green;
        trendText = '개선 중';
        break;
      case TrendDirection.declining:
        trendIcon = Icons.trending_down;
        trendColor = Colors.red;
        trendText = '주의 필요';
        break;
      case TrendDirection.stable:
        trendIcon = Icons.trending_flat;
        trendColor = Colors.blue;
        trendText = '안정적';
        break;
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            Row(
              children: [
                Icon(trendIcon, color: trendColor, size: 32.w),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '감정 트렌드',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        trendText,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: trendColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            LinearProgressIndicator(
              value: _trend.trendStrength,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(trendColor),
            ),
            SizedBox(height: 8.h),
            Text(
              '트렌드 강도: ${(_trend.trendStrength * 100).toInt()}%',
              style: TextStyle(fontSize: 14.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDominantEmotion() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '주요 감정',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: _getEmotionColor(_trend.dominantEmotion)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    _getEmotionIcon(_trend.dominantEmotion),
                    color: _getEmotionColor(_trend.dominantEmotion),
                    size: 32.w,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getEmotionName(_trend.dominantEmotion),
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '분석 기간 동안 가장 자주 경험한 감정입니다',
                        style: TextStyle(fontSize: 14.sp),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '인사이트',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16.h),
            ..._trend.insights.map((insight) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: AppTheme.primaryColor,
                        size: 20.w,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(insight, style: TextStyle(fontSize: 14.sp)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildChartTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          _buildEmotionChart(),
          SizedBox(height: 24.h),
          _buildEmotionDistribution(),
        ],
      ),
    );
  }

  Widget _buildEmotionChart() {
    if (widget.analyses.isEmpty) {
      return Center(
        child: Text('표시할 데이터가 없습니다', style: TextStyle(fontSize: 14.sp)),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < widget.analyses.length; i++) {
      final analysis = widget.analyses[i];
      final score = _calculateEmotionScore(analysis);
      spots.add(FlSpot(i.toDouble(), score));
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '감정 변화 차트',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              height: 200.h,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.primaryColor,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionDistribution() {
    final emotionCounts = <String, int>{};

    for (final analysis in widget.analyses) {
      final emotions = analysis.emotions;
      final emotionMap = {
        'happiness': emotions.happiness,
        'sadness': emotions.sadness,
        'anxiety': emotions.anxiety,
        'sleepiness': emotions.sleepiness,
        'curiosity': emotions.curiosity,
      };

      // Find dominant emotion for this analysis
      final dominantEmotion =
          emotionMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      emotionCounts[dominantEmotion] =
          (emotionCounts[dominantEmotion] ?? 0) + 1;
    }

    final sections = emotionCounts.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${entry.key}\n${entry.value}',
        color: _getEmotionColor(entry.key),
        radius: 80.r,
        titleStyle: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '감정 분포',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              height: 200.h,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40.r,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternsTab() {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _trend.patterns.length,
      itemBuilder: (context, index) {
        final pattern = _trend.patterns[index];
        return Card(
          margin: EdgeInsets.only(bottom: 16.h),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_getPatternIcon(pattern.type), size: 24.w),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        _getPatternTitle(pattern.type),
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        '${(pattern.confidence * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Text(pattern.description, style: TextStyle(fontSize: 14.sp)),
                if (pattern.sequence != null) ...[
                  SizedBox(height: 12.h),
                  Row(
                    children: pattern.sequence!
                        .map((emotion) => Container(
                              margin: EdgeInsets.only(right: 8.w),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: _getEmotionColor(emotion)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                    color: _getEmotionColor(emotion)),
                              ),
                              child: Text(
                                _getEmotionName(emotion),
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: _getEmotionColor(emotion),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecommendationsTab() {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _trend.recommendations.length,
      itemBuilder: (context, index) {
        final recommendation = _trend.recommendations[index];
        return Card(
          margin: EdgeInsets.only(bottom: 16.h),
          child: ListTile(
            leading: CircleAvatar(
              radius: 20.r,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            ),
            title: Text(recommendation, style: TextStyle(fontSize: 14.sp)),
            trailing: Icon(Icons.arrow_forward_ios, size: 16.w),
            onTap: () {
              // Could implement detailed recommendation view
            },
          ),
        );
      },
    );
  }

  double _calculateEmotionScore(EmotionAnalysis analysis) {
    final emotions = analysis.emotions;

    // Calculate score based on emotion values
    double score = 0.5; // neutral baseline

    // Add positive emotions
    score += emotions.happiness * 0.5;
    score += emotions.curiosity * 0.3;

    // Subtract negative emotions
    score -= emotions.sadness * 0.5;
    score -= emotions.anxiety * 0.4;

    // Sleepiness is neutral

    return score.clamp(0.0, 1.0);
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'joyful':
        return Colors.yellow[700]!;
      case 'excited':
        return Colors.orange;
      case 'content':
      case 'peaceful':
        return Colors.green;
      case 'sad':
        return Colors.blue[700]!;
      case 'angry':
      case 'frustrated':
        return Colors.red;
      case 'anxious':
      case 'worried':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getEmotionIcon(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'joyful':
        return Icons.sentiment_very_satisfied;
      case 'excited':
        return Icons.celebration;
      case 'content':
      case 'peaceful':
        return Icons.sentiment_satisfied;
      case 'sad':
        return Icons.sentiment_dissatisfied;
      case 'angry':
      case 'frustrated':
        return Icons.sentiment_very_dissatisfied;
      case 'anxious':
      case 'worried':
        return Icons.psychology;
      default:
        return Icons.sentiment_neutral;
    }
  }

  String _getEmotionName(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return '행복';
      case 'excited':
        return '신남';
      case 'content':
        return '만족';
      case 'peaceful':
        return '평온';
      case 'joyful':
        return '기쁨';
      case 'sad':
        return '슬픔';
      case 'angry':
        return '화남';
      case 'frustrated':
        return '좌절';
      case 'anxious':
        return '불안';
      case 'worried':
        return '걱정';
      default:
        return emotion;
    }
  }

  IconData _getPatternIcon(PatternType type) {
    switch (type) {
      case PatternType.timeOfDay:
        return Icons.schedule;
      case PatternType.weekly:
        return Icons.calendar_view_week;
      case PatternType.recovery:
        return Icons.trending_up;
      case PatternType.stress:
        return Icons.warning;
      case PatternType.cyclical:
        return Icons.repeat;
    }
  }

  String _getPatternTitle(PatternType type) {
    switch (type) {
      case PatternType.timeOfDay:
        return '시간대별 패턴';
      case PatternType.weekly:
        return '주간 패턴';
      case PatternType.recovery:
        return '회복 패턴';
      case PatternType.stress:
        return '스트레스 패턴';
      case PatternType.cyclical:
        return '반복 패턴';
    }
  }
}
