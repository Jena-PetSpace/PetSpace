import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/emotion_analysis.dart';

/// 행동 권장사항 카드
class EmotionRecommendationsCard extends StatelessWidget {
  final EmotionScores emotions;

  const EmotionRecommendationsCard({
    super.key,
    required this.emotions,
  });

  @override
  Widget build(BuildContext context) {
    final recommendations = _generateRecommendations();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.tips_and_updates,
                    color: Colors.green,
                    size: 24.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '권장 행동',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      Text(
                        '반려동물을 위한 맞춤 케어 가이드',
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

            // 즉시 해볼 것
            _buildRecommendationSection(
              title: '지금 바로 해보세요',
              icon: Icons.flash_on,
              color: Colors.orange,
              items: recommendations.immediateActions,
            ),

            SizedBox(height: 16.h),

            // 오늘 해볼 것
            _buildRecommendationSection(
              title: '오늘 해보면 좋아요',
              icon: Icons.today,
              color: Colors.blue,
              items: recommendations.todayActions,
            ),

            SizedBox(height: 16.h),

            // 장기적 케어
            _buildRecommendationSection(
              title: '지속적으로 신경 써주세요',
              icon: Icons.favorite,
              color: Colors.pink,
              items: recommendations.longTermCare,
            ),

            SizedBox(height: 16.h),

            // 주의사항
            if (recommendations.warnings.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.red, size: 18.w),
                        SizedBox(width: 8.w),
                        Text(
                          '주의사항',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    ...recommendations.warnings.map((warning) => Padding(
                      padding: EdgeInsets.only(bottom: 4.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(color: Colors.red, fontSize: 13.sp)),
                          Expanded(
                            child: Text(
                              warning,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.red.shade700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<_RecommendationItem> items,
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
        SizedBox(height: 8.h),
        ...items.map((item) => _buildRecommendationItem(item, color)),
      ],
    );
  }

  Widget _buildRecommendationItem(_RecommendationItem item, Color accentColor) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h, left: 26.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 4.h),
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                if (item.description != null)
                  Text(
                    item.description!,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.secondaryTextColor,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _Recommendations _generateRecommendations() {
    final dominant = emotions.dominantEmotion;
    final dominantValue = _getEmotionValue(dominant);

    switch (dominant) {
      case 'happiness':
        return _Recommendations(
          immediateActions: [
            _RecommendationItem(
              title: '함께 놀아주세요',
              description: '기쁜 상태를 유지하기 위해 좋아하는 놀이를 함께 해주세요.',
            ),
            _RecommendationItem(
              title: '사진을 찍어 기록하세요',
              description: '행복한 순간을 기록해두면 좋은 추억이 됩니다.',
            ),
          ],
          todayActions: [
            _RecommendationItem(
              title: '산책이나 외출',
              description: '긍정적인 에너지를 발산할 수 있는 야외 활동을 계획해보세요.',
            ),
            _RecommendationItem(
              title: '간식 보상',
              description: '좋은 행동에 대한 보상으로 건강한 간식을 주세요.',
            ),
          ],
          longTermCare: [
            _RecommendationItem(
              title: '일정한 놀이 시간 유지',
              description: '매일 비슷한 시간에 놀아주면 정서 안정에 도움이 됩니다.',
            ),
            _RecommendationItem(
              title: '긍정적인 환경 유지',
              description: '현재 환경이 좋은 영향을 주고 있으니 유지해주세요.',
            ),
          ],
          warnings: [],
        );

      case 'sadness':
        return _Recommendations(
          immediateActions: [
            _RecommendationItem(
              title: '따뜻하게 안아주세요',
              description: '신체 접촉은 반려동물에게 큰 위안이 됩니다.',
            ),
            _RecommendationItem(
              title: '부드러운 목소리로 말걸기',
              description: '차분하고 다정한 목소리로 안정감을 주세요.',
            ),
          ],
          todayActions: [
            _RecommendationItem(
              title: '좋아하는 간식 제공',
              description: '기분 전환을 위해 특별히 좋아하는 간식을 주세요.',
            ),
            _RecommendationItem(
              title: '함께 시간 보내기',
              description: '옆에 앉아 함께 있어주는 것만으로도 위안이 됩니다.',
            ),
          ],
          longTermCare: [
            _RecommendationItem(
              title: '규칙적인 일상 유지',
              description: '예측 가능한 루틴은 정서 안정에 도움이 됩니다.',
            ),
            _RecommendationItem(
              title: '분리 시간 점진적 늘리기',
              description: '분리불안이 있다면 천천히 혼자 있는 시간을 늘려주세요.',
            ),
          ],
          warnings: dominantValue > 0.7
              ? ['슬픔이 지속된다면 수의사 상담을 고려해보세요.', '식욕 저하나 무기력함이 계속되면 건강 문제일 수 있습니다.']
              : [],
        );

      case 'anxiety':
        return _Recommendations(
          immediateActions: [
            _RecommendationItem(
              title: '조용한 환경 만들기',
              description: 'TV나 음악 소리를 낮추고 조용한 공간을 만들어주세요.',
            ),
            _RecommendationItem(
              title: '안전한 은신처 제공',
              description: '숨을 수 있는 안전한 공간(크레이트, 담요 밑)을 확보해주세요.',
            ),
          ],
          todayActions: [
            _RecommendationItem(
              title: '스트레스 요인 파악',
              description: '불안의 원인이 무엇인지 관찰하고 제거해보세요.',
            ),
            _RecommendationItem(
              title: '가벼운 마사지',
              description: '부드럽게 쓰다듬어주면 긴장 완화에 도움이 됩니다.',
            ),
          ],
          longTermCare: [
            _RecommendationItem(
              title: '둔감화 훈련',
              description: '불안 요인에 점진적으로 노출시켜 적응을 돕습니다.',
            ),
            _RecommendationItem(
              title: '규칙적인 운동',
              description: '적절한 운동은 스트레스 해소에 효과적입니다.',
            ),
          ],
          warnings: dominantValue > 0.7
              ? ['높은 불안이 지속되면 분리불안 또는 공포증일 수 있습니다.', '행동 전문가나 수의사 상담을 권장합니다.']
              : ['갑작스러운 환경 변화는 피해주세요.'],
        );

      case 'sleepiness':
        return _Recommendations(
          immediateActions: [
            _RecommendationItem(
              title: '편안한 휴식 공간 제공',
              description: '조용하고 어두운 곳에서 쉴 수 있게 해주세요.',
            ),
            _RecommendationItem(
              title: '방해하지 않기',
              description: '졸릴 때는 충분히 쉬게 해주는 것이 좋습니다.',
            ),
          ],
          todayActions: [
            _RecommendationItem(
              title: '수면 환경 점검',
              description: '침대나 쿠션이 편안한지 확인해주세요.',
            ),
            _RecommendationItem(
              title: '적절한 실내 온도',
              description: '너무 덥거나 춥지 않은 환경을 유지해주세요.',
            ),
          ],
          longTermCare: [
            _RecommendationItem(
              title: '수면 패턴 관찰',
              description: '과도한 졸음은 건강 문제의 신호일 수 있습니다.',
            ),
            _RecommendationItem(
              title: '활동량 조절',
              description: '낮 동안 적절한 활동으로 밤에 숙면을 취하게 해주세요.',
            ),
          ],
          warnings: dominantValue > 0.8
              ? ['과도한 졸음이 계속된다면 건강 상태를 확인해보세요.']
              : [],
        );

      case 'curiosity':
        return _Recommendations(
          immediateActions: [
            _RecommendationItem(
              title: '탐색 기회 제공',
              description: '안전한 범위 내에서 새로운 것을 탐색하게 해주세요.',
            ),
            _RecommendationItem(
              title: '인터랙티브 장난감',
              description: '퍼즐 피더나 노즈워크 장난감으로 호기심을 충족시켜주세요.',
            ),
          ],
          todayActions: [
            _RecommendationItem(
              title: '새로운 산책 경로',
              description: '평소와 다른 길로 산책하면 새로운 자극이 됩니다.',
            ),
            _RecommendationItem(
              title: '훈련 시간',
              description: '새로운 트릭을 가르치기 좋은 상태입니다.',
            ),
          ],
          longTermCare: [
            _RecommendationItem(
              title: '정신적 자극 제공',
              description: '다양한 장난감과 활동으로 지루함을 방지해주세요.',
            ),
            _RecommendationItem(
              title: '사회화 기회',
              description: '다른 동물이나 사람과의 교류 기회를 만들어주세요.',
            ),
          ],
          warnings: [],
        );

      default:
        return _Recommendations(
          immediateActions: [
            _RecommendationItem(
              title: '관찰하기',
              description: '반려동물의 상태를 주의깊게 관찰해주세요.',
            ),
          ],
          todayActions: [
            _RecommendationItem(
              title: '일상 유지',
              description: '평소와 같은 루틴을 유지해주세요.',
            ),
          ],
          longTermCare: [
            _RecommendationItem(
              title: '지속적인 케어',
              description: '꾸준한 관심과 사랑을 보여주세요.',
            ),
          ],
          warnings: [],
        );
    }
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
}

class _Recommendations {
  final List<_RecommendationItem> immediateActions;
  final List<_RecommendationItem> todayActions;
  final List<_RecommendationItem> longTermCare;
  final List<String> warnings;

  _Recommendations({
    required this.immediateActions,
    required this.todayActions,
    required this.longTermCare,
    required this.warnings,
  });
}

class _RecommendationItem {
  final String title;
  final String? description;

  _RecommendationItem({
    required this.title,
    this.description,
  });
}
