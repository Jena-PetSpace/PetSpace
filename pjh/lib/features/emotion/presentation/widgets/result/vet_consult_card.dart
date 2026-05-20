import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/emotion_analysis.dart';
import '../../theme/emotion_result_tokens.dart';

/// VetConsultCard 모드 — 본문 카피가 모드별로 다르다.
/// - emotion: 스트레스 신호 컨텍스트
/// - health:  건강 신호 컨텍스트
enum VetConsultMode { emotion, health }

/// 수의사 상담 권장 카드 (조건부).
/// - 노출 조건 판정은 호출 측 책임. 위젯 자체는 표시 여부에 관여하지 않음.
///   - emotion: `VetConsultCard.shouldShow(analysis)` 헬퍼 사용
///   - health:  `analysis.riskAlert || analysis.overallScore < 70` 직접 판정
/// - 코랄 톤 (즉시 행동 키)
/// - "병원 찾기" 버튼 → KakaoMap 라우팅. 미구현시 SnackBar
///
/// `analysis`는 노출 조건 판정에만 쓰였으나 위젯 본문이 사용하지 않으므로
/// 옵셔널. health 페이지처럼 외부에서 직접 조건 판정하는 경우 생략 가능.
class VetConsultCard extends StatelessWidget {
  final EmotionAnalysis? analysis;
  final VoidCallback onFindVet;
  final VetConsultMode mode;

  const VetConsultCard({
    super.key,
    this.analysis,
    required this.onFindVet,
    this.mode = VetConsultMode.emotion,
  });

  /// emotion 페이지에서 노출 여부 판별. health 페이지는 자체 조건 사용.
  static bool shouldShow(EmotionAnalysis analysis) {
    final e = analysis.emotions;
    final negSum = e.anxiety + e.sadness + e.fear + e.discomfort;
    return e.stressLevel >= 80 || negSum >= 0.6;
  }

  /// 모드별 본문 카피.
  String get _body {
    switch (mode) {
      case VetConsultMode.emotion:
        return '지속되는 스트레스 신호가 감지됐어요.\n수의사와 상담해 보시는 게 좋아요.';
      case VetConsultMode.health:
        return '건강 신호에 변화가 보여요.\n수의사와 상담해 보시는 게 좋아요.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: EmotionResultTokens.coralLight,
        borderRadius: BorderRadius.circular(EmotionResultTokens.radiusCard.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36.r,
            height: 36.r,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: EmotionResultTokens.cardSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.medical_services_outlined,
              size: 20.r,
              color: EmotionResultTokens.coral,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      size: 12.r,
                      color: EmotionResultTokens.coral,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '수의사 상담 권장',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: EmotionResultTokens.coral,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  _body,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: EmotionResultTokens.textPrimary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: onFindVet,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: EmotionResultTokens.coral,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                '가까운 병원 찾기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
