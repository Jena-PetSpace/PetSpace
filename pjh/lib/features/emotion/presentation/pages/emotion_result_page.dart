import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/emotion_analysis.dart';
import '../bloc/emotion_analysis_bloc.dart';
import '../theme/emotion_result_tokens.dart';
import '../widgets/result/ai_insight_card.dart';
import '../widgets/result/bottom_action_bar.dart';
import '../widgets/result/breed_guide_card.dart';
import '../widgets/result/context_card.dart';
import '../widgets/result/emotion_distribution_card.dart';
import '../widgets/result/emotion_summary_card.dart';
import '../widgets/result/memo_save_modal.dart';
import '../widgets/result/next_action_card.dart';
import '../widgets/result/part_analysis_card.dart';
import '../widgets/result/photo_slider.dart';
import '../widgets/result/stress_card.dart';
import '../widgets/result/vet_consult_card.dart';

/// 감정 분석 결과 페이지 (리디자인 v2).
///
/// 구조: PhotoSlider → HeroCard → ContextCard(조건부) → AiInsight
///   → EmotionDistribution → PartAnalysis(조건부) → Stress → NextAction
///   → BreedGuide → VetConsult(조건부) → BottomActionBar.
///
/// 호출처 5곳에서 진입. fromHistory=true 인 경우 BottomActionBar의
/// 히스토리 버튼이 "닫기"로 동작하고, 신규 분석 자동 저장은 스킵.
class EmotionResultPage extends StatefulWidget {
  final EmotionAnalysis analysis;
  final List<String> imagePaths;

  /// 직전 분석. null이면 HeroCard의 delta 칩이 숨겨진다.
  /// TODO(previousAnalysis): 호출처 2곳(emotion_analysis_page, emotion_result_loader_page)에서
  /// 직전 1건을 조회해 주입하는 별도 PR 예정.
  final EmotionAnalysis? previousAnalysis;

  /// 히스토리에서 열렸을 때 true — 하단 버튼이 push 대신 pop으로 동작 + 자동 저장 스킵
  final bool fromHistory;

  const EmotionResultPage({
    super.key,
    required this.analysis,
    this.imagePaths = const [],
    this.previousAnalysis,
    this.fromHistory = false,
  });

  @override
  State<EmotionResultPage> createState() => _EmotionResultPageState();
}

class _EmotionResultPageState extends State<EmotionResultPage> {
  /// 분석 결과의 사진 경로. imagePaths가 비어 있으면 analysis.imageUrl을 사용.
  List<String> get _photoSources {
    if (widget.imagePaths.isNotEmpty) return widget.imagePaths;
    if (widget.analysis.imageUrl.isNotEmpty) return [widget.analysis.imageUrl];
    if (widget.analysis.localImagePath.isNotEmpty) {
      return [widget.analysis.localImagePath];
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    // 신규 분석 진입 시에만 자동 저장 트리거 (히스토리 진입은 스킵)
    if (!widget.fromHistory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // BLoC이 트리에 있어야만 동작 — 라우팅마다 BlocProvider가 다를 수 있어 try-catch로 감쌈
        try {
          context
              .read<EmotionAnalysisBloc>()
              .add(const SaveAnalysisRequested());
        } catch (_) {
          // BLoC이 없는 라우팅 경로 — 무시
        }
      });
    }
  }

  // ── 액션 핸들러 ─────────────────────────────────────────────

  void _onShare() {
    // TODO(action): share_plus 또는 기존 EmotionShareCard 재사용
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('공유 기능은 준비 중입니다')),
    );
  }

  Future<void> _onSave() async {
    final memo = await MemoSaveModal.show(
      context,
      initialMemo: widget.analysis.memo,
    );
    if (!mounted || memo == null) return;
    try {
      context
          .read<EmotionAnalysisBloc>()
          .add(SaveAnalysisRequested(memo: memo));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메모를 저장했어요')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장 중 오류가 발생했어요')),
      );
    }
  }

  void _onHistoryOrClose() {
    if (widget.fromHistory) {
      Navigator.of(context).pop();
      return;
    }
    // 신규 분석 진입에서 히스토리로 이동
    try {
      context.go('/emotion/history');
    } catch (_) {
      Navigator.of(context).pop();
    }
  }

  void _onReanalyze() {
    // TODO(action): 입력 페이지로 이미지·petId prefill 후 이동
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('재분석은 준비 중입니다')),
    );
  }

  void _onHealthCheck() {
    try {
      context.go('/health/analysis');
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('건강 분석 페이지로 이동할 수 없어요')),
      );
    }
  }

  void _onFindVet() {
    // TODO(action): KakaoMap 동물병원 검색 라우팅
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('병원 찾기는 준비 중입니다')),
    );
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
        '감정 분석 결과',
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: EmotionResultTokens.textPrimary,
        ),
      ),
      centerTitle: true,
      actions: const [
        // TODO(streak): user_points 테이블 연동 — 현재는 placeholder 미표시
        SizedBox.shrink(),
      ],
    );
  }

  /// 가로 패딩 + 카드 사이 간격 helper
  Widget _section(Widget child) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: EmotionResultTokens.pageHorizontalPadding.w,
      ),
      child: child,
    );
  }

  Widget _gap() => SizedBox(height: EmotionResultTokens.cardGap.h);

  @override
  Widget build(BuildContext context) {
    final analysis = widget.analysis;
    final showContext =
        analysis.contextNote != null && analysis.contextNote!.trim().isNotEmpty;
    final showPart = analysis.emotions.facialFeatures != null &&
        analysis.emotions.facialFeatures!.isNotEmpty;
    final showVet = VetConsultCard.shouldShow(analysis);

    return Scaffold(
      backgroundColor: EmotionResultTokens.background,
      appBar: _buildAppBar(),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 80.h),
        child: Column(
          children: [
            PhotoSlider(imagePaths: _photoSources),
            SizedBox(height: 12.h),
            _section(EmotionSummaryCard(
              analysis: analysis,
              previousAnalysis: widget.previousAnalysis,
              petName: analysis.petName,
            )),
            if (showContext) ...[
              _gap(),
              _section(ContextCard(contextNote: analysis.contextNote!.trim())),
            ],
            _gap(),
            _section(AiInsightCard(analysis: analysis)),
            _gap(),
            _section(EmotionDistributionCard(scores: analysis.emotions)),
            if (showPart) ...[
              _gap(),
              _section(PartAnalysisCard(
                features: analysis.emotions.facialFeatures!,
              )),
            ],
            _gap(),
            _section(StressCard(score: analysis.emotions.stressLevel)),
            _gap(),
            _section(NextActionCard(
              analysis: analysis,
              onReanalyze: _onReanalyze,
              onHealthCheck: _onHealthCheck,
              onMemo: _onSave,
            )),
            _gap(),
            // TODO(breed): pets 테이블에서 breed/ageMonths 조회 후 주입 — 별도 PR
            _section(const BreedGuideCard()),
            if (showVet) ...[
              _gap(),
              _section(VetConsultCard(
                analysis: analysis,
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
