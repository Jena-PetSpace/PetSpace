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
                        Icon(Icons.warning_amber,
                            color: Colors.red, size: 18.w),
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
                              Text('• ',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 13.sp)),
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

  _Recommendations _generateRecommendations() {
    final dominant = emotions.dominantEmotion;
    final dominantValue = _getEmotionValue(dominant);

    switch (dominant) {
      case 'happiness':
        return _Recommendations(
          immediateActions: [
            _RecommendationItem(title: '함께 놀아주세요', description: '기쁜 상태를 유지하기 위해 좋아하는 놀이를 함께 해주세요.'),
            _RecommendationItem(title: '사진을 찍어 기록하세요', description: '행복한 순간을 기록해두면 좋은 추억이 됩니다.'),
          ],
          todayActions: [
            _RecommendationItem(title: '산책이나 외출', description: '긍정적인 에너지를 발산할 수 있는 야외 활동을 계획해보세요.'),
            _RecommendationItem(title: '간식 보상', description: '좋은 행동에 대한 보상으로 건강한 간식을 주세요.'),
          ],
          longTermCare: [
            _RecommendationItem(title: '일정한 놀이 시간 유지', description: '매일 비슷한 시간에 놀아주면 정서 안정에 도움이 됩니다.'),
            _RecommendationItem(title: '긍정적인 환경 유지', description: '현재 환경이 좋은 영향을 주고 있으니 유지해주세요.'),
          ],
          warnings: [],
        );
      case 'calm':
        return _Recommendations(
          immediateActions: [
            _RecommendationItem(title: '편안한 환경 유지', description: '현재의 평온함을 방해하지 않도록 조용한 환경을 유지해주세요.'),
            _RecommendationItem(title: '함께 쉬기', description: '옆에 조용히 앉아 함께 쉬어주세요.'),
          ],
          todayActions: [
            _RecommendationItem(title: '부드러운 스트레칭', description: '가벼운 마사지나 쓰다듬기로 편안함을 더해주세요.'),
            _RecommendationItem(title: '일상 루틴 유지', description: '평소와 같은 일상을 유지해 안정감을 보장해주세요.'),
          ],
          longTermCare: [
            _RecommendationItem(title: '안정적인 환경 조성', description: '편안한 상태가 지속되도록 변화를 최소화해주세요.'),
          ],
          warnings: [],
        );
      case 'excitement':
        return _Recommendations(
          immediateActions: [
            _RecommendationItem(title: '에너지 발산 놀이', description: '달리기, 공 던지기 등 활발한 놀이로 에너지를 발산시켜주세요.'),
            _RecommendationItem(title: '안전 확인', description: '흥분 상태에서 다치지 않도록 주변을 정리해주세요.'),
          ],
          todayActions: [
            _RecommendationItem(title: '야외 활동', description: '넓은 공간에서 마음껏 뛰어놀 수 있게 해주세요.'),
            _RecommendationItem(title: '사회화 활동', description: '다른 친구들과 어울릴 기회를 만들어주세요.'),
          ],
          longTermCare: [
            _RecommendationItem(title: '규칙적인 운동', description: '매일 충분한 운동으로 흥분 에너지를 건강하게 소모시켜주세요.'),
          ],
          warnings: dominantValue > 0.8
              ? ['과도한 흥분이 지속되면 공격성이나 과호흡이 발생할 수 있습니다.']
              : [],
        );
      case 'curiosity':
        return _Recommendations(
          immediateActions: [
            _RecommendationItem(title: '탐색 기회 제공', description: '안전한 범위 내에서 새로운 것을 탐색하게 해주세요.'),
            _RecommendationItem(title: '인터랙티브 장난감', description: '퍼즐 피더나 노즈워크 장난감으로 호기심을 충족시켜주세요.'),
          ],
          todayActions: [
            _RecommendationItem(title: '새로운 산책 경로', description: '평소와 다른 길로 산책하면 새로운 자극이 됩니다.'),
            _RecommendationItem(title: '훈련 시간', description: '새로운 트릭을 가르치기 좋은 상태입니다.'),
          ],
          longTermCare: [
            _RecommendationItem(title: '정신적 자극 제공', description: '다양한 장난감과 활동으로 지루함을 방지해주세요.'),
            _RecommendationItem(title: '사회화 기회', description: '다른 동물이나 사람과의 교류 기회를 만들어주세요.'),
          ],
          warnings: [],
        );
      case 'anxiety':
        return _Recommendations(
          immediateActions: [
            _RecommendationItem(title: '조용한 환경 만들기', description: 'TV나 음악 소리를 낮추고 조용한 공간을 만들어주세요.'),
            _RecommendationItem(title: '안전한 은신처 제공', description: '숨을 수 있는 안전한 공간(크레이트, 담요 밑)을 확보해주세요.'),
          ],
          todayActions: [
            _RecommendationItem(title: '스트레스 요인 파악', description: '불안의 원인이 무엇인지 관찰하고 제거해보세요.'),
            _RecommendationItem(title: '가벼운 마사지', description: '부드럽게 쓰다듬어주면 긴장 완화에 도움이 됩니다.'),
          ],
          longTermCare: [
            _RecommendationItem(title: '둔감화 훈련', description: '불안 요인에 점진적으로 노출시켜 적응을 돕습니다.'),
            _RecommendationItem(title: '규칙적인 운동', description: '적절한 운동은 스트레스 해소에 효과적입니다.'),
          ],
          warnings: dominantValue > 0.7
              ? ['높은 불안이 지속되면 분리불안 또는 공포증일 수 있습니다. 행동 전문가나 수의사 상담을 권장합니다.']
              : ['갑작스러운 환경 변화는 피해주세요.'],
        );
      case 'fear':
        return _Recommendations(
          immediateActions: [
            _RecommendationItem(title: '즉시 안심시키기', description: '조용하고 낮은 목소리로 안심시켜주세요. 억지로 안지 마세요.'),
            _RecommendationItem(title: '두려움 원인 제거', description: '공포를 유발하는 자극(소음, 낯선 사람 등)을 즉시 제거해주세요.'),
            _RecommendationItem(title: '안전한 공간으로 이동', description: '숨을 수 있는 안전하고 조용한 장소로 안내해주세요.'),
          ],
          todayActions: [
            _RecommendationItem(title: '강제로 노출시키지 않기', description: '두려움 원인에 억지로 접근시키면 역효과가 납니다.'),
            _RecommendationItem(title: '간식으로 긍정 연상', description: '공포 자극과 간식을 연결해 천천히 둔감화를 시작하세요.'),
          ],
          longTermCare: [
            _RecommendationItem(title: '체계적 둔감화', description: '전문가 지도 하에 공포 자극에 점진적으로 익숙해지게 합니다.'),
            _RecommendationItem(title: '안전 기지 확립', description: '집 안에 언제든 피할 수 있는 안전한 공간을 영구적으로 마련해주세요.'),
          ],
          warnings: [
            '강한 공포 반응이 반복되면 수의사나 동물행동 전문가 상담이 필요합니다.',
            if (dominantValue > 0.7) '극심한 공포는 공격 행동으로 전환될 수 있으니 주의하세요.',
          ],
        );
      case 'sadness':
        return _Recommendations(
          immediateActions: [
            _RecommendationItem(title: '따뜻하게 안아주세요', description: '신체 접촉은 반려동물에게 큰 위안이 됩니다.'),
            _RecommendationItem(title: '부드러운 목소리로 말걸기', description: '차분하고 다정한 목소리로 안정감을 주세요.'),
          ],
          todayActions: [
            _RecommendationItem(title: '좋아하는 간식 제공', description: '기분 전환을 위해 특별히 좋아하는 간식을 주세요.'),
            _RecommendationItem(title: '함께 시간 보내기', description: '옆에 앉아 함께 있어주는 것만으로도 위안이 됩니다.'),
          ],
          longTermCare: [
            _RecommendationItem(title: '규칙적인 일상 유지', description: '예측 가능한 루틴은 정서 안정에 도움이 됩니다.'),
            _RecommendationItem(title: '분리 시간 점진적 늘리기', description: '분리불안이 있다면 천천히 혼자 있는 시간을 늘려주세요.'),
          ],
          warnings: dominantValue > 0.7
              ? ['슬픔이 지속된다면 수의사 상담을 고려해보세요. 식욕 저하나 무기력함이 계속되면 건강 문제일 수 있습니다.']
              : [],
        );
      case 'discomfort':
        return _Recommendations(
          immediateActions: [
            _RecommendationItem(title: '신체 상태 확인', description: '피부 발진, 상처, 이물질 등 신체적 불편의 원인을 살펴보세요.'),
            _RecommendationItem(title: '환경 점검', description: '온도, 습도, 냄새 등 환경 요인을 확인해주세요.'),
          ],
          todayActions: [
            _RecommendationItem(title: '그루밍 점검', description: '털 엉킴, 발톱 상태, 귀 청결 등을 확인해주세요.'),
            _RecommendationItem(title: '식사 점검', description: '먹이 알레르기나 소화 문제가 있는지 확인해주세요.'),
          ],
          longTermCare: [
            _RecommendationItem(title: '정기 건강 검진', description: '만성적 불편함은 내부 질환의 신호일 수 있습니다.'),
            _RecommendationItem(title: '환경 최적화', description: '온도·습도·소음 등 생활 환경을 꾸준히 관리해주세요.'),
          ],
          warnings: dominantValue > 0.7
              ? ['불편함이 지속되거나 강도가 높다면 수의사 진료를 받아보세요.']
              : [],
        );
      default:
        return _Recommendations(
          immediateActions: [
            _RecommendationItem(title: '관찰하기', description: '반려동물의 상태를 주의깊게 관찰해주세요.'),
          ],
          todayActions: [
            _RecommendationItem(title: '일상 유지', description: '평소와 같은 루틴을 유지해주세요.'),
          ],
          longTermCare: [
            _RecommendationItem(title: '지속적인 케어', description: '꾸준한 관심과 사랑을 보여주세요.'),
          ],
          warnings: [],
        );
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
