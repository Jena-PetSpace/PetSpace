import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_logo.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _lottieController;
  late AnimationController _logoController;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;

  bool _lottieLoaded = false;
  bool _symbolVisible = true; // 네이티브 브릿지용 발바닥 PNG
  bool _authReady = false;
  bool _lottieFinished = false;
  Timer? _maxWaitTimer;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _lottieController = AnimationController(vsync: this);

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );

    // 최대 3초 타임아웃
    _maxWaitTimer = Timer(const Duration(seconds: 3), _navigate);
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _logoController.dispose();
    _maxWaitTimer?.cancel();
    super.dispose();
  }

  void _onLottieLoaded(LottieComposition composition) {
    if (!mounted) return;
    setState(() {
      _lottieLoaded = true;
      _symbolVisible = false; // PNG → Lottie 교체
    });
    _lottieController
      ..duration = composition.duration
      ..forward().then((_) {
        if (!mounted) return;
        setState(() => _lottieFinished = true);
        _logoController.forward();
        Future.delayed(const Duration(milliseconds: 400), _tryNavigate);
      });

    // Lottie 시작 800ms 후 로고 미리 등장
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_logoController.isAnimating && !_lottieFinished) {
        _logoController.forward();
      }
    });
  }

  void _onAuthStateChanged() {
    _authReady = true;
    _tryNavigate();
  }

  void _tryNavigate() {
    if (!mounted) return;
    if (_lottieFinished && _authReady) _navigate();
  }

  void _navigate() {
    _maxWaitTimer?.cancel();
    if (!mounted) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      if (!authState.user.isOnboardingCompleted) {
        context.go('/onboarding/terms');
      } else {
        context.go('/home');
      }
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, current) =>
          current is AuthAuthenticated || current is AuthUnauthenticated,
      listener: (_, __) => _onAuthStateChanged(),
      child: Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: Stack(
          children: [
            // 배경 장식 링
            Positioned(
              top: -80, right: -100,
              child: _DecoRing(size: 300.r),
            ),
            Positioned(
              bottom: -40, left: -80,
              child: _DecoRing(size: 220.r),
            ),
            Positioned(
              top: 100, left: -50,
              child: _DecoRing(size: 140.r),
            ),

            // 메인 콘텐츠
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 심볼 + Lottie 영역
                  SizedBox(
                    width: 160.w,
                    height: 160.w,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 네이티브 브릿지 발바닥 PNG (Lottie 로드 전 표시)
                        AnimatedOpacity(
                          opacity: _symbolVisible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 150),
                          child: Image.asset(
                            'assets/icons/splash_symbol.png',
                            width: 100.w,
                            height: 100.w,
                          ),
                        ),
                        // Lottie 발바닥 애니메이션
                        AnimatedOpacity(
                          opacity: _lottieLoaded ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 150),
                          child: Lottie.asset(
                            'assets/lottie/splash.json',
                            controller: _lottieController,
                            onLoaded: _onLottieLoaded,
                            errorBuilder: (_, __, ___) {
                              // Lottie 실패 시 PNG 유지 + 타이머로 진행
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) {
                                if (!mounted) return;
                                setState(() {
                                  _symbolVisible = true;
                                  _lottieFinished = true;
                                });
                                Future.delayed(
                                  const Duration(milliseconds: 800),
                                  () {
                                    _logoController.forward();
                                    Future.delayed(
                                      const Duration(milliseconds: 600),
                                      _tryNavigate,
                                    );
                                  },
                                );
                              });
                              return const SizedBox.shrink();
                            },
                            repeat: false,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // 로고 + 슬로건 슬라이드인
                  SlideTransition(
                    position: _logoSlide,
                    child: FadeTransition(
                      opacity: _logoOpacity,
                      child: Column(
                        children: [
                          PetSpaceLogo(
                            variant: LogoVariant.dark,
                            height: 38.h,
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            '반려동물과 더 가까이',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.white.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(height: 14.h),
                          // AI 서비스 배지
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.highlightColor
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: AppTheme.highlightColor
                                    .withValues(alpha: 0.35),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              'AI 감정 분석 · 건강관리 · 커뮤니티',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: const Color(0xFFFF9B8F),
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 하단: 3dot 로딩 + JENA Team
            Positioned(
              bottom: 48.h,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => _LoadingDot(index: i),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'by JENA Team',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.white.withValues(alpha: 0.2),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 배경 장식 링
class _DecoRing extends StatelessWidget {
  final double size;
  const _DecoRing({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
      ),
    );
  }
}

// 3dot 로딩 인디케이터
class _LoadingDot extends StatefulWidget {
  final int index;
  const _LoadingDot({required this.index});

  @override
  State<_LoadingDot> createState() => _LoadingDotState();
}

class _LoadingDotState extends State<_LoadingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(
      Duration(milliseconds: widget.index * 200),
      () {
        if (mounted) _ctrl.repeat(reverse: true);
      },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3.w),
      child: FadeTransition(
        opacity: _anim,
        child: Container(
          width: 5.w,
          height: 5.w,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.highlightColor,
          ),
        ),
      ),
    );
  }
}
