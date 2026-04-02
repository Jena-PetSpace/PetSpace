import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/emotion_analysis.dart';
import '../bloc/emotion_analysis_bloc.dart';

class WeeklyReportPage extends StatelessWidget {
  const WeeklyReportPage({super.key});

  static const _emotionEmoji = {
    'happiness': '😊', 'sadness': '😢', 'anxiety': '😰',
    'sleepiness': '😴', 'curiosity': '🧐',
  };
  static const _emotionName = {
    'happiness': '행복', 'sadness': '슬픔', 'anxiety': '불안',
    'sleepiness': '졸림', 'curiosity': '호기심',
  };
  static const _emotionColor = {
    'happiness': Color(0xFF5BC0EB), 'sadness': Color(0xFF2C4482),
    'anxiety': Color(0xFFFF6F61), 'sleepiness': Color(0xFF1E3A5F),
    'curiosity': Color(0xFF0077B6),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('주간 감정 리포트', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
        centerTitle: true, backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryTextColor, elevation: 0.5,
      ),
      body: BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
        builder: (context, state) {
          if (state is! EmotionAnalysisHistoryLoaded || state.history.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('📊', style: TextStyle(fontSize: 48.sp)),
              SizedBox(height: 12.h),
              Text('아직 분석 기록이 없어요', style: TextStyle(fontSize: 14.sp, color: AppTheme.secondaryTextColor)),
            ]));
          }

          // 최근 7일 데이터 집계
          final now = DateTime.now();
          final weekAgo = now.subtract(const Duration(days: 7));
          final weekData = state.history.where((a) => a.analyzedAt.isAfter(weekAgo)).toList();

          // 일별 주감정
          final dayMap = <String, EmotionAnalysis>{};
          for (final a in weekData) {
            final key = '${a.analyzedAt.month}/${a.analyzedAt.day}';
            if (!dayMap.containsKey(key)) dayMap[key] = a;
          }

          // 감정 집계
          final emotionCount = <String, int>{};
          for (final a in weekData) {
            final d = a.emotions.dominantEmotion;
            emotionCount[d] = (emotionCount[d] ?? 0) + 1;
          }

          final topEmotion = emotionCount.isEmpty ? 'happiness'
              : emotionCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

          // 평균 행복도
          final avgHappiness = weekData.isEmpty ? 0.0
              : weekData.map((a) => a.emotions.happiness).reduce((a, b) => a + b) / weekData.length;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(children: [
              // 요약 카드
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('이번 주 리포트', style: TextStyle(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.7))),
                  SizedBox(height: 6.h),
                  Row(children: [
                    Text(_emotionEmoji[topEmotion] ?? '🐾', style: TextStyle(fontSize: 36.sp)),
                    SizedBox(width: 14.w),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${_emotionName[topEmotion] ?? ''} 감정이 많았어요',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('총 ${weekData.length}회 분석 · 평균 행복도 ${(avgHappiness * 100).round()}%',
                        style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.75))),
                    ]),
                  ]),
                ]),
              ),
              SizedBox(height: 16.h),

              // 일별 감정 타임라인
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('일별 감정 타임라인', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
                  SizedBox(height: 14.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (i) {
                      final day = now.subtract(Duration(days: 6 - i));
                      final key = '${day.month}/${day.day}';
                      final analysis = dayMap[key];
                      final dayLabel = ['월', '화', '수', '목', '금', '토', '일'][day.weekday - 1];
                      final emoji = analysis != null
                          ? (_emotionEmoji[analysis.emotions.dominantEmotion] ?? '🐾') : '';

                      return Column(children: [
                        Container(
                          width: 36.w, height: 36.w,
                          decoration: BoxDecoration(
                            color: analysis != null
                                ? (_emotionColor[analysis.emotions.dominantEmotion] ?? AppTheme.primaryColor).withValues(alpha: 0.15)
                                : AppTheme.subtleBackground,
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: analysis != null
                              ? Text(emoji, style: TextStyle(fontSize: 18.sp))
                              : Icon(Icons.remove, size: 14.w, color: AppTheme.lightTextColor)),
                        ),
                        SizedBox(height: 4.h),
                        Text(dayLabel, style: TextStyle(fontSize: 10.sp, color: AppTheme.secondaryTextColor)),
                      ]);
                    }),
                  ),
                ]),
              ),
              SizedBox(height: 14.h),

              // 감정 분포 바 차트
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('감정 분포', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
                  SizedBox(height: 14.h),
                  if (weekData.isEmpty)
                    Text('이번 주 분석 데이터가 없어요', style: TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor))
                  else
                    ...(emotionCount.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                      .map((e) {
                        final ratio = weekData.isEmpty ? 0.0 : e.value / weekData.length;
                        final color = _emotionColor[e.key] ?? AppTheme.primaryColor;
                        return Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: Row(children: [
                            Text(_emotionEmoji[e.key] ?? '', style: TextStyle(fontSize: 16.sp)),
                            SizedBox(width: 8.w),
                            SizedBox(width: 40.w, child: Text(_emotionName[e.key] ?? '',
                              style: TextStyle(fontSize: 11.sp, color: AppTheme.secondaryTextColor))),
                            Expanded(child: ClipRRect(
                              borderRadius: BorderRadius.circular(4.r),
                              child: LinearProgressIndicator(
                                value: ratio, backgroundColor: AppTheme.subtleBackground,
                                valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 10,
                              ),
                            )),
                            SizedBox(width: 8.w),
                            Text('${e.value}회', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: color)),
                          ]),
                        );
                      }),
                ]),
              ),
              SizedBox(height: 14.h),

              // AI 한마디
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('🤖', style: TextStyle(fontSize: 20.sp)),
                  SizedBox(width: 10.w),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AI 한마디', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
                    SizedBox(height: 4.h),
                    Text(
                      _getWeeklyComment(topEmotion, weekData.length, avgHappiness),
                      style: TextStyle(fontSize: 12.sp, color: AppTheme.primaryTextColor, height: 1.6),
                    ),
                  ])),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  String _getWeeklyComment(String topEmotion, int count, double avgHappiness) {
    if (count == 0) return '이번 주는 아직 분석 기록이 없어요. 오늘 반려동물의 감정을 분석해보세요! 🐾';
    final happinessStr = (avgHappiness * 100).round();
    final map = {
      'happiness': '이번 주 반려동물이 전반적으로 행복한 상태를 유지했어요! 평균 행복도 $happinessStr%로 아주 좋아요 😊 지금처럼 사랑을 듬뿍 주세요.',
      'sadness': '이번 주 반려동물이 다소 우울한 시간이 있었어요. 더 많은 스킨십과 놀이 시간을 늘려주세요 💙',
      'anxiety': '이번 주 불안한 순간이 있었어요. 조용하고 안정적인 환경을 만들어주세요. 규칙적인 일상도 도움이 돼요 🌿',
      'sleepiness': '이번 주 잘 쉬고 있는 것 같아요! 충분한 수면은 반려동물 건강에 매우 중요해요 😴',
      'curiosity': '이번 주 호기심이 왕성했어요! 새로운 장난감이나 탐색 공간을 제공해보세요 🧐',
    };
    return map[topEmotion] ?? '이번 주도 반려동물을 잘 보살펴주셔서 고마워요 🐾';
  }
}
