import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../../config/injection_container.dart';
import '../../data/models/health_analysis_model.dart';
import '../../domain/entities/health_analysis.dart' show HealthArea;
import '../../domain/repositories/emotion_repository.dart';
import '../theme/emotion_result_tokens.dart';
import '../widgets/result/ai_insight_card.dart';
import '../widgets/result/bottom_action_bar.dart';
import '../widgets/result/breed_guide_card.dart';
import '../widgets/result/context_card.dart';
import '../widgets/result/diagnosis_findings_card.dart';
import '../widgets/result/emotion_share_card.dart';
import '../widgets/result/health_disclaimer_card.dart';
import '../widgets/result/health_findings_card.dart';
import '../widgets/result/health_next_action_card.dart';
import '../widgets/result/health_score_card.dart';
import '../widgets/result/memo_save_modal.dart';
import '../widgets/result/photo_slider.dart';
import '../widgets/result/vet_consult_card.dart';

/// 건강 분석 결과 페이지 (리디자인 v1).
///
/// 감정 페이지 v2와 동일한 베이지 톤 + ScreenUtil + Material outlined 아이콘.
/// 건강 페이지만의 차별점: 도넛 게이지, severity 기반 그린/앰버/레드 분기, AI 안내.
///
/// 호출처 3곳:
/// - `app_router.dart` `/health/result` (extra=HealthAnalysisModel)
/// - `ai_history_page.dart` (히스토리 진입, fromHistory=true)
/// - `emotion_analysis_page.dart` (분석 직후 push)
class HealthResultPage extends StatefulWidget {
  final HealthAnalysisModel result;

  /// 히스토리에서 열렸을 때 true — 자동 저장 스킵 + 하단 버튼이 "닫기"로 동작.
  final bool fromHistory;

  const HealthResultPage({
    super.key,
    required this.result,
    this.fromHistory = false,
  });

  @override
  State<HealthResultPage> createState() => _HealthResultPageState();
}

class _HealthResultPageState extends State<HealthResultPage> {
  @override
  void initState() {
    super.initState();
    if (!widget.fromHistory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _saveResult();
      });
    }
  }

  /// 분석 결과를 Supabase에 저장. 히스토리 진입에서는 호출하지 않음.
  Future<void> _saveResult() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;
    try {
      await sl<EmotionRepository>().saveHealthAnalysis(
        userId: userId,
        imagePathsOrUrls: widget.result.imageUrls,
        resultJson: widget.result.toSupabaseJson(),
      );
    } catch (e) {
      log('[HealthResult] 저장 실패: $e', name: 'HealthResultPage');
    }
  }

  // ── 액션 핸들러 ─────────────────────────────────────────────

  Future<void> _onShare() async {
    try {
      await HealthShareHelper.shareAsCard(
        context,
        analysis: widget.result,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공유 중 오류가 발생했어요: $e')),
      );
    }
  }

  Future<void> _onSave() async {
    final memo = await MemoSaveModal.show(context);
    if (!mounted || memo == null) return;
    // 건강 분석은 메모를 별도 컬럼이 아니라 분석 결과 JSON 안에 저장하지 않음 (현재 스키마).
    // 임시: SnackBar로 안내만. v1.1에서 health_history.memo 컬럼 추가 후 연결.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('메모는 다음 업데이트에서 저장됩니다')),
    );
  }

  void _onHistoryOrClose() {
    if (widget.fromHistory) {
      Navigator.of(context).pop();
      return;
    }
    try {
      context.push('/ai-history-page');
    } catch (_) {
      Navigator.of(context).pop();
    }
  }

  void _onEmotionAnalysis() {
    try {
      context.push('/emotion?tab=emotion');
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('감정 분석 페이지로 이동할 수 없어요')),
      );
    }
  }

  /// "다른 부위도 분석하기" — AI 분석 페이지 건강 탭으로 이동.
  /// area prefill은 v1.1 (현재 area를 제외하고 시작하려면 입력 페이지가 받아야 함).
  void _onOtherArea() {
    try {
      context.push('/emotion?tab=health');
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('분석 페이지로 이동할 수 없어요')),
      );
    }
  }

  void _onFindVet() {
    try {
      context.push('/hospital');
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('병원 찾기 페이지로 이동할 수 없어요')),
      );
    }
  }

  // ── UI ─────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: EmotionResultTokens.background,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        color: EmotionResultTokens.textPrimary,
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        '건강 분석 결과',
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: EmotionResultTokens.textPrimary,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _section(Widget child) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: EmotionResultTokens.pageHorizontalPadding.w,
      ),
      child: child,
    );
  }

  Widget _gap() => SizedBox(height: EmotionResultTokens.cardGap.h);

  /// AiInsightCard.health에 줄 기본 행동 라인.
  /// recommendations[0]을 우선 사용. 없으면 점수 기반 fallback.
  String _resolveActionText() {
    final recs = widget.result.recommendations;
    if (recs.isNotEmpty) return recs.first;
    final score = widget.result.overallScore;
    if (score >= 90) return '지금 컨디션을 그대로 유지해 주세요.';
    if (score >= 70) return '아래 발견 사항을 한 번 확인해 주세요.';
    return '수의사와 상담해보시는 게 좋아요.';
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.result;
    final showContext = analysis.additionalContext != null &&
        analysis.additionalContext!.trim().isNotEmpty;
    final showInsight = analysis.summary.trim().isNotEmpty ||
        analysis.recommendations.isNotEmpty;
    final showFindings = analysis.findings.isNotEmpty;
    final showVet = analysis.riskAlert || analysis.overallScore < 70;

    return Scaffold(
      backgroundColor: EmotionResultTokens.background,
      appBar: _buildAppBar(),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 80.h),
        child: Column(
          children: [
            PhotoSlider(imagePaths: analysis.imageUrls),
            SizedBox(height: 12.h),
            _section(HealthScoreCard(analysis: analysis)),
            if (showContext) ...[
              _gap(),
              _section(ContextCard(
                contextNote: analysis.additionalContext!.trim(),
              )),
            ],
            if (showInsight) ...[
              _gap(),
              _section(AiInsightCard.health(
                basisText: analysis.summary.trim().isNotEmpty
                    ? analysis.summary.trim()
                    : null,
                actionText: _resolveActionText(),
              )),
            ],
            if (showFindings) ...[
              _gap(),
              _section(HealthFindingsCard(
                area: analysis.area,
                findings: analysis.findings,
              )),
              _gap(),
              _section(DiagnosisFindingsCard(findings: analysis.findings)),
            ],
            _gap(),
            _section(HealthNextActionCard(
              onEmotionAnalysis: _onEmotionAnalysis,
              onOtherArea: _onOtherArea,
              onMemo: _onSave,
              // 종합(overall) 분석한 경우엔 "다른 부위" 슬롯 hide.
              showOtherArea: analysis.area != HealthArea.overall,
            )),
            _gap(),
            // TODO(breed): pets 테이블에서 breed/ageMonths 조회 후 주입 — 별도 PR
            _section(const BreedGuideCard()),
            _gap(),
            _section(const HealthDisclaimerCard()),
            if (showVet) ...[
              _gap(),
              _section(VetConsultCard(
                mode: VetConsultMode.health,
                onFindVet: _onFindVet,
              )),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        onShare: _onShare,
        onSave: _onSave,
        onHistory: _onHistoryOrClose,
        fromHistory: widget.fromHistory,
      ),
    );
  }
}
