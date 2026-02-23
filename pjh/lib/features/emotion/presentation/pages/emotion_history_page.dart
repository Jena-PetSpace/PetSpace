import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/emotion_analysis.dart';
import '../bloc/emotion_analysis_bloc.dart';
import '../widgets/emotion_chart.dart';
import 'emotion_result_page.dart';

class EmotionHistoryPage extends StatefulWidget {
  final String userId;
  final String? petId;

  const EmotionHistoryPage({
    super.key,
    required this.userId,
    this.petId,
  });

  @override
  State<EmotionHistoryPage> createState() => _EmotionHistoryPageState();
}

class _EmotionHistoryPageState extends State<EmotionHistoryPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedEmotion; // 필터링할 감정 타입

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    context.read<EmotionAnalysisBloc>().add(
      LoadAnalysisHistory(
        userId: widget.userId,
        petId: widget.petId,
        startDate: _startDate,
        endDate: _endDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('감정 분석 히스토리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
        builder: (context, state) {
          if (state is EmotionAnalysisHistoryLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is EmotionAnalysisHistoryLoaded) {
            return _buildHistoryList(state.history);
          } else if (state is EmotionAnalysisError) {
            return _buildErrorState(state.message);
          }

          return const Center(child: Text('히스토리를 불러오는 중...'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showStatistics(),
        child: const Icon(Icons.bar_chart),
      ),
    );
  }

  Widget _buildHistoryList(List<EmotionAnalysis> history) {
    // 감정 필터 적용
    List<EmotionAnalysis> filteredHistory = history;
    if (_selectedEmotion != null) {
      filteredHistory = history.where((analysis) {
        return analysis.emotions.dominantEmotion == _selectedEmotion;
      }).toList();
    }

    if (filteredHistory.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async => _loadHistory(),
      child: Column(
        children: [
          // 활성 필터 표시
          if (_startDate != null || _endDate != null || _selectedEmotion != null)
            _buildActiveFilters(),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: filteredHistory.length,
              itemBuilder: (context, index) {
                final analysis = filteredHistory[index];
                return _buildHistoryItem(analysis);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(EmotionAnalysis analysis) {
    final dominantEmotion = analysis.emotions.dominantEmotion;
    final dominantValue = _getEmotionValue(analysis.emotions, dominantEmotion);

    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      child: InkWell(
        onTap: () => _navigateToDetail(analysis),
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 이미지 썸네일
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: analysis.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: analysis.imageUrl,
                            width: 60.w,
                            height: 60.w,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 60.w,
                              height: 60.w,
                              color: Colors.grey[200],
                              child: Icon(Icons.pets, size: 24.w),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 60.w,
                              height: 60.w,
                              color: Colors.grey[200],
                              child: Icon(Icons.error, size: 24.w),
                            ),
                          )
                        : Container(
                            width: 60.w,
                            height: 60.w,
                            color: Colors.grey[200],
                            child: Icon(Icons.pets, size: 24.w),
                          ),
                  ),
                  SizedBox(width: 16.w),

                  // 분석 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getEmotionIcon(dominantEmotion),
                              color: AppTheme.getEmotionColor(dominantEmotion),
                              size: 20.w,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              '${_getEmotionName(dominantEmotion)} ${(dominantValue * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.getEmotionColor(dominantEmotion),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          _formatDateTime(analysis.analyzedAt),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        if (analysis.memo != null && analysis.memo!.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            analysis.memo!,
                            style: TextStyle(fontSize: 12.sp),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 미니 차트
                  SizedBox(
                    width: 40.w,
                    height: 40.w,
                    child: EmotionChart(
                      emotions: analysis.emotions,
                      size: 40.w,
                    ),
                  ),
                ],
              ),

              // 감정 바
              SizedBox(height: 12.h),
              _buildEmotionBar(analysis.emotions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmotionBar(EmotionScores emotions) {
    final emotionData = [
      {'value': emotions.happiness, 'color': AppTheme.happinessColor},
      {'value': emotions.sadness, 'color': AppTheme.sadnessColor},
      {'value': emotions.anxiety, 'color': AppTheme.anxietyColor},
      {'value': emotions.sleepiness, 'color': AppTheme.sleepinessColor},
      {'value': emotions.curiosity, 'color': AppTheme.curiosityColor},
    ];

    return Row(
      children: emotionData.map((emotion) {
        final value = emotion['value'] as double;
        final color = emotion['color'] as Color;

        return Expanded(
          flex: (value * 100).toInt(),
          child: Container(
            height: 4.h,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.all(Radius.circular(2.r)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64.w,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16.h),
          Text(
            '아직 분석 기록이 없습니다',
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '첫 번째 감정 분석을 시작해보세요!',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.w,
            color: Colors.red,
          ),
          SizedBox(height: 16.h),
          Text(
            '오류가 발생했습니다',
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _loadHistory,
            child: Text('다시 시도', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          if (_startDate != null || _endDate != null)
            Chip(
              label: Text(
                '${_startDate?.toString().split(' ')[0] ?? '시작'} ~ ${_endDate?.toString().split(' ')[0] ?? '종료'}',
                style: TextStyle(fontSize: 12.sp),
              ),
              deleteIcon: Icon(Icons.close, size: 18.w),
              onDeleted: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                });
                _loadHistory();
              },
            ),
          if (_selectedEmotion != null)
            Chip(
              label: Text(
                _getEmotionName(_selectedEmotion!),
                style: TextStyle(fontSize: 12.sp),
              ),
              backgroundColor: AppTheme.getEmotionColor(_selectedEmotion!).withValues(alpha: 0.2),
              deleteIcon: Icon(Icons.close, size: 18.w),
              onDeleted: () {
                setState(() {
                  _selectedEmotion = null;
                });
                // 클라이언트 측 필터링이므로 재로드 불필요
              },
            ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('필터'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('기간', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('시작일'),
                  subtitle: Text(_startDate?.toString().split(' ')[0] ?? '선택되지 않음'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _startDate = date);
                      setDialogState(() {});
                    }
                  },
                ),
                ListTile(
                  title: const Text('종료일'),
                  subtitle: Text(_endDate?.toString().split(' ')[0] ?? '선택되지 않음'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _endDate = date);
                      setDialogState(() {});
                    }
                  },
                ),
                const Divider(),
                const Text('감정', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildEmotionFilterChip('happiness', '기쁨', setDialogState),
                    _buildEmotionFilterChip('sadness', '슬픔', setDialogState),
                    _buildEmotionFilterChip('anxiety', '불안', setDialogState),
                    _buildEmotionFilterChip('sleepiness', '졸림', setDialogState),
                    _buildEmotionFilterChip('curiosity', '호기심', setDialogState),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _selectedEmotion = null;
                });
                Navigator.pop(context);
                _loadHistory();
              },
              child: const Text('초기화'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadHistory();
              },
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionFilterChip(String emotion, String label, StateSetter setDialogState) {
    final isSelected = _selectedEmotion == emotion;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.getEmotionColor(emotion).withValues(alpha: 0.3),
      onSelected: (selected) {
        setState(() {
          _selectedEmotion = selected ? emotion : null;
        });
        setDialogState(() {});
      },
    );
  }

  void _showStatistics() {
    context.read<EmotionAnalysisBloc>().add(
      LoadEmotionStatistics(
        userId: widget.userId,
        petId: widget.petId,
        startDate: _startDate,
        endDate: _endDate,
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
            builder: (context, state) {
              if (state is EmotionStatisticsLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is EmotionStatisticsLoaded) {
                return _buildStatisticsSheet(state.statistics, scrollController);
              } else if (state is EmotionAnalysisError) {
                return Center(child: Text(state.message));
              }
              return const Center(child: Text('통계를 불러오는 중...'));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSheet(Map<String, dynamic> statistics, ScrollController scrollController) {
    final averageEmotions = statistics['averageEmotions'] as Map<String, dynamic>;
    final totalAnalyses = statistics['totalAnalyses'] as int;
    final dominantEmotion = statistics['dominantEmotion'] as String?;

    return SingleChildScrollView(
      controller: scrollController,
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '감정 분석 통계',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20.h),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard('총 분석 횟수', '$totalAnalyses회', Icons.analytics),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildStatCard(
                    '주요 감정',
                    dominantEmotion != null ? _getEmotionName(dominantEmotion) : '없음',
                    _getEmotionIcon(dominantEmotion ?? ''),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20.h),
            Text(
              '평균 감정 분포',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16.h),

            if (averageEmotions.isNotEmpty)
              EmotionBarChart(
                emotions: EmotionScores(
                  happiness: (averageEmotions['happiness'] ?? 0.0).toDouble(),
                  sadness: (averageEmotions['sadness'] ?? 0.0).toDouble(),
                  anxiety: (averageEmotions['anxiety'] ?? 0.0).toDouble(),
                  sleepiness: (averageEmotions['sleepiness'] ?? 0.0).toDouble(),
                  curiosity: (averageEmotions['curiosity'] ?? 0.0).toDouble(),
                ),
                height: 200.h,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Icon(icon, size: 32.w, color: AppTheme.primaryColor),
            SizedBox(height: 8.h),
            Text(
              value,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(EmotionAnalysis analysis) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmotionResultPage(
          analysis: analysis,
          imagePath: analysis.localImagePath,
        ),
      ),
    );
  }

  double _getEmotionValue(EmotionScores emotions, String emotion) {
    switch (emotion) {
      case 'happiness': return emotions.happiness;
      case 'sadness': return emotions.sadness;
      case 'anxiety': return emotions.anxiety;
      case 'sleepiness': return emotions.sleepiness;
      case 'curiosity': return emotions.curiosity;
      default: return 0.0;
    }
  }

  String _getEmotionName(String emotion) {
    switch (emotion) {
      case 'happiness': return '기쁨';
      case 'sadness': return '슬픔';
      case 'anxiety': return '불안';
      case 'sleepiness': return '졸림';
      case 'curiosity': return '호기심';
      default: return '알 수 없음';
    }
  }

  IconData _getEmotionIcon(String emotion) {
    switch (emotion) {
      case 'happiness': return Icons.mood;
      case 'sadness': return Icons.mood_bad;
      case 'anxiety': return Icons.warning;
      case 'sleepiness': return Icons.bedtime;
      case 'curiosity': return Icons.psychology;
      default: return Icons.help_outline;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}