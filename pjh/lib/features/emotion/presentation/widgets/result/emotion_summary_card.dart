import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../shared/themes/app_theme.dart';
import '../../../domain/entities/emotion_analysis.dart';
import '../../../utils/korean_particle.dart';
import '../../theme/emotion_result_tokens.dart';

/// HeroCard — 결과 페이지 최상단 요약 카드.
/// - 보라(purple) 배경, 흰 텍스트
/// - 주감정명(대문자) + % + 멘트
/// - 이전 분석 대비 변화 칩 (previousAnalysis != null + delta ≥ 5%인 항목만, 최대 2개)
class EmotionSummaryCard extends StatelessWidget {
  final EmotionAnalysis analysis;
  final EmotionAnalysis? previousAnalysis;
  final String? petName;

  const EmotionSummaryCard({
    super.key,
    required this.analysis,
    this.previousAnalysis,
    this.petName,
  });

  // 보라 톤은 HeroCard 전용. 토큰화하지 않고 카드 내부 상수로 둠.
  // (다른 카드는 베이지/코랄/네이비 톤 사용 — 의도된 색 분리)
  static const Color _bg = Color(0xFF6B5FB5);

  String _dominantKey() => analysis.emotions.dominantEmotion;

  double _dominantScore() {
    final e = analysis.emotions;
    switch (_dominantKey()) {
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

  /// 결과 요약 멘트.
  /// 우선순위: 강한 부정 > 강한 긍정 > 강한 흥분 > 강한 호기심 > 평온.
  /// 펫 이름 + 주격 조사(이/가)는 [withSubject] 헬퍼로 받침 자동 분기.
  String _buildMessage(String name) {
    final e = analysis.emotions;
    final negSum = e.anxiety + e.sadness + e.fear;
    final posSum = e.happiness + e.calm;
    final subject = withSubject(name); // "토토가" / "초롱이"

    if (negSum > 0.5) {
      // 부정 케이스
      final k = _dominantKey();
      final feel = switch (k) {
        'fear' => '무서워하고',
        'anxiety' => '불안해하고',
        'sadness' => '시무룩해하고',
        'discomfort' => '불편해하고',
        _ => '힘들어하고',
      };
      return '지금 $subject $feel 있어요.\n곁에서 차분히 안심시켜 주세요.';
    }
    if (posSum > 0.6) {
      return '오늘 $subject 편안하고 행복해 보여요.\n이 분위기를 함께 즐겨주세요.';
    }
    if (e.excitement > 0.5) {
      return '$subject 한껏 들떠 있어요.\n에너지를 차분히 풀어주세요.';
    }
    if (e.curiosity > 0.5) {
      return '$subject 호기심 가득한 상태예요.';
    }
    return '$subject 잔잔한 하루를 보내고 있어요.';
  }

  /// 이전 분석 대비 변화 칩 데이터. delta 5% 미만은 제외.
  /// 절대값 기준 상위 최대 2개만 반환 (긍정 변화 우선).
  List<({String label, double delta, bool isUp})> _buildDeltas() {
    if (previousAnalysis == null) return const [];
    final cur = analysis.emotions;
    final prev = previousAnalysis!.emotions;
    final pairs = <(String, double)>[
      ('happiness',  cur.happiness  - prev.happiness),
      ('calm',       cur.calm       - prev.calm),
      ('excitement', cur.excitement - prev.excitement),
      ('curiosity',  cur.curiosity  - prev.curiosity),
      ('anxiety',    cur.anxiety    - prev.anxiety),
      ('fear',       cur.fear       - prev.fear),
      ('sadness',    cur.sadness    - prev.sadness),
      ('discomfort', cur.discomfort - prev.discomfort),
    ];
    final filtered = pairs.where((p) => p.$2.abs() >= 0.05).toList()
      ..sort((a, b) => b.$2.abs().compareTo(a.$2.abs()));
    final top = filtered.take(2);
    return top
        .map((p) => (
              label: AppTheme.getEmotionLabel(p.$1),
              delta: p.$2,
              isUp: p.$2 > 0,
            ))
        .toList();
  }

  Widget _buildDeltaChip(({String label, double delta, bool isUp}) d) {
    final pct = (d.delta.abs() * 100).toInt();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            d.isUp ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12.r,
            color: Colors.white,
          ),
          SizedBox(width: 4.w),
          Text(
            '${d.label} ${d.isUp ? '+' : '-'}$pct%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (petName != null && petName!.isNotEmpty)
        ? petName!
        : (analysis.petName ?? '아이');
    final dominantLabel = AppTheme.getEmotionLabel(_dominantKey());
    final scorePct = (_dominantScore() * 100).round();
    final message = _buildMessage(name);
    final deltas = _buildDeltas();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(EmotionResultTokens.radiusCard.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                dominantLabel,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '$scorePct%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 13.sp,
              height: 1.5,
            ),
          ),
          if (deltas.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: deltas.map(_buildDeltaChip).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
