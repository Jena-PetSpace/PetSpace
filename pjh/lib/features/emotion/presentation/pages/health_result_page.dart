import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
import '../../../../shared/themes/app_theme.dart';
import '../../data/models/health_analysis_model.dart';
import '../../domain/entities/health_analysis.dart';

class HealthResultPage extends StatefulWidget {
  final HealthAnalysisModel result;
  const HealthResultPage({super.key, required this.result});

  @override
  State<HealthResultPage> createState() => _HealthResultPageState();
}

class _HealthResultPageState extends State<HealthResultPage> {

  @override
  void initState() {
    super.initState();
    _saveResult();
  }

  Future<void> _saveResult() async {
    try {
      await Supabase.instance.client
          .from('health_history')
          .insert(widget.result.toSupabaseJson());
    } catch (e) {
      log('건강분석 저장 실패: $e', name: 'HealthResultPage');
    }
  }

  Color get _statusColor {
    switch (widget.result.status) {
      case '양호':  return AppTheme.successColor;
      case '주의':  return const Color(0xFFEF9F27);
      case '위험':  return AppTheme.errorColor;
      default:     return AppTheme.secondaryTextColor;
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'warning': return AppTheme.errorColor;
      case 'caution': return const Color(0xFFEF9F27);
      default:        return AppTheme.successColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(children: [
        // ── 딥블루 히어로 헤더 ──────────────────────────────────
        Container(
          color: AppTheme.primaryColor,
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              // 앱바 영역
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      '${r.area.displayName} 건강 분석 결과',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 48.w),
                ]),
              ),
              // 분석 이미지 썸네일
              if (r.imageUrls.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: r.imageUrls.take(3).map((url) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 4.w),
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.white30, width: 1),
                      ),
                      child: ClipOval(
                        child: Image.file(
                          File(url),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.pets, size: 20.w, color: Colors.white54),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              // 종합 점수 + 상태 배지
              Padding(
                padding: EdgeInsets.only(bottom: 20.h),
                child: Column(children: [
                  Text(
                    '${r.overallScore}',
                    style: TextStyle(
                      fontSize: 56.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: _statusColor.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      r.status,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    r.petName != null
                        ? '${r.petName} · ${r.area.displayName}'
                        : r.area.displayName,
                    style: TextStyle(fontSize: 10.sp, color: Colors.white54),
                  ),
                ]),
              ),
            ]),
          ),
        ),

        // ── 스크롤 본문 ─────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(14.w),
            child: Column(children: [
              // risk_alert 배너
              if (r.riskAlert) ...[
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 10.h),
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppTheme.highlightColor,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 20.w),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '수의사 상담을 권장합니다',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (r.riskReason != null)
                            Text(
                              r.riskReason!,
                              style: TextStyle(
                                  fontSize: 10.sp, color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/hospital'),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 9.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          '병원찾기',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.highlightColor,
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ],

              // 요약
              if (r.summary.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 10.h),
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Text(
                    r.summary,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.primaryTextColor,
                      height: 1.5,
                    ),
                  ),
                ),
              ],

              // 분석별 소견
              if (r.findings.isNotEmpty) ...[
                _sectionTitle('분석별 소견'),
                ...r.findings.map((f) => _findingCard(f)),
                SizedBox(height: 6.h),
              ],

              // 권장사항
              if (r.recommendations.isNotEmpty) ...[
                _sectionTitle('일상 권장사항'),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Column(
                    children: r.recommendations.asMap().entries.map((e) =>
                      Padding(
                        padding: EdgeInsets.only(
                            bottom: e.key < r.recommendations.length - 1
                                ? 8.h : 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20.w,
                              height: 20.w,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${e.key + 1}',
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                e.value,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  height: 1.4,
                                  color: AppTheme.primaryTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).toList(),
                  ),
                ),
                SizedBox(height: 10.h),
              ],

              // 면책 문구
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: AppTheme.subtleBackground,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 14.w, color: AppTheme.secondaryTextColor),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        'AI 참고용 분석입니다. 정확한 진단과 치료는 반드시 수의사에게 받으세요.',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AppTheme.secondaryTextColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 80.h),
            ]),
          ),
        ),
      ]),

      // ── 하단바 ───────────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 24.h),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(children: [
          // 시스템 공유
          SizedBox(
            width: 44.w,
            height: 44.w,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Icon(Icons.share_outlined,
                  size: 18.w, color: Colors.grey[700]),
            ),
          ),
          SizedBox(width: 8.w),
          // 피드 공유
          SizedBox(
            width: 44.w,
            height: 44.w,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r)),
                side: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.5)),
              ),
              child: Icon(Icons.dynamic_feed_outlined,
                  size: 18.w, color: AppTheme.primaryColor),
            ),
          ),
          SizedBox(width: 8.w),
          // 저장 완료
          Expanded(
            child: SizedBox(
              height: 44.w,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                  elevation: 0,
                ),
                icon: Icon(Icons.check_circle_outline, size: 16.w),
                label: Text(
                  '저장 완료',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
    padding: EdgeInsets.only(bottom: 8.h),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        t,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryTextColor,
        ),
      ),
    ),
  );

  Widget _findingCard(HealthFinding f) {
    final c = _severityColor(f.severity);
    return Container(
      margin: EdgeInsets.only(bottom: 7.h),
      padding: EdgeInsets.all(11.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border(left: BorderSide(color: c, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                f.item,
                style: TextStyle(
                  fontSize: 12.sp, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7.r),
              ),
              child: Text(
                f.result,
                style: TextStyle(
                  fontSize: 9.sp, color: c, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          if (f.detail.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              f.detail,
              style: TextStyle(
                fontSize: 11.sp,
                color: AppTheme.secondaryTextColor,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
