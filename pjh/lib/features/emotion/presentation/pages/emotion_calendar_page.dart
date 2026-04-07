import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/emotion_analysis.dart';
import '../bloc/emotion_analysis_bloc.dart';

class EmotionCalendarPage extends StatefulWidget {
  const EmotionCalendarPage({super.key});

  @override
  State<EmotionCalendarPage> createState() => _EmotionCalendarPageState();
}

class _EmotionCalendarPageState extends State<EmotionCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 날짜 → 분석 목록 맵
  Map<DateTime, List<EmotionAnalysis>> _analysisMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  void _loadHistory() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<EmotionAnalysisBloc>().add(
            LoadAnalysisHistory(userId: authState.user.uid, limit: 200),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('감정 캘린더',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryTextColor,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
        builder: (context, state) {
          if (state is EmotionAnalysisHistoryLoaded) {
            _buildAnalysisMap(state.history);
          }

          final selectedAnalyses = _selectedDay != null
              ? (_analysisMap[_dateOnly(_selectedDay!)] ?? <EmotionAnalysis>[])
              : <EmotionAnalysis>[];

          return Column(
            children: [
              // 캘린더
              Container(
                color: Colors.white,
                child: TableCalendar<EmotionAnalysis>(
                  firstDay: DateTime.utc(2024, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) =>
                      isSameDay(_selectedDay, day),
                  eventLoader: (day) =>
                      _analysisMap[_dateOnly(day)] ?? [],
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: TextStyle(
                        color: Colors.white, fontSize: 13.sp),
                    todayTextStyle: TextStyle(
                        color: AppTheme.primaryColor, fontSize: 13.sp),
                    defaultTextStyle:
                        TextStyle(fontSize: 13.sp, color: AppTheme.primaryTextColor),
                    weekendTextStyle:
                        TextStyle(fontSize: 13.sp, color: AppTheme.highlightColor),
                    outsideTextStyle:
                        TextStyle(fontSize: 13.sp, color: AppTheme.lightTextColor),
                    markersMaxCount: 1,
                    markerDecoration: const BoxDecoration(
                      color: AppTheme.highlightColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                        fontSize: 15.sp, fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTextColor),
                    leftChevronIcon: Icon(Icons.chevron_left,
                        color: AppTheme.primaryColor, size: 22.w),
                    rightChevronIcon: Icon(Icons.chevron_right,
                        color: AppTheme.primaryColor, size: 22.w),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                        fontSize: 11.sp, color: AppTheme.secondaryTextColor,
                        fontWeight: FontWeight.w600),
                    weekendStyle: TextStyle(
                        fontSize: 11.sp, color: AppTheme.highlightColor,
                        fontWeight: FontWeight.w600),
                  ),
                  // 날짜 빌더 - 이모지 오버레이
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return null;
                      final dominant = events.first.emotions.dominantEmotion;
                      final emoji = AppTheme.getEmotionEmoji(dominant);
                      return Positioned(
                        bottom: 2,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(emoji, style: TextStyle(fontSize: 10.sp)),
                            if (events.length > 1)
                              Text('+${events.length - 1}',
                                style: TextStyle(fontSize: 7.sp, color: AppTheme.highlightColor, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      );
                    },
                  ),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay = focused;
                    });
                  },
                  onPageChanged: (focused) {
                    setState(() => _focusedDay = focused);
                  },
                ),
              ),

              // 선택된 날짜 분석 목록
              // 월별 통계 요약
              if (_selectedDay == null)
                _buildMonthSummary(state),

              Expanded(
                child: selectedAnalyses.isEmpty
                    ? _buildEmptyState()
                    : _buildDayAnalysisList(selectedAnalyses),
              ),
            ],
          );
        },
      ),
    );
  }

  void _buildAnalysisMap(List<EmotionAnalysis> history) {
    _analysisMap = {};
    for (final a in history) {
      final key = _dateOnly(a.analyzedAt);
      _analysisMap[key] = (_analysisMap[key] ?? [])..add(a);
    }
  }

  DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  Widget _buildMonthSummary(EmotionAnalysisState state) {
    if (state is! EmotionAnalysisHistoryLoaded) return const SizedBox.shrink();

    final now = _focusedDay;
    final thisMonth = state.history.where((a) =>
        a.analyzedAt.year == now.year &&
        a.analyzedAt.month == now.month).toList();

    if (thisMonth.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppTheme.subtleBackground,
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('📊', style: TextStyle(fontSize: 20.sp)),
              SizedBox(width: 10.w),
              Text('이번 달 분석 기록이 없어요',
                style: TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor)),
            ],
          ),
        ),
      );
    }

    // 이번 달 주감정 집계
    final emotionCount = <String, int>{};
    for (final a in thisMonth) {
      final d = a.emotions.dominantEmotion;
      emotionCount[d] = (emotionCount[d] ?? 0) + 1;
    }
    final topEmotion = emotionCount.entries
        .reduce((a, b) => a.value > b.value ? a : b).key;
    final emoji = AppTheme.getEmotionEmoji(topEmotion);

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Text(emoji, style: TextStyle(fontSize: 28.sp)),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${now.month}월 분석 요약',
                    style: TextStyle(fontSize: 11.sp, color: AppTheme.secondaryTextColor),
                  ),
                  Text(
                    '총 ${thisMonth.length}회 · 가장 많은 감정: ${AppTheme.getEmotionLabel(topEmotion)}',
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppTheme.primaryTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_selectedDay == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📅', style: TextStyle(fontSize: 48.sp)),
            SizedBox(height: 12.h),
            Text('날짜를 선택하면\n해당 날의 감정 분석을 볼 수 있어요',
                style: TextStyle(
                    fontSize: 13.sp,
                    color: AppTheme.secondaryTextColor,
                    height: 1.6),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔍', style: TextStyle(fontSize: 36.sp)),
          SizedBox(height: 10.h),
          Text('이 날은 분석 기록이 없어요',
              style: TextStyle(
                  fontSize: 13.sp, color: AppTheme.secondaryTextColor)),
          SizedBox(height: 16.h),
          ElevatedButton.icon(
            onPressed: () => context.go('/emotion'),
            icon: Icon(Icons.psychology_outlined, size: 18.w),
            label: const Text('지금 분석하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayAnalysisList(List<EmotionAnalysis> analyses) {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: analyses.length,
      itemBuilder: (context, index) {
        final a = analyses[index];
        final dominant = a.emotions.dominantEmotion;
        final emoji = AppTheme.getEmotionEmoji(dominant);
        final name = AppTheme.getEmotionLabel(dominant);
        final time = '${a.analyzedAt.hour.toString().padLeft(2, '0')}:'
            '${a.analyzedAt.minute.toString().padLeft(2, '0')}';

        return GestureDetector(
          onTap: () => context.push('/emotion/result/${a.id}'),
          child: Container(
            margin: EdgeInsets.only(bottom: 10.h),
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 이모지 원형 배경
                Container(
                  width: 50.w,
                  height: 50.w,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(emoji,
                        style: TextStyle(fontSize: 24.sp)),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name ${(a.emotions.happiness * 100).round()}%',
                        style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryTextColor),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        a.petName ?? '반려동물',
                        style: TextStyle(
                            fontSize: 11.sp,
                            color: AppTheme.secondaryTextColor),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(time,
                        style: TextStyle(
                            fontSize: 11.sp,
                            color: AppTheme.secondaryTextColor)),
                    SizedBox(height: 4.h),
                    Icon(Icons.chevron_right,
                        size: 18.w, color: AppTheme.lightTextColor),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
