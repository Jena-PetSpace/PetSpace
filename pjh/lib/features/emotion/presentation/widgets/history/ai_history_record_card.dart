import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../shared/themes/app_theme.dart';
import '../../../domain/entities/ai_history.dart';
import '../../models/ai_history_presentation.dart';

class AiHistoryRecordCard extends StatelessWidget {
  final AiHistoryRecord record;
  final String petLabel;
  final bool selectionMode;
  final VoidCallback onTap;

  const AiHistoryRecordCard({
    super.key,
    required this.record,
    required this.petLabel,
    required this.onTap,
    this.selectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEmotion = record.kind == AiHistoryKind.emotion;
    final title = isEmotion
        ? AiHistoryPresentation.emotionTitle(record.emotion!)
        : AiHistoryPresentation.healthTitle(record.health!);
    final typeLabel = isEmotion ? '감정 관찰' : '건강 확인';
    final analyzedAt = record.analyzedAt.toLocal();
    final period = analyzedAt.hour < 12 ? '오전' : '오후';
    final hour = analyzedAt.hour % 12 == 0 ? 12 : analyzedAt.hour % 12;
    final minute = analyzedAt.minute.toString().padLeft(2, '0');
    final time = '$period $hour:$minute';
    final healthState = isEmotion
        ? null
        : AiHistoryPresentation.healthStateLabel(record.health!);
    final confidence =
        isEmotion ? record.emotion!.confidence : record.health!.confidence;
    final trustLabel = _confidenceLabel(confidence);
    final semantics = [
      typeLabel,
      if (healthState != null) healthState,
      title,
      petLabel,
      time,
      trustLabel,
      '진단 결과가 아님',
      if (selectionMode) '선택 가능',
    ].join(', ');

    return Semantics(
      button: true,
      label: semantics,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                _thumbnail(isEmotion),
                SizedBox(width: 13.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: isEmotion
                                  ? AppTheme.primaryColor.withValues(
                                      alpha: 0.08,
                                    )
                                  : const Color(0xFFFFF3DD),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: isEmotion
                                    ? AppTheme.primaryColor
                                    : const Color(0xFF8B5A12),
                              ),
                            ),
                          ),
                          if (!isEmotion) ...[
                            SizedBox(width: 7.w),
                            Icon(
                              AiHistoryPresentation.healthStateIcon(
                                record.health!,
                              ),
                              size: 16.sp,
                              color: AiHistoryPresentation.healthStateColor(
                                record.health!,
                              ),
                            ),
                            SizedBox(width: 3.w),
                            Flexible(
                              child: Text(
                                AiHistoryPresentation.healthStateLabel(
                                  record.health!,
                                ),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AiHistoryPresentation.healthStateColor(
                                    record.health!,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.sp,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 7.h),
                      Text(
                        '$petLabel · $time',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        '$trustLabel · 진단 결과가 아니에요',
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 11.sp,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  selectionMode
                      ? Icons.check_circle_outline
                      : Icons.chevron_right,
                  size: 24.sp,
                  color: AppTheme.neutral400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(bool isEmotion) {
    final imageUrl = record.imageUrl;
    if (imageUrl != null && imageUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14.r),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 64.w,
          height: 64.w,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _fallback(isEmotion),
        ),
      );
    }
    return _fallback(isEmotion);
  }

  String _confidenceLabel(double confidence) {
    if (!confidence.isFinite || confidence <= 0) return '참고용 AI 결과';
    final normalized = confidence > 1 ? confidence / 100 : confidence;
    if (normalized >= 0.8) return '분석 근거 높음';
    if (normalized >= 0.55) return '분석 근거 보통';
    return '참고용 AI 결과';
  }

  Widget _fallback(bool isEmotion) {
    return Container(
      width: 64.w,
      height: 64.w,
      decoration: BoxDecoration(
        color: isEmotion
            ? AppTheme.primaryColor.withValues(alpha: 0.08)
            : const Color(0xFFFFF3DD),
        borderRadius: BorderRadius.circular(14.r),
      ),
      alignment: Alignment.center,
      child: Icon(
        isEmotion
            ? Icons.psychology_outlined
            : Icons.health_and_safety_outlined,
        size: 28.sp,
        color: isEmotion ? AppTheme.primaryColor : const Color(0xFF8B5A12),
      ),
    );
  }
}
