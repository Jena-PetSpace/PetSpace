import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/emotion_analysis.dart';
import '../bloc/emotion_analysis_bloc.dart';
import '../widgets/emotion_chart.dart';
import '../widgets/emotion_radar_chart.dart';
import '../widgets/emotion_interpretation_card.dart';
import '../widgets/emotion_recommendations_card.dart';

class EmotionResultPage extends StatefulWidget {
  final EmotionAnalysis analysis;
  final String? imagePath;

  const EmotionResultPage({
    super.key,
    required this.analysis,
    this.imagePath,
  });

  @override
  State<EmotionResultPage> createState() => _EmotionResultPageState();
}

class _EmotionResultPageState extends State<EmotionResultPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _memoController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _selectedChartType = 0; // 0: 레이더, 1: 파이, 2: 막대

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('감정 분석 결과'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareResult(),
          ),
        ],
      ),
      body: BlocListener<EmotionAnalysisBloc, EmotionAnalysisState>(
        listener: (context, state) {
          if (state is EmotionAnalysisSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('분석 결과가 저장되었습니다.')),
            );
            Navigator.of(context).pop();
          } else if (state is EmotionAnalysisError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageSection(),
                  SizedBox(height: 20.h),
                  _buildQuickSummary(),
                  SizedBox(height: 20.h),
                  _buildChartSection(),
                  SizedBox(height: 20.h),
                  EmotionInterpretationCard(emotions: widget.analysis.emotions),
                  SizedBox(height: 20.h),
                  EmotionRecommendationsCard(emotions: widget.analysis.emotions),
                  SizedBox(height: 20.h),
                  _buildMemoSection(),
                  SizedBox(height: 32.h),
                  _buildActionButtons(),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final dominantEmotion = widget.analysis.emotions.dominantEmotion;
    final dominantValue = _getEmotionValue(dominantEmotion);
    final emotionColor = AppTheme.getEmotionColor(dominantEmotion);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          // 이미지
          if (widget.imagePath != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                  child: Image.file(
                    File(widget.imagePath!),
                    width: double.infinity,
                    height: 220.h,
                    fit: BoxFit.cover,
                  ),
                ),
                // 감정 배지
                Positioned(
                  top: 12.w,
                  right: 12.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: emotionColor,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: emotionColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getEmotionIcon(dominantEmotion),
                          color: Colors.white,
                          size: 16.w,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '${_getEmotionName(dominantEmotion)} ${(dominantValue * 100).toInt()}%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          // 정보
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoChip(
                  icon: Icons.access_time,
                  label: '분석 시간',
                  value: _formatDateTime(widget.analysis.analyzedAt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16.w, color: AppTheme.secondaryTextColor),
        SizedBox(width: 6.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                color: AppTheme.secondaryTextColor,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickSummary() {
    final dominant = widget.analysis.emotions.dominantEmotion;
    final dominantValue = _getEmotionValue(dominant);
    final emotionColor = AppTheme.getEmotionColor(dominant);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            emotionColor.withValues(alpha: 0.2),
            emotionColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: emotionColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              color: emotionColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getEmotionEmoji(dominant),
                style: TextStyle(fontSize: 32.sp),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '반려동물이 ${_getEmotionName(dominant)} 상태예요',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${(dominantValue * 100).toInt()}%의 확률로 분석되었습니다',
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
    );
  }

  Widget _buildChartSection() {
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '감정 분포',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // 차트 타입 선택
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      _buildChartTypeButton(0, Icons.radar, '레이더'),
                      _buildChartTypeButton(1, Icons.pie_chart, '파이'),
                      _buildChartTypeButton(2, Icons.bar_chart, '막대'),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildSelectedChart(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartTypeButton(int index, IconData icon, String label) {
    final isSelected = _selectedChartType == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedChartType = index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16.w,
              color: isSelected ? Colors.white : AppTheme.secondaryTextColor,
            ),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                color: isSelected ? Colors.white : AppTheme.secondaryTextColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedChart() {
    switch (_selectedChartType) {
      case 0:
        return EmotionRadarChart(
          key: const ValueKey('radar'),
          emotions: widget.analysis.emotions,
          size: 220.w,
        );
      case 1:
        return Row(
          key: const ValueKey('pie'),
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            EmotionChart(emotions: widget.analysis.emotions, size: 150.w),
            SizedBox(width: 16.w),
            EmotionLegend(emotions: widget.analysis.emotions),
          ],
        );
      case 2:
        return EmotionBarChart(
          key: const ValueKey('bar'),
          emotions: widget.analysis.emotions,
          height: 200.h,
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildMemoSection() {
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
                Icon(Icons.note_alt, color: AppTheme.primaryColor, size: 20.w),
                SizedBox(width: 8.w),
                Text(
                  '메모',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _memoController,
              maxLines: 3,
              style: TextStyle(fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: '이 상황에 대한 메모를 남겨보세요...\n예: 산책 후 촬영, 밥 먹기 전 등',
                hintStyle: TextStyle(fontSize: 13.sp, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.withValues(alpha: 0.05),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
      builder: (context, state) {
        final isLoading = state is EmotionAnalysisSaving;

        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _saveAnalysis,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 2,
                ),
                icon: isLoading
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  isLoading ? '저장 중...' : '분석 결과 저장',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                icon: const Icon(Icons.close),
                label: Text('닫기', style: TextStyle(fontSize: 16.sp)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _saveAnalysis() {
    context.read<EmotionAnalysisBloc>().add(
      SaveAnalysisRequested(memo: _memoController.text.trim()),
    );
  }

  Future<void> _shareResult() async {
    try {
      final dominantEmotion = widget.analysis.emotions.dominantEmotion;
      final dominantValue = _getEmotionValue(dominantEmotion);
      final percentage = (dominantValue * 100).toInt();
      final emotionName = _getEmotionName(dominantEmotion);
      final emoji = _getEmotionEmoji(dominantEmotion);

      final text = '''
$emoji 펫페이스 AI 감정 분석 결과

주요 감정: $emotionName ($percentage%)
분석 시간: ${_formatDateTime(widget.analysis.analyzedAt)}

감정 점수:
😊 기쁨: ${(widget.analysis.emotions.happiness * 100).toInt()}%
😢 슬픔: ${(widget.analysis.emotions.sadness * 100).toInt()}%
😰 불안: ${(widget.analysis.emotions.anxiety * 100).toInt()}%
😴 졸림: ${(widget.analysis.emotions.sleepiness * 100).toInt()}%
🤔 호기심: ${(widget.analysis.emotions.curiosity * 100).toInt()}%

#펫페이스 #반려동물감정분석 #AI감정분석
''';

      if (widget.imagePath != null) {
        await Share.shareXFiles(
          [XFile(widget.imagePath!)],
          text: text,
          subject: '반려동물 AI 감정 분석 결과',
        );
      } else {
        await Share.share(
          text,
          subject: '반려동물 AI 감정 분석 결과',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공유 중 오류가 발생했습니다: $e')),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  double _getEmotionValue(String emotion) {
    switch (emotion) {
      case 'happiness':
        return widget.analysis.emotions.happiness;
      case 'sadness':
        return widget.analysis.emotions.sadness;
      case 'anxiety':
        return widget.analysis.emotions.anxiety;
      case 'sleepiness':
        return widget.analysis.emotions.sleepiness;
      case 'curiosity':
        return widget.analysis.emotions.curiosity;
      default:
        return 0.0;
    }
  }

  String _getEmotionName(String emotion) {
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
        return '알 수 없음';
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
        return '🤔';
      default:
        return '🐾';
    }
  }

  IconData _getEmotionIcon(String emotion) {
    switch (emotion) {
      case 'happiness':
        return Icons.mood;
      case 'sadness':
        return Icons.mood_bad;
      case 'anxiety':
        return Icons.warning_amber;
      case 'sleepiness':
        return Icons.bedtime;
      case 'curiosity':
        return Icons.psychology;
      default:
        return Icons.help_outline;
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
