import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/emotion_analysis.dart';
import '../../theme/emotion_result_tokens.dart';

/// AiInsightCard 모드.
/// - emotion: 기본. analysis를 받아 내부에서 텍스트 생성. 행동 박스가 코랄.
/// - health:  외부에서 basisText/actionText 주입. 행동 박스가 그린.
enum AiInsightMode { emotion, health }

/// AI가 본 신호 카드.
/// 3개 블록:
///   1) 헤더 (sparkles + "AI가 본 신호")
///   2) 분석 근거 (네이비 톤 인용 박스, facialFeatures에서 상위 신호 조합)
///   3) 행동 한 줄 (모드별 톤 박스, 다음에 할 행동)
///
/// 기존 emotion 호출처(`AiInsightCard(analysis: ...)`)는 변경 없이 동작.
/// health 호출처는 `AiInsightCard.health(basisText: ..., actionText: ...)` 사용.
class AiInsightCard extends StatelessWidget {
  final AiInsightMode mode;
  final EmotionAnalysis? analysis;
  final String? basisText;
  final String? actionText;

  const AiInsightCard({
    super.key,
    required EmotionAnalysis this.analysis,
  })  : mode = AiInsightMode.emotion,
        basisText = null,
        actionText = null;

  /// 건강 페이지용 생성자. summary를 분석 근거로, recommendations[0]을 행동으로.
  const AiInsightCard.health({
    super.key,
    this.basisText,
    required String this.actionText,
  })  : mode = AiInsightMode.health,
        analysis = null;

  /// 부위별 분석 중 비어있지 않은 항목을 최대 3개 골라 자연어로 합성.
  /// (emotion 모드 전용)
  String? _buildBasisSentence() {
    final features = analysis?.emotions.facialFeatures;
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

  /// 주감정/스트레스 기반 행동 한 줄. (emotion 모드 전용)
  String _buildActionLine() {
    final e = analysis!.emotions;
    final stress = e.stressLevel;
    final negSum = e.anxiety + e.sadness + e.fear;
    final posSum = e.happiness + e.calm;

    if (stress >= 80 || negSum > 0.5) {
      return '조용한 공간에서 잠시 쉬게 해주세요.';
    }
    if (posSum > 0.6) {
      return '가벼운 산책으로 이 컨디션을 이어가요.';
    }
    if (e.excitement > 0.5) {
      return '짧은 놀이로 에너지를 풀어주세요.';
    }
    if (e.curiosity > 0.5) {
      return '새로운 장난감이나 향기로 호기심을 채워주세요.';
    }
    return '평소처럼 곁에서 함께해주세요.';
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
    // 모드별 톤 분기 — emotion=코랄, health=그린.
    final isHealth = mode == AiInsightMode.health;
    final bg = isHealth
        ? EmotionResultTokens.greenLight
        : EmotionResultTokens.coralLight;
    final iconColor = isHealth
        ? EmotionResultTokens.green
        : EmotionResultTokens.coral;
    final textColor = isHealth
        ? EmotionResultTokens.greenDark
        : EmotionResultTokens.coralDark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 16.r,
            color: iconColor,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              action,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: textColor,
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
    final String? basis = mode == AiInsightMode.health
        ? (basisText != null && basisText!.trim().isNotEmpty ? basisText : null)
        : _buildBasisSentence();
    final String action = mode == AiInsightMode.health
        ? (actionText ?? '')
        : _buildActionLine();

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
          if (action.isNotEmpty) ...[
            SizedBox(height: 10.h),
            _buildActionBox(action),
          ],
        ],
      ),
    );
  }
}
