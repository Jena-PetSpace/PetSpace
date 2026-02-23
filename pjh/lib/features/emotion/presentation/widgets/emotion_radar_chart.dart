import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/emotion_analysis.dart';

/// 감정 레이더 차트 위젯
class EmotionRadarChart extends StatelessWidget {
  final EmotionScores emotions;
  final double size;

  const EmotionRadarChart({
    super.key,
    required this.emotions,
    this.size = 250,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          ticksTextStyle: TextStyle(
            color: Colors.transparent,
            fontSize: 10.sp,
          ),
          tickBorderData: BorderSide(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
          gridBorderData: BorderSide(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
          radarBorderData: const BorderSide(color: Colors.transparent),
          titleTextStyle: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryTextColor,
          ),
          titlePositionPercentageOffset: 0.15,
          getTitle: (index, angle) {
            final titles = [
              _EmotionTitle('😊 기쁨', emotions.happiness),
              _EmotionTitle('😢 슬픔', emotions.sadness),
              _EmotionTitle('😰 불안', emotions.anxiety),
              _EmotionTitle('😴 졸림', emotions.sleepiness),
              _EmotionTitle('🤔 호기심', emotions.curiosity),
            ];
            return RadarChartTitle(
              text: '${titles[index].label}\n${(titles[index].value * 100).toInt()}%',
            );
          },
          dataSets: [
            RadarDataSet(
              fillColor: AppTheme.primaryColor.withValues(alpha: 0.3),
              borderColor: AppTheme.primaryColor,
              borderWidth: 2,
              entryRadius: 4,
              dataEntries: [
                RadarEntry(value: emotions.happiness),
                RadarEntry(value: emotions.sadness),
                RadarEntry(value: emotions.anxiety),
                RadarEntry(value: emotions.sleepiness),
                RadarEntry(value: emotions.curiosity),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmotionTitle {
  final String label;
  final double value;

  _EmotionTitle(this.label, this.value);
}

/// 감정 강도 게이지 위젯
class EmotionIntensityGauge extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  const EmotionIntensityGauge({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (value * 100).toInt();
    final intensity = _getIntensityLevel(value);

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20.w),
              SizedBox(width: 8.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  intensity.label,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Stack(
            children: [
              Container(
                height: 8.h,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                height: 8.h,
                width: (MediaQuery.of(context).size.width - 80.w) * value,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.7), color],
                  ),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                intensity.description,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _IntensityLevel _getIntensityLevel(double value) {
    if (value >= 0.7) {
      return _IntensityLevel('매우 높음', '강한 감정 상태');
    } else if (value >= 0.5) {
      return _IntensityLevel('높음', '뚜렷한 감정');
    } else if (value >= 0.3) {
      return _IntensityLevel('보통', '약간의 감정');
    } else if (value >= 0.1) {
      return _IntensityLevel('낮음', '미미한 감정');
    } else {
      return _IntensityLevel('매우 낮음', '거의 없음');
    }
  }
}

class _IntensityLevel {
  final String label;
  final String description;

  _IntensityLevel(this.label, this.description);
}

/// 감정 비교 막대 (수평)
class EmotionComparisonBar extends StatelessWidget {
  final EmotionScores emotions;

  const EmotionComparisonBar({super.key, required this.emotions});

  @override
  Widget build(BuildContext context) {
    final emotionList = [
      _EmotionData('기쁨', emotions.happiness, AppTheme.happinessColor, Icons.mood),
      _EmotionData('슬픔', emotions.sadness, AppTheme.sadnessColor, Icons.mood_bad),
      _EmotionData('불안', emotions.anxiety, AppTheme.anxietyColor, Icons.warning_amber),
      _EmotionData('졸림', emotions.sleepiness, AppTheme.sleepinessColor, Icons.bedtime),
      _EmotionData('호기심', emotions.curiosity, AppTheme.curiosityColor, Icons.psychology),
    ];

    // 값으로 정렬
    emotionList.sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: emotionList.asMap().entries.map((entry) {
        final index = entry.key;
        final emotion = entry.value;
        final isTop = index == 0;

        return Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: emotion.color.withValues(alpha: isTop ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: isTop ? Border.all(color: emotion.color, width: 2) : null,
                ),
                child: Icon(
                  emotion.icon,
                  color: emotion.color,
                  size: 18.w,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              emotion.label,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: isTop ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            if (isTop) ...[
                              SizedBox(width: 6.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: emotion.color,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  '주요 감정',
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${(emotion.value * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: emotion.color,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Stack(
                      children: [
                        Container(
                          height: 6.h,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3.r),
                          ),
                        ),
                        AnimatedContainer(
                          duration: Duration(milliseconds: 600 + (index * 100)),
                          curve: Curves.easeOutCubic,
                          height: 6.h,
                          width: (MediaQuery.of(context).size.width - 100.w) * emotion.value,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                emotion.color.withValues(alpha: 0.6),
                                emotion.color,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3.r),
                            boxShadow: isTop
                                ? [
                                    BoxShadow(
                                      color: emotion.color.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _EmotionData {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  _EmotionData(this.label, this.value, this.color, this.icon);
}
