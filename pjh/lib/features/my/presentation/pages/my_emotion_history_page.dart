import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../emotion/presentation/bloc/emotion_analysis_bloc.dart';
import '../../../emotion/domain/entities/emotion_analysis.dart';

class MyEmotionHistoryPage extends StatefulWidget {
  const MyEmotionHistoryPage({super.key});

  @override
  State<MyEmotionHistoryPage> createState() => _MyEmotionHistoryPageState();
}

class _MyEmotionHistoryPageState extends State<MyEmotionHistoryPage> {
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<EmotionAnalysisBloc>().add(
            LoadAnalysisHistory(userId: authState.user.uid, limit: 50),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '감정분석 기록',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
        builder: (context, state) {
          if (state is EmotionAnalysisHistoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is EmotionAnalysisHistoryLoaded) {
            if (state.history.isEmpty) {
              return _buildEmptyState();
            }
            return _buildHistoryList(state.history);
          }
          if (state is EmotionAnalysisError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48.w, color: Colors.grey[400]),
                  SizedBox(height: 12.h),
                  Text(state.message,
                      style: TextStyle(
                          fontSize: 14.sp, color: AppTheme.secondaryTextColor)),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                      onPressed: _loadHistory, child: const Text('다시 시도')),
                ],
              ),
            );
          }
          // 로딩 시작 전 상태
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.psychology_outlined, size: 64.w, color: Colors.grey[300]),
          SizedBox(height: 16.h),
          Text(
            '감정분석 기록이 없습니다',
            style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryTextColor),
          ),
          SizedBox(height: 8.h),
          Text(
            'AI분석 탭에서 반려동물의\n감정을 분석해보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.secondaryTextColor,
                height: 1.5),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () => context.go('/emotion'),
            icon: const Icon(Icons.psychology),
            label: const Text('감정분석 하러가기'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<EmotionAnalysis> history) {
    return RefreshIndicator(
      onRefresh: () async {
        _loadHistory();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: history.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (context, index) {
          final analysis = history[index];
          return _buildAnalysisCard(analysis);
        },
      ),
    );
  }

  Widget _buildAnalysisCard(EmotionAnalysis analysis) {
    final dominant = analysis.emotions.dominantEmotion;
    final dominantKr = _getEmotionKorean(dominant);
    final emoji = _getEmotionEmoji(dominant);
    final date = _formatDate(analysis.analyzedAt);
    final stress = analysis.emotions.stressLevel;

    return GestureDetector(
      onTap: () => context.push('/emotion/result/${analysis.id}'),
      child: Container(
        decoration: AppTheme.cardDecoration,
        padding: EdgeInsets.all(14.w),
        child: Row(
          children: [
            // 감정 이모지
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: _getEmotionColor(dominant).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Center(
                child: Text(emoji, style: TextStyle(fontSize: 22.sp)),
              ),
            ),
            SizedBox(width: 12.w),

            // 감정 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$emoji $dominantKr',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryTextColor,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    '스트레스 $stress점 · $date',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),

            // 감정 바
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildMiniBar(
                    '기쁨', analysis.emotions.happiness, AppTheme.happinessColor),
                SizedBox(height: 2.h),
                _buildMiniBar(
                    '불안', analysis.emotions.anxiety, AppTheme.anxietyColor),
                SizedBox(height: 2.h),
                _buildMiniBar('호기심', analysis.emotions.curiosity,
                    AppTheme.curiosityColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBar(String label, double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 50.w,
          height: 4.h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2.r),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${date.month}/${date.day}';
  }

  String _getEmotionKorean(String emotion) {
    switch (emotion) {
      case 'happiness':
        return '기쁨';
      case 'sadness':
        return '슬픔';
      case 'anxiety':
        return '불안';
      case 'sleepiness':
        return '졸림';
      case 'curiosity':
        return '호기심';
      default:
        return emotion;
    }
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion) {
      case 'happiness':
        return '😊';
      case 'sadness':
        return '😢';
      case 'anxiety':
        return '😰';
      case 'sleepiness':
        return '😴';
      case 'curiosity':
        return '🧐';
      default:
        return '🐾';
    }
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion) {
      case 'happiness':
        return AppTheme.happinessColor;
      case 'sadness':
        return AppTheme.sadnessColor;
      case 'anxiety':
        return AppTheme.anxietyColor;
      case 'sleepiness':
        return AppTheme.sleepinessColor;
      case 'curiosity':
        return AppTheme.curiosityColor;
      default:
        return AppTheme.primaryColor;
    }
  }
}
