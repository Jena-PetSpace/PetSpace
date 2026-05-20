import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/health_analysis.dart';
import '../../theme/emotion_result_tokens.dart';

/// 진단 소견 카드.
/// - 헤더: 클립보드 아이콘 + "진단 소견"
/// - 본문: 각 finding을 `[항목명] 상세 설명` 형태로 표시
///   - `[항목명]`은 네이비 강조 (w500)
///   - 상세는 textPrimary
///   - severity별 좌측 색 점으로 시각 구분
class DiagnosisFindingsCard extends StatelessWidget {
  final List<HealthFinding> findings;

  const DiagnosisFindingsCard({super.key, required this.findings});

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.assignment_outlined,
          size: 18.r,
          color: EmotionResultTokens.navy,
        ),
        SizedBox(width: 6.w),
        Text(
          '진단 소견',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: EmotionResultTokens.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildFindingItem(HealthFinding f) {
    final dotColor = EmotionResultTokens.severityColor(f.severity);
    final hasItem = f.item.trim().isNotEmpty;
    final hasDetail = f.detail.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // severity 점
          Container(
            margin: EdgeInsets.only(top: 6.h, right: 8.w),
            width: 8.r,
            height: 8.r,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12.sp,
                  height: 1.6,
                  color: EmotionResultTokens.textPrimary,
                ),
                children: [
                  if (hasItem)
                    TextSpan(
                      text: '[${f.item}] ',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: EmotionResultTokens.navy,
                      ),
                    ),
                  TextSpan(
                    text: hasDetail
                        ? f.detail
                        : (hasItem ? '상세 소견 없음' : '소견 없음'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) return const SizedBox.shrink();

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
          SizedBox(height: 4.h),
          for (final f in findings) _buildFindingItem(f),
        ],
      ),
    );
  }
}
