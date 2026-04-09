import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/emotion_analysis.dart';

class EmotionChartWidget extends StatelessWidget {
  final EmotionAnalysis emotionAnalysis;
  final double height;

  const EmotionChartWidget({
    super.key,
    required this.emotionAnalysis,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final emotions = emotionAnalysis.emotions;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 1.0,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < AppTheme.emotionOrder.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        AppTheme.getEmotionLabel(AppTheme.emotionOrder[idx]),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
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
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 0.2,
          ),
          borderData: FlBorderData(show: false),
          barGroups: AppTheme.emotionOrder.asMap().entries.map((entry) {
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
            return _createBarGroup(idx, value, AppTheme.getEmotionColor(key));
          }).toList(),
        ),
      ),
    );
  }

  BarChartGroupData _createBarGroup(int x, double value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          color: color,
          width: 20,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
      ],
    );
  }
}
