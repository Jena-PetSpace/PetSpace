import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/emotion_analysis.dart';

/// AI 감정 해석 카드
class EmotionInterpretationCard extends StatelessWidget {
  final EmotionScores emotions;

  const EmotionInterpretationCard({
    super.key,
    required this.emotions,
  });

  @override
  Widget build(BuildContext context) {
    final interpretation = _generateInterpretation();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              interpretation.primaryColor.withValues(alpha: 0.1),
              Colors.white,
            ],
          ),
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: interpretation.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: interpretation.primaryColor,
                    size: 24.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 감정 해석',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      Text(
                        '반려동물의 현재 감정 상태 분석',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16.h),

            // 주요 감정 상태
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: interpretation.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: interpretation.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    interpretation.emoji,
                    style: TextStyle(fontSize: 40.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          interpretation.title,
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: interpretation.primaryColor,
                          ),
                        ),
                        Text(
                          interpretation.subtitle,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // 분석 이유
            _buildSection(
              icon: Icons.lightbulb_outline,
              title: '왜 이런 결과가 나왔나요?',
              content: interpretation.reason,
              color: Colors.amber,
            ),

            SizedBox(height: 12.h),

            // 행동 패턴 분석
            _buildSection(
              icon: Icons.pets,
              title: '행동 패턴 분석',
              content: interpretation.behaviorAnalysis,
              color: Colors.blue,
            ),

            SizedBox(height: 12.h),

            // 환경 요인
            _buildSection(
              icon: Icons.home,
              title: '환경 요인 고려',
              content: interpretation.environmentFactors,
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18.w),
            SizedBox(width: 8.w),
            Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryTextColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Padding(
          padding: EdgeInsets.only(left: 26.w),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 13.sp,
              height: 1.5,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ),
      ],
    );
  }

  double _getEmotionValue(String emotion) {
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

  String _getSecondaryEmotion() {
    final sorted = AppTheme.emotionOrder
        .map((k) => MapEntry(k, _getEmotionValue(k)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.length > 1 ? sorted[1].key : 'happiness';
  }

  _EmotionInterpretation _generateInterpretation() {
    final dominant = emotions.dominantEmotion;
    final dominantValue = _getEmotionValue(dominant);
    final secondaryEmotion = _getSecondaryEmotion();
    final secLabel = AppTheme.getEmotionLabel(secondaryEmotion);

    switch (dominant) {
      case 'happiness':
        return _EmotionInterpretation(
          emoji: '😊',
          title: '행복한 상태',
          subtitle: '기쁨이 ${(dominantValue * 100).toInt()}%로 가장 높습니다',
          primaryColor: AppTheme.happinessColor,
          reason: dominantValue > 0.7
              ? '매우 높은 행복 지수가 감지되었습니다. 꼬리 흔들기, 편안한 표정, 이완된 자세 등 긍정적인 신체 언어가 명확하게 나타났습니다. $secLabel도 함께 높아 활기찬 상태입니다.'
              : '긍정적인 감정 상태입니다. 입꼬리가 올라간 표정과 편안한 눈빛이 감지되었습니다.',
          behaviorAnalysis: '꼬리를 흔들거나, 입을 살짝 벌리고 있거나, 편안하게 누워있는 모습이 감지되었습니다.',
          environmentFactors: '현재 환경이 안정감을 주고 있습니다. 적절한 온도, 편안한 공간, 보호자와의 긍정적인 상호작용이 기여했을 수 있습니다.',
        );
      case 'calm':
        return _EmotionInterpretation(
          emoji: '😌',
          title: '편안한 상태',
          subtitle: '편안함이 ${(dominantValue * 100).toInt()}%로 가장 높습니다',
          primaryColor: AppTheme.calmColor,
          reason: dominantValue > 0.7
              ? '매우 안정된 상태입니다. 근육이 이완되고 호흡이 고르게 감지되었습니다.'
              : '전반적으로 차분하고 안정적인 상태입니다.',
          behaviorAnalysis: '느슨하게 이완된 자세, 반쯤 감긴 눈, 고른 호흡이 감지되었습니다. 신뢰와 안정감의 신호입니다.',
          environmentFactors: '조용하고 안전한 환경이 이러한 편안함에 기여하고 있습니다.',
        );
      case 'excitement':
        return _EmotionInterpretation(
          emoji: '🎉',
          title: '흥분된 상태',
          subtitle: '흥분이 ${(dominantValue * 100).toInt()}%로 가장 높습니다',
          primaryColor: AppTheme.excitementColor,
          reason: dominantValue > 0.7
              ? '매우 높은 흥분 상태입니다. 활발한 움직임, 빠른 호흡, 긴장된 근육이 감지되었습니다.'
              : '적당한 흥분 상태입니다. 긍정적인 자극에 반응하고 있습니다.',
          behaviorAnalysis: '빠르게 움직이거나, 뛰어오르거나, 활발히 움직이는 모습이 감지되었습니다.',
          environmentFactors: '새로운 자극이나 즐거운 활동이 흥분을 유발했을 수 있습니다. 에너지를 발산할 공간을 제공해주세요.',
        );
      case 'curiosity':
        return _EmotionInterpretation(
          emoji: '🤔',
          title: '호기심 많은 상태',
          subtitle: '호기심이 ${(dominantValue * 100).toInt()}%로 가장 높습니다',
          primaryColor: AppTheme.curiosityColor,
          reason: dominantValue > 0.7
              ? '매우 높은 호기심이 감지되었습니다. 쫑긋한 귀, 집중하는 눈빛, 앞으로 향한 자세가 나타났습니다. $secLabel도 함께 높아 즐겁게 탐색 중입니다.'
              : '적당한 호기심이 감지되었습니다. 건강하고 활발한 정신 상태를 나타냅니다.',
          behaviorAnalysis: '귀가 쫑긋 세워진 모습, 집중하는 눈빛, 무언가를 탐색하는 자세가 감지되었습니다.',
          environmentFactors: '새로운 소리, 냄새, 움직임이 호기심을 자극했을 수 있습니다. 퍼즐 피더나 새 장난감이 효과적입니다.',
        );
      case 'anxiety':
        return _EmotionInterpretation(
          emoji: '😰',
          title: '불안한 상태',
          subtitle: '불안이 ${(dominantValue * 100).toInt()}%로 가장 높습니다',
          primaryColor: AppTheme.anxietyColor,
          reason: dominantValue > 0.7
              ? '높은 불안 수치가 감지되었습니다. 경계하는 자세, 동공 확장, 귀를 뒤로 젖힌 모습이 나타났습니다. $secLabel도 동반되어 있습니다.'
              : '가벼운 긴장 상태입니다. 새로운 환경이나 낯선 자극에 대한 자연스러운 반응일 수 있습니다.',
          behaviorAnalysis: '경계하는 자세, 귀를 뒤로 젖힌 모습, 긴장된 표정이 감지되었습니다.',
          environmentFactors: '큰 소리, 낯선 방문자, 익숙하지 않은 환경이 원인일 수 있습니다. 조용하고 안전한 공간을 제공해주세요.',
        );
      case 'fear':
        return _EmotionInterpretation(
          emoji: '😨',
          title: '두려움을 느끼는 상태',
          subtitle: '공포가 ${(dominantValue * 100).toInt()}%로 가장 높습니다',
          primaryColor: AppTheme.fearColor,
          reason: dominantValue > 0.7
              ? '강한 두려움이 감지되었습니다. 몸을 낮추거나 웅크리는 자세, 떨림 등이 나타났습니다.'
              : '두려움 신호가 감지되었습니다. 스트레스 요인을 파악하고 제거해주세요.',
          behaviorAnalysis: '몸을 낮추거나, 꼬리를 내리거나, 웅크리는 모습이 감지되었습니다. 즉각적인 안심이 필요합니다.',
          environmentFactors: '갑작스러운 소음, 낯선 존재, 위협적인 상황이 공포를 유발했을 수 있습니다. 안전한 공간으로 이동시켜주세요.',
        );
      case 'sadness':
        return _EmotionInterpretation(
          emoji: '😢',
          title: '슬픈 상태',
          subtitle: '슬픔이 ${(dominantValue * 100).toInt()}%로 가장 높습니다',
          primaryColor: AppTheme.sadnessColor,
          reason: dominantValue > 0.7
              ? '높은 슬픔 지수가 감지되었습니다. 처진 귀, 축 처진 눈, 무기력한 자세가 나타났습니다. $secLabel도 동반되어 있습니다.'
              : '약간의 우울함이 감지되었습니다. 일시적인 상태일 수 있으나 지속된다면 점검해보세요.',
          behaviorAnalysis: '귀가 처져있거나, 눈이 축 처진 모습, 활력이 떨어진 자세가 감지되었습니다.',
          environmentFactors: '최근 환경 변화(이사, 가족 변화, 일상 패턴 변화)가 원인일 수 있습니다.',
        );
      case 'discomfort':
        return _EmotionInterpretation(
          emoji: '😣',
          title: '불편한 상태',
          subtitle: '불편함이 ${(dominantValue * 100).toInt()}%로 가장 높습니다',
          primaryColor: AppTheme.discomfortColor,
          reason: dominantValue > 0.7
              ? '높은 불편함이 감지되었습니다. 신체적 불편 또는 환경적 자극이 원인일 수 있습니다.'
              : '약간의 불편함이 감지되었습니다. 환경을 점검해주세요.',
          behaviorAnalysis: '긁거나, 몸을 비비거나, 불편한 자세를 취하는 모습이 감지되었습니다.',
          environmentFactors: '피부 자극, 온도 불쾌, 소화 불편 등 신체적 원인을 확인해보세요.',
        );
      default:
        return _EmotionInterpretation(
          emoji: '🐾',
          title: '균형잡힌 상태',
          subtitle: '감정이 고르게 분포되어 있습니다',
          primaryColor: AppTheme.primaryColor,
          reason: '여러 감정이 비슷한 수준으로 나타나고 있어 특정 감정이 두드러지지 않습니다.',
          behaviorAnalysis: '반려동물이 다양한 감정을 경험하고 있으며, 전반적으로 안정적인 상태입니다.',
          environmentFactors: '현재 환경이 적절하게 유지되고 있습니다. 지속적인 관심과 케어를 유지해주세요.',
        );
    }
  }
}

class _EmotionInterpretation {
  final String emoji;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final String reason;
  final String behaviorAnalysis;
  final String environmentFactors;

  _EmotionInterpretation({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.reason,
    required this.behaviorAnalysis,
    required this.environmentFactors,
  });
}
