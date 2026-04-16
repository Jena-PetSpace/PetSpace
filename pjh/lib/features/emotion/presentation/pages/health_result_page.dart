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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _saveResult();
  }

  Future<void> _saveResult() async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client
          .from('health_history')
          .insert(widget.result.toSupabaseJson());
    } catch (e) {
      log('건강분석 저장 실패: $e', name: 'HealthResultPage');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color get _statusColor {
    switch (widget.result.status) {
      case '양호':
        return AppTheme.successColor;
      case '주의':
        return Colors.orange;
      case '위험':
        return AppTheme.errorColor;
      default:
        return AppTheme.secondaryTextColor;
    }
  }

  Color get _scoreColor {
    final s = widget.result.overallScore;
    if (s >= 80) return AppTheme.successColor;
    if (s >= 60) return Colors.orange;
    return AppTheme.errorColor;
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'warning':
        return AppTheme.errorColor;
      case 'caution':
        return Colors.orange;
      default:
        return AppTheme.successColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${r.area.displayName} 분석 결과',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_saving)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
              child: SizedBox(
                width: 18.w,
                height: 18.w,
                child: const CircularProgressIndicator(
                  color: Colors.white54,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 위험 알림 배너 — sticky (스크롤 밖)
          if (r.riskAlert)
            Container(
              width: double.infinity,
              color: AppTheme.errorColor,
              padding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 18.w),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      r.riskReason ?? '즉시 수의사 상담이 필요한 소견이 발견되었습니다.',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // 스크롤 가능한 본문
          Expanded(
            child: SingleChildScrollView(
              padding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 종합 점수 카드
                  _ScoreCard(
                    score: r.overallScore,
                    status: r.status,
                    statusColor: _statusColor,
                    scoreColor: _scoreColor,
                    confidence: r.confidence,
                    summary: r.summary,
                    petName: r.petName,
                    area: r.area,
                  ),
                  SizedBox(height: 16.h),

                  // 검사 항목
                  if (r.findings.isNotEmpty) ...[
                    const _SectionTitle(title: '검사 항목'),
                    SizedBox(height: 8.h),
                    ...r.findings.map((f) => _FindingCard(
                          finding: f,
                          severityColor: _severityColor(f.severity),
                        )),
                    SizedBox(height: 16.h),
                  ],

                  // 권장 사항
                  if (r.recommendations.isNotEmpty) ...[
                    const _SectionTitle(title: '권장 사항'),
                    SizedBox(height: 8.h),
                    _RecommendationsCard(items: r.recommendations),
                    SizedBox(height: 16.h),
                  ],

                  // 병원 찾기 버튼 (위험/주의 시)
                  if (r.riskAlert || r.status == '주의' || r.status == '위험')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/hospital'),
                        icon: Icon(Icons.local_hospital_outlined,
                            size: 18.w),
                        label: Text(
                          '근처 동물병원 찾기',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),

                  SizedBox(height: 24.h),
                  // 면책 고지
                  Text(
                    'AI 참고용 분석입니다. 정확한 진단은 반드시 수의사에게 받으세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppTheme.lightTextColor,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 서브 위젯들 ───────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryTextColor,
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final int score;
  final String status;
  final Color statusColor;
  final Color scoreColor;
  final double confidence;
  final String summary;
  final String? petName;
  final HealthArea area;

  const _ScoreCard({
    required this.score,
    required this.status,
    required this.statusColor,
    required this.scoreColor,
    required this.confidence,
    required this.summary,
    this.petName,
    required this.area,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 점수 + 상태
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 56.sp,
                  fontWeight: FontWeight.w800,
                  color: scoreColor,
                  height: 1,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 8.h, left: 4.w),
                child: Text(
                  '/ 100',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            padding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '신뢰도 ${(confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 11.sp,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          if (summary.isNotEmpty) ...[
            SizedBox(height: 14.h),
            Divider(height: 1, color: Colors.grey.shade200),
            SizedBox(height: 14.h),
            Text(
              summary,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.primaryTextColor,
                height: 1.5,
              ),
            ),
          ],
          if (petName != null) ...[
            SizedBox(height: 8.h),
            Text(
              petName!,
              style: TextStyle(
                fontSize: 11.sp,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  final HealthFinding finding;
  final Color severityColor;

  const _FindingCard({
    required this.finding,
    required this.severityColor,
  });

  Color get _resultTextColor {
    switch (finding.result) {
      case '이상':
        return AppTheme.errorColor;
      case '주의':
        return Colors.orange;
      case '정상':
        return AppTheme.successColor;
      default:
        return AppTheme.secondaryTextColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border(
          left: BorderSide(color: severityColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  finding.item,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                Text(
                  finding.result,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _resultTextColor,
                  ),
                ),
              ],
            ),
            if (finding.detail.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Text(
                finding.detail,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.secondaryTextColor,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecommendationsCard extends StatelessWidget {
  final List<String> items;

  const _RecommendationsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final text = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: i < items.length - 1 ? 10.h : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20.w,
                  height: 20.w,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppTheme.primaryTextColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
