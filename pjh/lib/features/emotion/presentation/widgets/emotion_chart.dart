import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/emotion_analysis.dart';

class EmotionChart extends StatelessWidget {
  final EmotionScores emotions;
  final double size;

  const EmotionChart({
    super.key,
    required this.emotions,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: PieChart(
        PieChartData(
          sections: _buildSections(),
          centerSpaceRadius: size * 0.3,
          sectionsSpace: 2,
          startDegreeOffset: -90,
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    final emotionData = [
      {
        'label': '기쁨',
        'value': emotions.happiness,
        'color': AppTheme.happinessColor,
      },
      {
        'label': '슬픔',
        'value': emotions.sadness,
        'color': AppTheme.sadnessColor,
      },
      {
        'label': '불안',
        'value': emotions.anxiety,
        'color': AppTheme.anxietyColor,
      },
      {
        'label': '졸림',
        'value': emotions.sleepiness,
        'color': AppTheme.sleepinessColor,
      },
      {
        'label': '호기심',
        'value': emotions.curiosity,
        'color': AppTheme.curiosityColor,
      },
    ];

    return emotionData.map((emotion) {
      final value = emotion['value'] as double;
      final color = emotion['color'] as Color;
      final percentage = (value * 100).toInt();

      return PieChartSectionData(
        value: value,
        color: color,
        title: percentage > 5 ? '$percentage%' : '',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: size * 0.15,
      );
    }).toList();
  }
}

class EmotionBarChart extends StatelessWidget {
  final EmotionScores emotions;
  final double height;

  const EmotionBarChart({
    super.key,
    required this.emotions,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 1.0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.transparent,
              tooltipPadding: EdgeInsets.zero,
              tooltipMargin: 4,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final value = (rod.toY * 100).toInt();
                return BarTooltipItem(
                  '$value%',
                  const TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${(value * 100).toInt()}%',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const emotionNames = ['기쁨', '슬픔', '불안', '졸림', '호기심'];
                  if (value.toInt() < emotionNames.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        emotionNames[value.toInt()],
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            horizontalInterval: 0.2,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withValues(alpha: 0.3),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: _buildBarGroups(),
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    final emotionValues = [
      emotions.happiness,
      emotions.sadness,
      emotions.anxiety,
      emotions.sleepiness,
      emotions.curiosity,
    ];

    final emotionColors = [
      AppTheme.happinessColor,
      AppTheme.sadnessColor,
      AppTheme.anxietyColor,
      AppTheme.sleepinessColor,
      AppTheme.curiosityColor,
    ];

    return emotionValues.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: emotionColors[entry.key],
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
        showingTooltipIndicators: [0],
      );
    }).toList();
  }
}

class EmotionLegend extends StatelessWidget {
  final EmotionScores emotions;

  const EmotionLegend({super.key, required this.emotions});

  @override
  Widget build(BuildContext context) {
    final emotionData = [
      {
        'label': '기쁨',
        'value': emotions.happiness,
        'color': AppTheme.happinessColor,
        'icon': Icons.mood,
      },
      {
        'label': '슬픔',
        'value': emotions.sadness,
        'color': AppTheme.sadnessColor,
        'icon': Icons.mood_bad,
      },
      {
        'label': '불안',
        'value': emotions.anxiety,
        'color': AppTheme.anxietyColor,
        'icon': Icons.warning,
      },
      {
        'label': '졸림',
        'value': emotions.sleepiness,
        'color': AppTheme.sleepinessColor,
        'icon': Icons.bedtime,
      },
      {
        'label': '호기심',
        'value': emotions.curiosity,
        'color': AppTheme.curiosityColor,
        'icon': Icons.psychology,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: emotionData.map((emotion) {
        final percentage = ((emotion['value'] as double) * 100).toInt();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                emotion['icon'] as IconData,
                color: emotion['color'] as Color,
                size: 20,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
                child: Text(
                  emotion['label'] as String,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: emotion['color'] as Color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}