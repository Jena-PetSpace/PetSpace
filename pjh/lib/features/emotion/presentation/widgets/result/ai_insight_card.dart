import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/emotion_analysis.dart';
import '../../theme/emotion_result_tokens.dart';

/// AI가 본 신호 카드.
/// 3개 블록:
///   1) 헤더 (sparkles + "AI가 본 신호")
///   2) 분석 근거 (네이비 톤 인용 박스, facialFeatures에서 상위 신호 조합)
///   3) 행동 한 줄 (코랄 톤 박스, 다음에 할 행동)
class AiInsightCard extends StatelessWidget {
  final EmotionAnalysis analysis;

  const AiInsightCard({super.key, required this.analysis});

  /// 부위별 분석 중 비어있지 않은 항목을 최대 3개 골라 자연어로 합성.
  /// 형식: "{부위A의 state}고, {부위B의 state}이며, {부위C의 state}."
  String? _buildBasisSentence() {
    final features = analysis.emotions.facialFeatures;
    if (features == null || features.isEmpty) return null;

    final states = features.values
        .map((f) => f.state.trim())
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();
    if (states.isEmpty) return null;

    if (states.length == 1) return '${states[0]}.';
    if (states.length == 2) return '${states[0]}, ${states[1]}.';
    return '${states[0]}, ${states[1]}, ${states[2]}.';
  }

  /// 주감정/스트레스 기반 행동 한 줄.
  /// TODO(copy): 5가지 분기 멘트
  String _buildActionLine() {
    final e = analysis.emotions;
    final stress = e.stressLevel;
    final negSum = e.anxiety + e.sadness + e.fear;
    final posSum = e.happiness + e.calm;

    if (stress >= 80 || negSum > 0.5) {
      // TODO(copy): 고스트레스/부정 행동 권장
      return '조용한 공간에서 잠시 쉬게 해주세요.';
    }
    if (posSum > 0.6) {
      // TODO(copy): 긍정 행동 권장
      return '이 상태를 유지할 수 있는 짧은 산책이 좋아요.';
    }
    if (e.excitement > 0.5) {
      // TODO(copy): 흥분 행동 권장
      return '에너지 발산을 도울 가벼운 놀이가 적당해요.';
    }
    if (e.curiosity > 0.5) {
      // TODO(copy): 호기심 행동 권장
      return '새로운 장난감이나 냄새 자극을 시도해보세요.';
    }
    // TODO(copy): 평온 행동 권장
    return '평소처럼 차분히 곁에 있어주세요.';
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.auto_awesome_outlined,
          size: 18.r,
          color: EmotionResultTokens.navy,
        ),
        SizedBox(width: 6.w),
        Text(
          // TODO(copy): AiInsightCard 헤더
          'AI가 본 신호',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: EmotionResultTokens.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildBasisBox(String basis) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: EmotionResultTokens.navyLight,
        border: Border(
          left: BorderSide(
            color: EmotionResultTokens.navy,
            width: 3.w,
          ),
        ),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8.r),
          bottomRight: Radius.circular(8.r),
        ),
      ),
      child: Text(
        basis,
        style: TextStyle(
          fontSize: 12.sp,
          height: 1.6,
          color: EmotionResultTokens.textPrimary,
        ),
      ),
    );
  }

  Widget _buildActionBox(String action) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: EmotionResultTokens.coralLight,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 16.r,
            color: EmotionResultTokens.coral,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              action,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: EmotionResultTokens.coralDark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final basis = _buildBasisSentence();
    final action = _buildActionLine();

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
          if (basis != null) ...[
            SizedBox(height: 10.h),
            _buildBasisBox(basis),
          ],
          SizedBox(height: 10.h),
          _buildActionBox(action),
        ],
      ),
    );
  }
}
