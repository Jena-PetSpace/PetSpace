import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theme/emotion_result_tokens.dart';

/// 품종·연령 가이드 카드.
/// - 네이비 톤 (정보·안내 키)
/// - breed/ageMonths가 있으면 매핑된 가이드, 없으면 일반 fallback
/// - 실제 품종-연령 매핑 데이터(assets/data/breed_age_guides.json)는 미구현 → fallback 우선
class BreedGuideCard extends StatelessWidget {
  final String? breed;
  final int? ageMonths;

  const BreedGuideCard({
    super.key,
    this.breed,
    this.ageMonths,
  });

  /// 연령 단계 fallback. 6개월 미만=사회화기, 18개월 미만=청년기, 그 외=성견기.
  String _ageStage() {
    final m = ageMonths;
    if (m == null) return '';
    if (m < 6) return '사회화 시기';
    if (m < 18) return '청년기';
    if (m < 96) return '성견기';
    return '노령기';
  }

  String _bodyText() {
    final hasBreed = breed != null && breed!.trim().isNotEmpty;
    final stage = _ageStage();
    // TODO(copy): BreedGuideCard 본문 — 정현님 카피라이팅 확정 후 교체
    if (hasBreed && stage.isNotEmpty) {
      return '$breed $stage 특성: 환경 변화에 민감할 수 있어요.\n새로운 사람·소리에 천천히 노출해주세요.';
    }
    if (hasBreed) {
      return '$breed 특성: 품종 평균 데이터는 곧 추가됩니다.';
    }
    if (stage.isNotEmpty) {
      return '$stage: 일관된 일과와 충분한 수면이 안정에 도움이 돼요.';
    }
    return '품종·나이를 등록하면 더 정확한 가이드를 받을 수 있어요.';
  }

  Widget _buildLabel() {
    final hasBreed = breed != null && breed!.trim().isNotEmpty;
    return Text(
      // TODO(copy): BreedGuideCard 상단 라벨
      hasBreed ? '$breed · 가이드' : '일반 가이드',
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w500,
        color: EmotionResultTokens.navy,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.r,
            height: 36.r,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: EmotionResultTokens.navyLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pets,
              size: 20.r,
              color: EmotionResultTokens.navy,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel(),
                SizedBox(height: 4.h),
                Text(
                  _bodyText(),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: EmotionResultTokens.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
