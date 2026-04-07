import 'package:flutter/material.dart';

import '../../../../shared/themes/app_theme.dart';

class StatisticsSummaryCard extends StatelessWidget {
  final Map<String, dynamic> statistics;

  const StatisticsSummaryCard({
    super.key,
    required this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    // statistics에서 데이터 추출
    final totalAnalyses = statistics['totalAnalyses'] ?? 0;
    final averageEmotions =
        statistics['averageEmotions'] as Map<String, dynamic>? ?? {};
    final dominantEmotion =
        statistics['dominantEmotion'] as String? ?? 'happiness';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '주간 통계',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '최근 7일',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // 총 분석 횟수
                Expanded(
                  child: _StatisticItem(
                    icon: Icons.analytics,
                    label: '분석 횟수',
                    value: totalAnalyses.toString(),
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                // 주요 감정
                Expanded(
                  child: _StatisticItem(
                    icon: _getEmotionIcon(dominantEmotion),
                    label: '주요 감정',
                    value: _getEmotionName(dominantEmotion),
                    color: AppTheme.getEmotionColor(dominantEmotion),
                  ),
                ),
              ],
            ),
            if (averageEmotions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                '평균 감정 분포',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _buildEmotionBars(averageEmotions),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionBars(Map<String, dynamic> emotions) {
    final emotionList = AppTheme.emotionOrder.map((key) => {
      'name': key,
      'label': AppTheme.getEmotionLabel(key),
      'value': emotions[key] ?? 0.0,
    }).toList();

    return Column(
      children: emotionList.map((emotion) {
        final value = (emotion['value'] as num).toDouble();
        final percentage = (value * 100).toInt();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  emotion['label'] as String,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(
                    AppTheme.getEmotionColor(emotion['name'] as String),
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 35,
                child: Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getEmotionName(String emotion) => AppTheme.getEmotionLabel(emotion);

  IconData _getEmotionIcon(String emotion) {
    switch (emotion) {
      case 'happiness':  return Icons.mood;
      case 'calm':       return Icons.self_improvement;
      case 'excitement': return Icons.celebration;
      case 'curiosity':  return Icons.psychology;
      case 'anxiety':    return Icons.warning;
      case 'fear':       return Icons.warning_amber_outlined;
      case 'sadness':    return Icons.mood_bad;
      case 'discomfort': return Icons.sick_outlined;
      default:           return Icons.help_outline;
    }
  }
}

class _StatisticItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatisticItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
