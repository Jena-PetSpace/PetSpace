import 'dart:async';

import 'package:flutter/material.dart';

import 'data/pet_facts.dart';
import 'paw_trail.dart';

// TODO(refactor): emotion·health 양쪽에서 사용 — 향후 features/_shared/ 또는
// shared/widgets/로 이동 검토. (스펙 v1.0 적용 시 emotion 디렉토리에 임시 배치.)

/// AI 분석 로딩 화면 — 스펙 v1.0 §1~10.
///
/// ## 진행바 동작
/// 외부에서 분석 결과 도착 시 [analysisCompleted]를 true로 갱신해야 한다.
/// 단일 [AnimationController]가 0→1 사이를 흐른다:
///
/// - **`analysisCompleted=false`**: [estimatedDuration] 동안 0→0.99로 진행,
///   0.99에서 멈춰 응답 대기.
/// - **`analysisCompleted=true`**: 현재 위치에서 1.0까지 가속 구간 진행
///   (남은 거리에 비례, 200~800ms).
///
/// 1.0 도달 시점에 [onProgressComplete]가 정확히 한 번 호출된다.
class AiAnalysisLoadingWidget extends StatefulWidget {
  /// 일러스트 PNG asset 경로.
  final String illustrationAssetPath;

  /// 0→0.99 진행에 걸리는 시간.
  final Duration estimatedDuration;

  /// 외부 분석이 완료되었는지.
  final bool analysisCompleted;

  /// 진행바가 1.0에 도달했을 때 호출 (정확히 1회).
  final VoidCallback? onProgressComplete;

  const AiAnalysisLoadingWidget({
    super.key,
    this.illustrationAssetPath = LoadingScreenConfig.defaultIllustrationAsset,
    this.estimatedDuration = LoadingScreenConfig.estimatedAnalysisDuration,
    this.analysisCompleted = false,
    this.onProgressComplete,
  });

  @override
  State<AiAnalysisLoadingWidget> createState() =>
      _AiAnalysisLoadingWidgetState();
}

class _AiAnalysisLoadingWidgetState extends State<AiAnalysisLoadingWidget>
    with TickerProviderStateMixin {
  late final AnimationController _progressController;
  Timer? _factTimer;
  Timer? _stageTimer;
  bool _completionFired = false;

  int _factIndex = 0;
  int _stageIndex = 0;

  static const _stages = <String>[
    '이미지 인식 중',
    '특징 추출 중',
    '결과 분석 중',
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: widget.estimatedDuration,
    );
    _progressController.addStatusListener(_onStatus);

    // 0 → 0.99까지 estimatedDuration 동안 선형 진행.
    _progressController.animateTo(
      LoadingScreenConfig.progressStallFraction,
      duration: widget.estimatedDuration,
      curve: Curves.linear,
    );

    _factTimer = Timer.periodic(LoadingScreenConfig.factRotation, (_) {
      if (!mounted) return;
      setState(() {
        _factIndex = (_factIndex + 1) % kPlaceholderFacts.length;
      });
    });

    _stageTimer = Timer.periodic(LoadingScreenConfig.stageRotation, (_) {
      if (!mounted) return;
      setState(() {
        _stageIndex = (_stageIndex + 1) % _stages.length;
      });
    });

    if (widget.analysisCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _accelerateToCompletion();
      });
    }
  }

  @override
  void didUpdateWidget(covariant AiAnalysisLoadingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.analysisCompleted && widget.analysisCompleted) {
      _accelerateToCompletion();
    }
  }

  void _accelerateToCompletion() {
    if (_completionFired) return;

    final currentValue = _progressController.value;
    final remaining = 1.0 - currentValue;
    if (remaining <= 0.0001) {
      _fireCompletion();
      return;
    }

    final accelMs = (remaining * LoadingScreenConfig.completionAccelMs)
        .round()
        .clamp(
          LoadingScreenConfig.completionAccelMinMs,
          LoadingScreenConfig.completionAccelMs,
        );

    _progressController.animateTo(
      1.0,
      duration: Duration(milliseconds: accelMs),
      curve: Curves.easeOut,
    );
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _completionFired) return;
    // 0.99 도달 → 분석이 이미 완료됐다면 1.0으로 가속, 아니면 대기.
    if (_progressController.value >= 1.0 - 0.0001) {
      _fireCompletion();
    } else if (widget.analysisCompleted) {
      _accelerateToCompletion();
    }
    // 그 외(stall): 0.99에서 대기. didUpdateWidget이 트리거할 것.
  }

  void _fireCompletion() {
    if (_completionFired) return;
    _completionFired = true;
    widget.onProgressComplete?.call();
  }

  @override
  void dispose() {
    _factTimer?.cancel();
    _stageTimer?.cancel();
    _progressController.removeStatusListener(_onStatus);
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LoadingScreenColors.background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final hPad = w * (LoadingScreenConfig.horizontalPaddingPct / 100.0);
            final illustSize =
                w * (LoadingScreenConfig.illustrationWidthPct / 100.0);
            final illustTop =
                h * (LoadingScreenConfig.illustrationTopPct / 100.0);
            final illustLeft = (w - illustSize) / 2.0;
            final infoBottom = h * (LoadingScreenConfig.infoBottomPct / 100.0);
            final progressBottom =
                h * (LoadingScreenConfig.progressBottomPct / 100.0);
            final innerWidth = w - hPad * 2;

            return Stack(
              children: [
                const Positioned.fill(child: PawTrail()),
                Positioned(
                  left: illustLeft,
                  top: illustTop,
                  width: illustSize,
                  height: illustSize,
                  child: Image.asset(
                    widget.illustrationAssetPath,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  left: hPad,
                  right: hPad,
                  bottom: infoBottom,
                  child: _buildInfoCard(),
                ),
                Positioned(
                  left: hPad,
                  bottom: progressBottom,
                  width: innerWidth,
                  child: _buildProgressSection(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final fact = kPlaceholderFacts[_factIndex];
    return AnimatedSwitcher(
      duration: LoadingScreenConfig.fadeTransition,
      child: Column(
        key: ValueKey<int>(_factIndex),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: LoadingScreenColors.tagBackground,
              borderRadius: BorderRadius.circular(999.0),
            ),
            child: Text(
              fact.category,
              style: const TextStyle(
                fontSize: 11.0,
                fontWeight: FontWeight.w500,
                color: LoadingScreenColors.labelBlue,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            fact.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              color: LoadingScreenColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return AnimatedBuilder(
      animation: _progressController,
      builder: (_, __) {
        final progress = _progressController.value.clamp(0.0, 1.0);
        final pct = (progress * 100).round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStageLabel(),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w500,
                    color: LoadingScreenColors.textSecondary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6.0),
            ClipRRect(
              borderRadius: BorderRadius.circular(999.0),
              child: SizedBox(
                height: 5.0,
                child: Stack(
                  children: [
                    const ColoredBox(
                      color: LoadingScreenColors.barBackground,
                      child: SizedBox.expand(),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: const ColoredBox(
                        color: LoadingScreenColors.primaryBlue,
                        child: SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStageLabel() {
    return AnimatedSwitcher(
      duration: LoadingScreenConfig.stageFadeTransition,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: Text(
        _stages[_stageIndex],
        key: ValueKey<int>(_stageIndex),
        style: const TextStyle(
          fontSize: 10.0,
          fontWeight: FontWeight.w500,
          color: LoadingScreenColors.labelBlue,
        ),
      ),
    );
  }
}

class LoadingScreenColors {
  const LoadingScreenColors._();
  static const Color background = Color(0xFFBFE0F4);
  static const Color primaryBlue = Color(0xFF378ADD);
  static const Color labelBlue = Color(0xFF185FA5);
  static const Color textPrimary = Color(0xB8000000);
  static const Color textSecondary = Color(0x8C000000);
  static const Color tagBackground = Color(0xB3FFFFFF);
  static const Color barBackground = Color(0x99FFFFFF);
  static const Color paw = Color(0xFFFFFFFF);
  static const Color cheekPink = Color(0xFFF4C0D1);
}

class LoadingScreenConfig {
  const LoadingScreenConfig._();

  static const String defaultIllustrationAsset =
      'assets/images/illust_dog_cat_pair.png';

  static const Duration cycle = Duration(milliseconds: 4800);
  static const double staggerSeconds = 0.4;
  static const Duration factRotation = Duration(milliseconds: 3500);
  static const Duration stageRotation = Duration(milliseconds: 5000);
  static const Duration fadeTransition = Duration(milliseconds: 350);
  static const Duration stageFadeTransition = Duration(milliseconds: 400);

  /// AI 분석 평균 응답 시간 추정치. 진행바가 0→0.99까지 차오르는 시간.
  static const Duration estimatedAnalysisDuration = Duration(seconds: 15);

  /// 분석 완료 신호 전 진행바가 멈추는 지점.
  static const double progressStallFraction = 0.99;

  /// 분석 완료 신호 후 1.0까지 가속 구간 최대 시간 (ms).
  static const int completionAccelMs = 800;

  /// 완료 가속 구간 최소 시간.
  static const int completionAccelMinMs = 200;

  static const double illustrationTopPct = 29.0;
  static const double illustrationWidthPct = 90.0;
  static const double infoBottomPct = 18.0;
  static const double progressBottomPct = 5.0;
  static const double horizontalPaddingPct = 9.0;
}
