import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/health_analysis.dart';
import '../../../utils/korean_particle.dart';
import '../../theme/emotion_result_tokens.dart';

/// 건강 분석 결과 페이지 최상단 HeroCard.
/// - 좌측: 도넛 게이지 (overallScore)
/// - 우측: 선택 부위 라벨 + 상태 칩 + 본문 메시지
/// - 하단: 분석 일시 · 펫 정보 메타 행
class HealthScoreCard extends StatelessWidget {
  final HealthAnalysis analysis;

  const HealthScoreCard({super.key, required this.analysis});

  int get _score => analysis.overallScore;

  /// 점수 기반 본문 메시지. petName + 받침 분기.
  String _buildBody() {
    final name = analysis.petName;
    final subject = withSubject(name);
    if (_score >= 90) {
      return '$subject 건강한 상태예요.\n좋은 컨디션을 유지해 주세요.';
    }
    if (_score >= 70) {
      return '$subject 살짝 신경 써볼 부분이 있어요.\n아래 발견 사항을 확인해 주세요.';
    }
    return '$subject 건강 신호에 변화가 있어요.\n수의사와 한번 상담해보시는 게 좋아요.';
  }

  Widget _buildDonut() {
    final color = EmotionResultTokens.scoreSignalColor(_score);
    return SizedBox(
      width: 84.r,
      height: 84.r,
      child: CustomPaint(
        painter: _DonutPainter(
          score: _score,
          fillColor: color,
          trackColor: EmotionResultTokens.scoreSignalBg(_score),
          strokeWidth: 8.r,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_score',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w600,
                  color: EmotionResultTokens.scoreSignalDark(_score),
                  height: 1.0,
                ),
              ),
              Text(
                '/ 100',
                style: TextStyle(
                  fontSize: 9.sp,
                  color: EmotionResultTokens.grayText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAreaLabel() {
    return Text(
      '선택 부위 · ${EmotionResultTokens.areaHeroLabel(analysis.area)}',
      style: TextStyle(
        fontSize: 10.sp,
        fontWeight: FontWeight.w500,
        color: EmotionResultTokens.navy,
      ),
    );
  }

  Widget _buildStatusChip() {
    final bg = EmotionResultTokens.scoreSignalBg(_score);
    final fg = EmotionResultTokens.scoreSignalDark(_score);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(EmotionResultTokens.radiusChip.r),
      ),
      child: Text(
        EmotionResultTokens.scoreStatusLabel(_score),
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        Flexible(child: _buildAreaLabel()),
        SizedBox(width: 6.w),
        _buildStatusChip(),
      ],
    );
  }

  Widget _buildMeta() {
    final dt = analysis.analyzedAt;
    final yyyy = dt.year.toString().padLeft(4, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final dateStr = '$yyyy.$mm.$dd $hh:$min';

    final petPart = (analysis.petName != null && analysis.petName!.isNotEmpty)
        ? analysis.petName!
        : null;

    final parts = <String>[dateStr];
    if (petPart != null) parts.add(petPart);

    return Padding(
      padding: EdgeInsets.only(top: 10.h),
      child: Container(
        padding: EdgeInsets.only(top: 10.h),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: EmotionResultTokens.dividerLight,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_outlined,
              size: 12.r,
              color: EmotionResultTokens.grayText,
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Text(
                parts.join('  ·  '),
                style: TextStyle(
                  fontSize: 10.sp,
                  color: EmotionResultTokens.grayText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: EmotionResultTokens.cardSurface,
        borderRadius: BorderRadius.circular(EmotionResultTokens.radiusCard.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDonut(),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderRow(),
                    SizedBox(height: 8.h),
                    Text(
                      _buildBody(),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: EmotionResultTokens.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildMeta(),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final int score;       // 0~100
  final Color fillColor;
  final Color trackColor;
  final double strokeWidth;

  _DonutPainter({
    required this.score,
    required this.fillColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 트랙 (배경 원)
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // 채움 (점수 비율)
    final ratio = (score.clamp(0, 100)) / 100.0;
    if (ratio > 0) {
      final fillPaint = Paint()
        ..color = fillColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      const startAngle = -math.pi / 2; // 12시 방향
      final sweepAngle = 2 * math.pi * ratio;
      canvas.drawArc(rect, startAngle, sweepAngle, false, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.score != score ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
