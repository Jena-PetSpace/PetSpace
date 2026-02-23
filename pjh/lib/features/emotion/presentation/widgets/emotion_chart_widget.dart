import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
                  const emotions = ['행복', '슬픔', '불안', '졸림', '호기심'];
                  if (value.toInt() >= 0 && value.toInt() < emotions.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        emotions[value.toInt()],
                        style: const TextStyle(fontSize: 12),
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
          barGroups: [
            _createBarGroup(0, emotions.happiness, Colors.amber),
            _createBarGroup(1, emotions.sadness, Colors.blue),
            _createBarGroup(2, emotions.anxiety, Colors.red),
            _createBarGroup(3, emotions.sleepiness, Colors.purple),
            _createBarGroup(4, emotions.curiosity, Colors.green),
          ],
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
