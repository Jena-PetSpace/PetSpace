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
    final emotionData = AppTheme.emotionOrder.map((key) {
      double value;
      switch (key) {
        case 'happiness':  value = emotions.happiness;  break;
        case 'calm':       value = emotions.calm;        break;
        case 'excitement': value = emotions.excitement;  break;
        case 'curiosity':  value = emotions.curiosity;   break;
        case 'anxiety':    value = emotions.anxiety;     break;
        case 'fear':       value = emotions.fear;        break;
        case 'sadness':    value = emotions.sadness;     break;
        case 'discomfort': value = emotions.discomfort;  break;
        default:           value = 0.0;
      }
      return {
        'label': AppTheme.getEmotionLabel(key),
        'value': value,
        'color': AppTheme.getEmotionColor(key),
      };
    }).toList();

    return emotionData.map((emotion) {
      final value = emotion['value'] as double;
      final color = emotion['color'] as Color;
      final percentage = (value * 100).toInt();

      return PieChartSectionData(
        value: value > 0 ? value : 0.001,
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
                  final idx = value.toInt();
                  if (idx < AppTheme.emotionOrder.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        AppTheme.getEmotionLabel(AppTheme.emotionOrder[idx]),
                        style: const TextStyle(fontSize: 9),
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
    return AppTheme.emotionOrder.asMap().entries.map((entry) {
      final idx = entry.key;
      final key = entry.value;
      double value;
      switch (key) {
        case 'happiness':  value = emotions.happiness;  break;
        case 'calm':       value = emotions.calm;        break;
        case 'excitement': value = emotions.excitement;  break;
        case 'curiosity':  value = emotions.curiosity;   break;
        case 'anxiety':    value = emotions.anxiety;     break;
        case 'fear':       value = emotions.fear;        break;
        case 'sadness':    value = emotions.sadness;     break;
        case 'discomfort': value = emotions.discomfort;  break;
        default:           value = 0.0;
      }
      final group = AppTheme.getEmotionGroup(key);
      final Color bgColor;
      if (group == 'positive') {
        bgColor = const Color(0xFFE8F5E9);
      } else if (group == 'negative') {
        bgColor = const Color(0xFFFCE4EC);
      } else {
        bgColor = const Color(0xFFF3E5F5);
      }
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: value,
            color: AppTheme.getEmotionColor(key),
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 1.0,
              color: bgColor,
            ),
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
    final emotionData = AppTheme.emotionOrder.map((key) {
      double value;
      switch (key) {
        case 'happiness':  value = emotions.happiness;  break;
        case 'calm':       value = emotions.calm;        break;
        case 'excitement': value = emotions.excitement;  break;
        case 'curiosity':  value = emotions.curiosity;   break;
        case 'anxiety':    value = emotions.anxiety;     break;
        case 'fear':       value = emotions.fear;        break;
        case 'sadness':    value = emotions.sadness;     break;
        case 'discomfort': value = emotions.discomfort;  break;
        default:           value = 0.0;
      }
      IconData icon;
      switch (key) {
        case 'happiness':  icon = Icons.mood;                       break;
        case 'calm':       icon = Icons.self_improvement;           break;
        case 'excitement': icon = Icons.celebration;                break;
        case 'curiosity':  icon = Icons.psychology;                 break;
        case 'anxiety':    icon = Icons.warning;                    break;
        case 'fear':       icon = Icons.warning_amber_outlined;     break;
        case 'sadness':    icon = Icons.mood_bad;                   break;
        case 'discomfort': icon = Icons.sick_outlined;              break;
        default:           icon = Icons.circle;
      }
      return {
        'label': AppTheme.getEmotionLabel(key),
        'value': value,
        'color': AppTheme.getEmotionColor(key),
        'icon': icon,
      };
    }).toList();

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
