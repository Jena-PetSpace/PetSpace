import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../../shared/themes/app_theme.dart';

class RecentEmotionCard extends StatelessWidget {
  final EmotionAnalysis analysis;

  const RecentEmotionCard({
    super.key,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    final dominantEmotion = analysis.emotions.dominantEmotion;
    final dominantValue = _getEmotionValue(analysis.emotions, dominantEmotion);

    return Card(
      child: InkWell(
        onTap: () => context.push('/emotion/history'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 감정 아이콘
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.getEmotionColor(dominantEmotion)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getEmotionIcon(dominantEmotion),
                  color: AppTheme.getEmotionColor(dominantEmotion),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),

              // 감정 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getEmotionName(dominantEmotion),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(dominantValue * 100).toInt()}% 확률',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(analysis.analyzedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),

              // 신뢰도 표시
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '신뢰도',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(analysis.confidence * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _getConfidenceColor(analysis.confidence),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getEmotionValue(EmotionScores emotions, String emotion) {
    switch (emotion) {
      case 'happiness':  return emotions.happiness;
      case 'calm':       return emotions.calm;
      case 'excitement': return emotions.excitement;
      case 'curiosity':  return emotions.curiosity;
      case 'anxiety':    return emotions.anxiety;
      case 'fear':       return emotions.fear;
      case 'sadness':    return emotions.sadness;
      case 'discomfort': return emotions.discomfort;
      default:           return 0.0;
    }
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

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.7) return Colors.green;
    if (confidence > 0.4) return Colors.orange;
    return Colors.red;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return DateFormat('MM월 dd일').format(dateTime);
    }
  }
}
