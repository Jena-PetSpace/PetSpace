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

  _EmotionInterpretation _generateInterpretation() {
    final dominant = emotions.dominantEmotion;
    final dominantValue = _getEmotionValue(dominant);

    // 보조 감정 찾기
    final secondaryEmotion = _getSecondaryEmotion();

    switch (dominant) {
      case 'happiness':
        return _EmotionInterpretation(
          emoji: '😊',
          title: '행복한 상태',
          subtitle: '기쁨이 ${(dominantValue * 100).toInt()}%로 가장 높습니다',
          primaryColor: AppTheme.happinessColor,
          reason: _getHappinessReason(dominantValue, secondaryEmotion),
          behaviorAnalysis: '꼬리를 흔들거나, 입을 살짝 벌리고 있거나, 편안하게 누워있는 모습이 감지되었습니다. 이는 반려동물이 현재 환경에 만족하고 있다는 긍정적인 신호입니다.',
          environmentFactors: '현재 환경이 반려동물에게 안정감을 주고 있습니다. 적절한 온도, 편안한 공간, 그리고 보호자와의 긍정적인 상호작용이 이러한 행복감에 기여했을 수 있습니다.',
        );
      case 'sadness':
        return _EmotionInterpretation(
          emoji: '😢',
          title: '슬픈 상태',
          subtitle: '슬픔이 ${(dominantValue * 100).toInt()}%로 가장 높습니다',
          primaryColor: AppTheme.sadnessColor,
          reason: _getSadnessReason(dominantValue, secondaryEmotion),
          behaviorAnalysis: '귀가 처져있거나, 눈이 축 처진 모습, 또는 활력이 떨어진 자세가 감지되었습니다. 반려동물이 무언가를 그리워하거나 외로움을 느끼고 있을 수 있습니다.',
          environmentFactors: '최근 환경 변화(이사, 가족 구성원 변화, 일상 패턴 변화)가 있었다면 이것이 원인일 수 있습니다. 반려동물은 루틴 변화에 민감하게 반응합니다.',
        );
      case 'anxiety':
        return _EmotionInterpretation(
          emoji: '😰',
          title: '불안한 상태',
          subtitle: '불안이 ${(dominantValue * 100).toInt()}%로 가장 높습니다',
          primaryColor: AppTheme.anxietyColor,
          reason: _getAnxietyReason(dominantValue, secondaryEmotion),
          behaviorAnalysis: '경계하는 자세, 귀를 뒤로 젖힌 모습, 또는 긴장된 표정이 감지되었습니다. 주변에 스트레스 요인이 있거나 낯선 상황에 처해 있을 수 있습니다.',
          environmentFactors: '큰 소리, 낯선 사람/동물의 방문, 또는 익숙하지 않은 환경이 불안의 원인일 수 있습니다. 조용하고 안전한 공간을 제공해주세요.',
        );
      case 'sleepiness':
        return _EmotionInterpretation(
          emoji: '😴',
          title: '졸린 상태',
          subtitle: '졸림이 ${(dominantValue * 100).toInt()}%로 가장 높습니다',
          primaryColor: AppTheme.sleepinessColor,
          reason: _getSleepinessReason(dominantValue, secondaryEmotion),
          behaviorAnalysis: '눈이 반쯤 감긴 모습, 하품하는 표정, 또는 편안하게 웅크린 자세가 감지되었습니다. 휴식이 필요하거나 식사 후 소화 중일 수 있습니다.',
          environmentFactors: '적절한 활동량 후의 자연스러운 피로일 수 있습니다. 편안하고 조용한 휴식 공간을 마련해주세요. 충분한 수면은 건강에 필수적입니다.',
        );
      case 'curiosity':
        return _EmotionInterpretation(
          emoji: '🤔',
          title: '호기심 많은 상태',
          subtitle: '호기심이 ${(dominantValue * 100).toInt()}%로 가장 높습니다',
          primaryColor: AppTheme.curiosityColor,
          reason: _getCuriosityReason(dominantValue, secondaryEmotion),
          behaviorAnalysis: '귀가 쫑긋 세워진 모습, 집중하는 눈빛, 또는 무언가를 탐색하는 자세가 감지되었습니다. 주변 환경에 관심을 가지고 있으며 정신적으로 활발한 상태입니다.',
          environmentFactors: '새로운 소리, 냄새, 또는 움직임이 호기심을 자극했을 수 있습니다. 이런 상태에서 새로운 장난감이나 퍼즐 피더를 제공하면 좋습니다.',
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

  String _getHappinessReason(double value, String secondary) {
    if (value > 0.7) {
      return '매우 높은 행복 지수가 감지되었습니다. 꼬리 흔들기, 편안한 표정, 이완된 자세 등 긍정적인 신체 언어가 명확하게 나타났습니다. ${secondary == 'curiosity' ? '호기심도 함께 높아 활동적이고 즐거운 상태입니다.' : ''}';
    } else if (value > 0.5) {
      return '긍정적인 감정 상태입니다. 입꼬리가 올라간 표정과 편안한 눈빛이 감지되었습니다. ${secondary == 'sleepiness' ? '약간의 졸림도 있어 만족스러운 휴식 상태일 수 있습니다.' : ''}';
    }
    return '보통 수준의 기쁨이 감지되었습니다. 전반적으로 안정적이나 더 많은 놀이 시간이 기쁨을 높일 수 있습니다.';
  }

  String _getSadnessReason(double value, String secondary) {
    if (value > 0.7) {
      return '높은 슬픔 지수가 감지되었습니다. 처진 귀, 축 처진 눈, 무기력한 자세가 나타났습니다. ${secondary == 'anxiety' ? '불안감도 동반되어 분리불안이나 스트레스가 원인일 수 있습니다.' : '외로움이나 관심 부족이 원인일 수 있습니다.'}';
    }
    return '약간의 우울함이 감지되었습니다. 일시적인 상태일 수 있으나, 지속된다면 환경 변화나 건강 상태를 점검해보세요.';
  }

  String _getAnxietyReason(double value, String secondary) {
    if (value > 0.7) {
      return '높은 불안 수치가 감지되었습니다. 경계하는 자세, 동공 확장, 귀를 뒤로 젖힌 모습이 나타났습니다. ${secondary == 'sadness' ? '슬픔도 동반되어 분리불안 증상일 가능성이 있습니다.' : '주변 환경에서 스트레스 요인을 찾아보세요.'}';
    }
    return '가벼운 긴장 상태입니다. 새로운 환경이나 낯선 자극에 대한 자연스러운 반응일 수 있습니다.';
  }

  String _getSleepinessReason(double value, String secondary) {
    if (value > 0.7) {
      return '매우 피곤한 상태입니다. 눈이 거의 감긴 모습과 이완된 근육이 감지되었습니다. ${secondary == 'happiness' ? '행복감도 함께 높아 만족스러운 휴식 상태입니다.' : '충분한 휴식을 취하게 해주세요.'}';
    }
    return '적당한 졸림이 감지되었습니다. 활동 후 자연스러운 휴식 신호입니다.';
  }

  String _getCuriosityReason(double value, String secondary) {
    if (value > 0.7) {
      return '매우 높은 호기심이 감지되었습니다. 쫑긋한 귀, 집중하는 눈빛, 앞으로 향한 자세가 나타났습니다. ${secondary == 'happiness' ? '기쁨도 함께 높아 즐겁게 탐색 중입니다.' : '새로운 자극에 강하게 반응하고 있습니다.'}';
    }
    return '적당한 호기심이 감지되었습니다. 건강하고 활발한 정신 상태를 나타냅니다.';
  }

  double _getEmotionValue(String emotion) {
    switch (emotion) {
      case 'happiness':
        return emotions.happiness;
      case 'sadness':
        return emotions.sadness;
      case 'anxiety':
        return emotions.anxiety;
      case 'sleepiness':
        return emotions.sleepiness;
      case 'curiosity':
        return emotions.curiosity;
      default:
        return 0.0;
    }
  }

  String _getSecondaryEmotion() {
    final emotionMap = {
      'happiness': emotions.happiness,
      'sadness': emotions.sadness,
      'anxiety': emotions.anxiety,
      'sleepiness': emotions.sleepiness,
      'curiosity': emotions.curiosity,
    };

    final sorted = emotionMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.length > 1 ? sorted[1].key : 'happiness';
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
