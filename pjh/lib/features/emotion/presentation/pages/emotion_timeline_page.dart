import 'dart:developer' as dev;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';

class EmotionTimelinePage extends StatefulWidget {
  final String petId;
  final String petName;
  final String? petAvatarUrl;

  const EmotionTimelinePage({
    super.key,
    required this.petId,
    required this.petName,
    this.petAvatarUrl,
  });

  @override
  State<EmotionTimelinePage> createState() => _EmotionTimelinePageState();
}

class _EmotionTimelinePageState extends State<EmotionTimelinePage> {
  List<_TimelineEntry> _entries = [];
  int _daysRange = 30;
  bool _loading = true;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try {
      final response = await Supabase.instance.client.rpc(
        'get_emotion_timeline',
        params: {'p_pet_id': widget.petId, 'p_days': _daysRange},
      );
      if (mounted) {
        final list = (response as List).map((json) => _TimelineEntry(
          date: DateTime.parse(json['date'] as String),
          dominantEmotion: json['dominant_emotion'] as String? ?? 'happiness',
          dominantValue: (json['dominant_value'] as num?)?.toDouble() ?? 0,
          happiness: (json['happiness_avg'] as num?)?.toDouble() ?? 0,
          sadness: (json['sadness_avg'] as num?)?.toDouble() ?? 0,
          anger: (json['anger_avg'] as num?)?.toDouble() ?? 0,
          fear: (json['fear_avg'] as num?)?.toDouble() ?? 0,
          count: (json['analysis_count'] as num?)?.toInt() ?? 0,
          imageUrl: json['first_image_url'] as String?,
        )).toList();
        setState(() { _entries = list; _loading = false; });
      }
    } catch (e) {
      dev.log('EmotionTimeline load error: $e', name: 'EmotionTimeline');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.subtleBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${widget.petName}의 감정 기록',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700,
              color: AppTheme.primaryTextColor),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildHeaderCard(),
                    _buildRangeSelector(),
                    if (_entries.isNotEmpty) _buildChartCard(),
                    const SizedBox(height: 8),
                    Expanded(child: _buildTimelineList()),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_graph, size: 64.w, color: AppTheme.secondaryTextColor),
            SizedBox(height: 16.h),
            Text(
              '${widget.petName}의 첫 AI 감정분석을 해보세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15.sp, color: AppTheme.secondaryTextColor,
                  height: 1.5),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () => context.push('/emotion'),
              icon: const Icon(Icons.pets),
              label: const Text('지금 분석하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final totalCount = _entries.fold<int>(0, (sum, e) => sum + e.count);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24.r,
            backgroundImage: widget.petAvatarUrl != null
                ? CachedNetworkImageProvider(widget.petAvatarUrl!)
                : null,
            backgroundColor: AppTheme.subtleBackground,
            child: widget.petAvatarUrl == null
                ? Icon(Icons.pets, size: 24.w, color: AppTheme.primaryColor)
                : null,
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.petName,
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700,
                      color: AppTheme.primaryTextColor)),
              Text(
                '지난 $_daysRange일 동안 $totalCount회 분석',
                style: TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Row(
        children: [
          for (final days in [7, 30, 90])
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: GestureDetector(
                onTap: () {
                  if (_daysRange != days) {
                    setState(() => _daysRange = days);
                    _load();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: _daysRange == days
                        ? AppTheme.primaryColor
                        : AppTheme.subtleBackground,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Text(
                    '$days일',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: _daysRange == days
                          ? Colors.white
                          : AppTheme.secondaryTextColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    // 날짜순 정렬 (오래된 것 → 최신)
    final sorted = [..._entries]..sort((a, b) => a.date.compareTo(b.date));
    if (sorted.isEmpty) return const SizedBox.shrink();

    final emotions = {
      'happiness': AppTheme.successColor,
      'sadness': Colors.blue,
      'anger': Colors.red,
      'fear': Colors.orange,
    };

    List<LineChartBarData> lines = [];
    emotions.forEach((key, color) {
      final spots = sorted.asMap().entries.map((e) {
        final val = key == 'happiness' ? e.value.happiness
            : key == 'sadness' ? e.value.sadness
            : key == 'anger' ? e.value.anger
            : e.value.fear;
        return FlSpot(e.key.toDouble(), val.clamp(0.0, 1.0));
      }).toList();

      final hasData = spots.any((s) => s.y > 0.01);
      if (!hasData) return;

      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2,
        dotData: FlDotData(show: sorted.length <= 10),
        belowBarData: BarAreaData(show: false),
      ));
    });

    return Container(
      color: Colors.white,
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('감정 변화 흐름',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700,
                  color: AppTheme.primaryTextColor)),
          SizedBox(height: 4.h),
          // 범례
          Wrap(
            spacing: 12.w,
            children: emotions.entries.map((e) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10.w, height: 3.h,
                    color: e.value),
                SizedBox(width: 4.w),
                Text(AppTheme.getEmotionLabel(e.key),
                    style: TextStyle(fontSize: 10.sp,
                        color: AppTheme.secondaryTextColor)),
              ],
            )).toList(),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 160.h,
            child: lines.isEmpty
                ? Center(child: Text('차트 데이터 없음',
                    style: TextStyle(fontSize: 12.sp,
                        color: AppTheme.secondaryTextColor)))
                : LineChart(LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 0.25,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: AppTheme.dividerColor,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 0.5,
                          reservedSize: 28.w,
                          getTitlesWidget: (val, _) => Text(
                            val == 0 ? '0' : val == 0.5 ? '0.5' : '1',
                            style: TextStyle(fontSize: 9.sp,
                                color: AppTheme.secondaryTextColor),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: sorted.length <= 14,
                          getTitlesWidget: (val, _) {
                            final idx = val.toInt();
                            if (idx < 0 || idx >= sorted.length) {
                              return const SizedBox.shrink();
                            }
                            final d = sorted[idx].date;
                            return Padding(
                              padding: EdgeInsets.only(top: 4.h),
                              child: Text('${d.month}/${d.day}',
                                  style: TextStyle(fontSize: 9.sp,
                                      color: AppTheme.secondaryTextColor)),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: 1,
                    lineBarsData: lines,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots.map((s) {
                          final keys = ['happiness', 'sadness', 'anger', 'fear'];
                          final key = s.barIndex < keys.length
                              ? keys[s.barIndex] : '';
                          return LineTooltipItem(
                            '${AppTheme.getEmotionLabel(key)}: ${(s.y * 100).toInt()}%',
                            TextStyle(fontSize: 10.sp, color: Colors.white),
                          );
                        }).toList(),
                      ),
                    ),
                  )),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineList() {
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: _entries.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (ctx, i) => _buildTimelineCard(i),
    );
  }

  Widget _buildTimelineCard(int index) {
    final entry = _entries[index];
    final isExpanded = _expandedIndex == index;

    return GestureDetector(
      onTap: () => setState(() =>
          _expandedIndex = isExpanded ? null : index),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            children: [
              Row(
                children: [
                  // 썸네일
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: entry.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: entry.imageUrl!,
                            width: 56.w, height: 56.w,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _emojiBlock(entry),
                          )
                        : _emojiBlock(entry),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(entry.date),
                          style: TextStyle(fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.secondaryTextColor),
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Text(
                              AppTheme.getEmotionEmoji(entry.dominantEmotion),
                              style: TextStyle(fontSize: 20.sp),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              AppTheme.getEmotionLabel(entry.dominantEmotion),
                              style: TextStyle(fontSize: 15.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryTextColor),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              '${(entry.dominantValue * 100).toInt()}%',
                              style: TextStyle(fontSize: 13.sp,
                                  color: AppTheme.secondaryTextColor),
                            ),
                          ],
                        ),
                        if (entry.count > 1)
                          Text(
                            '${entry.count}회 분석 평균',
                            style: TextStyle(fontSize: 11.sp,
                                color: AppTheme.primaryColor),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: AppTheme.secondaryTextColor,
                    size: 20.w,
                  ),
                ],
              ),
              // 확장: 감정 바 차트
              if (isExpanded) ...[
                SizedBox(height: 12.h),
                const Divider(height: 1),
                SizedBox(height: 12.h),
                _buildEmotionBars(entry),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emojiBlock(_TimelineEntry entry) {
    return Container(
      width: 56.w, height: 56.w,
      decoration: BoxDecoration(
        color: AppTheme.subtleBackground,
        borderRadius: BorderRadius.circular(8.r),
      ),
      alignment: Alignment.center,
      child: Text(
        AppTheme.getEmotionEmoji(entry.dominantEmotion),
        style: TextStyle(fontSize: 28.sp),
      ),
    );
  }

  Widget _buildEmotionBars(_TimelineEntry entry) {
    final items = [
      ('happiness', entry.happiness),
      ('sadness', entry.sadness),
      ('anger', entry.anger),
      ('fear', entry.fear),
    ];
    return Column(
      children: items.map((item) {
        final label = AppTheme.getEmotionLabel(item.$1);
        final val = item.$2.clamp(0.0, 1.0);
        return Padding(
          padding: EdgeInsets.only(bottom: 6.h),
          child: Row(
            children: [
              SizedBox(
                width: 52.w,
                child: Text(label,
                    style: TextStyle(fontSize: 11.sp,
                        color: AppTheme.secondaryTextColor)),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: val,
                    minHeight: 8.h,
                    backgroundColor: AppTheme.dividerColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _emotionColor(item.$1),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Text('${(val * 100).toInt()}%',
                  style: TextStyle(fontSize: 11.sp,
                      color: AppTheme.secondaryTextColor)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _emotionColor(String emotion) {
    switch (emotion) {
      case 'happiness': return AppTheme.successColor;
      case 'sadness': return Colors.blue;
      case 'anger': return Colors.red;
      case 'fear': return Colors.orange;
      default: return AppTheme.primaryColor;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    if (diff < 7) return '$diff일 전';
    return '${date.month}월 ${date.day}일';
  }
}

class _TimelineEntry {
  final DateTime date;
  final String dominantEmotion;
  final double dominantValue;
  final double happiness, sadness, anger, fear;
  final int count;
  final String? imageUrl;

  _TimelineEntry({
    required this.date,
    required this.dominantEmotion,
    required this.dominantValue,
    required this.happiness,
    required this.sadness,
    required this.anger,
    required this.fear,
    required this.count,
    this.imageUrl,
  });
}
