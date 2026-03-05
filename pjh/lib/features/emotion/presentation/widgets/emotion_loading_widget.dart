import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import 'blob_painter.dart';

class EmotionLoadingWidget extends StatefulWidget {
  final String message;

  const EmotionLoadingWidget({
    super.key,
    this.message = 'AI가 감정을 분석 중입니다...',
  });

  @override
  State<EmotionLoadingWidget> createState() => _EmotionLoadingWidgetState();
}

class _EmotionLoadingWidgetState extends State<EmotionLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _blobController;
  late AnimationController _progressController;
  late Timer _stepTimer;

  int _currentStep = 0;

  static const _steps = [
    _LoadingStep('👀', 'AI가 감지 중', '반려동물의 감정을 섬세하게 읽어내고 있어요'),
    _LoadingStep('🧠', 'AI가 분석 중', '표정과 외관에서 감정 신호를 추출하고 있어요'),
    _LoadingStep('📊', 'AI가 계산 중', '5가지 감정 지표를 정밀하게 산출하고 있어요'),
    _LoadingStep('✨', 'AI가 완료 중', '맞춤형 리포트를 정리하고 있어요'),
  ];

  @override
  void initState() {
    super.initState();

    _blobController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _progressController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..forward();

    _stepTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted) return;
      setState(() {
        _currentStep = (_currentStep + 1) % _steps.length;
      });
    });
  }

  @override
  void dispose() {
    _stepTimer.cancel();
    _blobController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFEFAF6), Color(0xFFFFF5EE), Color(0xFFF0F4FF)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          _buildAmbientBlobs(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 블롭 + 이모지
                SizedBox(
                  width: 180.w,
                  height: 180.w,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildMainBlob(),
                      _buildCenterEmoji(),
                    ],
                  ),
                ),

                SizedBox(height: 36.h),

                // 텍스트
                _buildStepText(),

                SizedBox(height: 32.h),

                // 원형 프로그레스
                _buildCircularProgress(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 배경 Ambient 블롭 3개
  Widget _buildAmbientBlobs() {
    final colors = [
      AppTheme.happinessColor,
      AppTheme.anxietyColor,
      AppTheme.curiosityColor,
    ];

    return AnimatedBuilder(
      animation: _blobController,
      builder: (_, __) {
        return Stack(
          children: List.generate(3, (i) {
            final offset =
                sin(_blobController.value * 2 * pi + i * 1.2) * 15;
            final size = (160.0 + i * 50).w;

            return Positioned(
              top: (80.0 + i * 140).h,
              left: (20.0 + i * 80).w,
              child: Transform.translate(
                offset: Offset(offset, -offset * 0.7),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors[i].withValues(alpha: 0.04),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  /// 메인 모핑 블롭 (2겹)
  Widget _buildMainBlob() {
    final emotionColors = _getStepColors();

    return AnimatedBuilder(
      animation: _blobController,
      builder: (_, __) {
        return Stack(
          children: [
            // 1번 블롭 (opacity 0.2)
            CustomPaint(
              size: Size(180.w, 180.w),
              painter: BlobPainter(
                animationValue: _blobController.value,
                color1: emotionColors.$1,
                color2: emotionColors.$2,
                opacity: 0.2,
              ),
            ),
            // 2번 블롭 (오프셋 +0.3, opacity 0.15)
            CustomPaint(
              size: Size(180.w, 180.w),
              painter: BlobPainter(
                animationValue:
                    (_blobController.value + 0.3) % 1.0,
                color1: emotionColors.$2,
                color2: emotionColors.$1,
                opacity: 0.15,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 블롭 중심 이모지
  Widget _buildCenterEmoji() {
    return AnimatedBuilder(
      animation: _blobController,
      builder: (_, __) {
        final pulseScale =
            1.0 + sin(_blobController.value * 2 * pi) * 0.04;
        return Transform.scale(
          scale: pulseScale,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.elasticOut,
                  ),
                ),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Text(
              _steps[_currentStep].emoji,
              key: ValueKey<int>(_currentStep),
              style: TextStyle(fontSize: 48.sp),
            ),
          ),
        );
      },
    );
  }

  /// 단계별 텍스트 (fade + slide up)
  Widget _buildStepText() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: offsetAnimation,
            child: child,
          ),
        );
      },
      child: Column(
        key: ValueKey<int>(_currentStep),
        children: [
          Text(
            _steps[_currentStep].mainText,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryTextColor,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            _steps[_currentStep].subText,
            style: TextStyle(
              fontSize: 13.sp,
              color: const Color(0xFF999999),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 원형 프로그레스 링
  Widget _buildCircularProgress() {
    final emotionColors = [
      AppTheme.happinessColor,
      AppTheme.sadnessColor,
      AppTheme.anxietyColor,
      AppTheme.sleepinessColor,
      AppTheme.curiosityColor,
    ];
    final currentColor = emotionColors[_currentStep % emotionColors.length];

    return AnimatedBuilder(
      animation: _progressController,
      builder: (_, __) {
        final progress = _progressController.value;
        return SizedBox(
          width: 56.w,
          height: 56.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(56.w, 56.w),
                painter: CircularProgressPainter(
                  progress: progress,
                  color: currentColor,
                  backgroundColor: const Color(0xFFE8E8E8),
                  strokeWidth: 3.0,
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 500),
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: currentColor,
                ),
                child: Text('${(progress * 100).round()}%'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 현재 단계에 맞는 감정 컬러 쌍 반환
  (Color, Color) _getStepColors() {
    switch (_currentStep) {
      case 0:
        return (AppTheme.happinessColor, AppTheme.curiosityColor);
      case 1:
        return (AppTheme.curiosityColor, AppTheme.sadnessColor);
      case 2:
        return (AppTheme.anxietyColor, AppTheme.happinessColor);
      case 3:
        return (AppTheme.happinessColor, AppTheme.anxietyColor);
      default:
        return (AppTheme.happinessColor, AppTheme.curiosityColor);
    }
  }
}

class _LoadingStep {
  final String emoji;
  final String mainText;
  final String subText;

  const _LoadingStep(this.emoji, this.mainText, this.subText);
}
