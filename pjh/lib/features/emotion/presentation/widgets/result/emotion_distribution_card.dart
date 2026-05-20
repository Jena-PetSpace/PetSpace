import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../shared/themes/app_theme.dart';
import '../../../domain/entities/emotion_analysis.dart';
import '../../theme/emotion_result_tokens.dart';
import '../emotion_radar_chart.dart';

/// 감정 분포 카드.
/// - 헤더: "감정 분포" + 막대/레이더 토글
/// - 본문: 8감정 컬러 도트 + 바 그래프 (높은 점수 순)
///   - 0% 항목은 도트/텍스트 회색 처리 + 막대 채움 없음
class EmotionDistributionCard extends StatefulWidget {
  final EmotionScores scores;

  const EmotionDistributionCard({super.key, required this.scores});

  @override
  State<EmotionDistributionCard> createState() =>
      _EmotionDistributionCardState();
}

enum _ChartMode { bar, radar }

class _EmotionDistributionCardState extends State<EmotionDistributionCard> {
  _ChartMode _mode = _ChartMode.bar;

  /// 8감정을 (key, score) 페어로. 점수 내림차순.
  /// 0% 동률은 emotionOrder 순서 유지 (Dart sort는 stable).
  List<({String key, double score})> _items() {
    final e = widget.scores;
    final pairs = <({String key, double score})>[
      for (final k in AppTheme.emotionOrder)
        (key: k, score: _valueFor(k, e)),
    ];
    pairs.sort((a, b) => b.score.compareTo(a.score));
    return pairs;
  }

  double _valueFor(String key, EmotionScores e) {
    switch (key) {
      case 'happiness':  return e.happiness;
      case 'calm':       return e.calm;
      case 'excitement': return e.excitement;
      case 'curiosity':  return e.curiosity;
      case 'anxiety':    return e.anxiety;
      case 'fear':       return e.fear;
      case 'sadness':    return e.sadness;
      case 'discomfort': return e.discomfort;
      default:           return 0.0;
    }
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          // TODO(copy): EmotionDistributionCard 헤더
          '감정 분포',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: EmotionResultTokens.textPrimary,
          ),
        ),
        _buildToggle(),
      ],
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: EdgeInsets.all(2.r),
      decoration: BoxDecoration(
        color: EmotionResultTokens.amberSoft,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton('막대', _ChartMode.bar),
          _toggleButton('레이더', _ChartMode.radar),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, _ChartMode mode) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected
                ? EmotionResultTokens.textPrimary
                : EmotionResultTokens.grayDark,
          ),
        ),
      ),
    );
  }

  Widget _buildBarRow(({String key, double score}) item) {
    final isZero = item.score < 0.005; // 0.5% 미만이면 0% 취급
    final color = isZero
        ? EmotionResultTokens.grayInactive
        : AppTheme.getEmotionColor(item.key);
    final textColor = isZero
        ? EmotionResultTokens.grayText
        : EmotionResultTokens.textPrimary;
    final pct = (item.score * 100).round();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          // 컬러 도트
          Container(
            width: 10.r,
            height: 10.r,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8.w),
          // 감정명
          SizedBox(
            width: 60.w,
            child: Text(
              AppTheme.getEmotionLabel(item.key),
              style: TextStyle(
                fontSize: 12.sp,
                color: textColor,
              ),
            ),
          ),
          // 막대
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 6.h,
                  decoration: BoxDecoration(
                    color: EmotionResultTokens.grayBar,
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                ),
                if (!isZero)
                  FractionallySizedBox(
                    widthFactor: item.score.clamp(0.0, 1.0),
                    child: Container(
                      height: 6.h,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // %
          SizedBox(
            width: 32.w,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarBody() {
    final items = _items();
    return Column(
      children: items.map(_buildBarRow).toList(),
    );
  }

  Widget _buildRadarBody() {
    return Center(
      child: EmotionRadarChart(
        emotions: widget.scores,
        size: 240.r,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: EmotionResultTokens.cardSurface,
        borderRadius: BorderRadius.circular(EmotionResultTokens.radiusCard.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          SizedBox(height: 12.h),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _mode == _ChartMode.bar
                ? _buildBarBody()
                : _buildRadarBody(),
          ),
        ],
      ),
    );
  }
}
