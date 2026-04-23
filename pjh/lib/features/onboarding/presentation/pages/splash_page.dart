import 'dart:async';
import 'dart:developer';

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
  bool _lottieFinished = false;
  bool _authReady = false;
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

    // 로고 슬라이드인 + 페이드인 (600ms)
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

    // 최대 3초 타임아웃 — Lottie가 로드됐든 아니든 강제 이동
    // (단, Lottie가 이미 재생 중이면 최소 애니메이션은 보장)
    _maxWaitTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _lottieFinished = true); // 강제로 완료 처리
      _navigate();
    });
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _logoController.dispose();
    _maxWaitTimer?.cancel();
    super.dispose();
  }

  // Lottie 로드 완료 콜백 — 딜레이 없이 즉시 재생
  void _onLottieLoaded(LottieComposition composition) {
    if (!mounted) return;
    setState(() => _lottieLoaded = true);
    _lottieController
      ..duration = composition.duration
      ..forward().then((_) {
        if (!mounted) return;
        setState(() => _lottieFinished = true);
        _logoController.forward();
        // Lottie 완료 후 400ms 대기 후 이동 시도
        Future.delayed(const Duration(milliseconds: 400), _tryNavigate);
      });

    // Lottie 시작 800ms 후 로고 미리 등장 (자연스러운 타이밍)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_logoController.isAnimating && !_lottieFinished) {
        _logoController.forward();
      }
    });
  }

  // BlocListener에서 호출
  void _onAuthStateChanged() {
    _authReady = true;
    _tryNavigate();
  }

  // Lottie 완료 + Auth 준비 둘 다 충족 시 이동
  void _tryNavigate() {
    if (!mounted) return;
    if (_lottieFinished && _authReady) _navigate();
  }

  void _navigate() {
    _maxWaitTimer?.cancel();
    if (!mounted) return;
    final authState = context.read<AuthBloc>().state;

    // AuthInitial/AuthLoading은 아직 인증 확인 중 — 이동하지 않음
    // BlocListener나 타이머가 재호출할 때까지 대기
    if (authState is AuthInitial || authState is AuthLoading) return;

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
      // AuthInitial/AuthLoading 무시 — 확정 상태만 처리
      listenWhen: (_, current) =>
          current is AuthAuthenticated || current is AuthUnauthenticated,
      listener: (_, __) => _onAuthStateChanged(),
      child: Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: Stack(
          children: [
            // ── 배경 장식 링 (화이트 7% opacity, 깊이감) ──
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

            // ── 메인 콘텐츠 ──
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Lottie 캐릭터 애니메이션
                  // 로드 전에는 투명, 로드 완료 후 페이드인
                  AnimatedOpacity(
                    opacity: _lottieLoaded ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: SizedBox(
                      width: 160.w,
                      height: 160.w,
                      child: Lottie.asset(
                        'assets/lottie/splash.json',
                        controller: _lottieController,
                        onLoaded: _onLottieLoaded,
                        fit: BoxFit.contain,
                        errorBuilder: (_, error, ___) {
                          // Lottie 실패 시 splash_char.png fallback
                          log('Lottie 로드 실패: $error', name: 'SplashPage');
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            setState(() {
                              _lottieLoaded = true; // fallback 이미지 표시
                              _lottieFinished = true;
                            });
                            _logoController.forward();
                            Future.delayed(
                              const Duration(milliseconds: 600),
                              _tryNavigate,
                            );
                          });
                          return Image.asset(
                            'assets/icons/splash_char.png',
                            width: 120.w,
                            height: 120.w,
                            fit: BoxFit.contain,
                          );
                        },
                        repeat: false,
                      ),
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // ── 로고 + 슬로건 슬라이드인 페이드인 ──
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
                          // AI 서비스 뱃지
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

            // ── 하단: 3dot 로딩 인디케이터 + JENA Team (home indicator 영역 회피) ──
            Positioned(
              bottom: 48.h + MediaQuery.of(context).padding.bottom,
              left: 0, right: 0,
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

// ── 배경 장식 링 ─────────────────────────────────────────────────
class _DecoRing extends StatelessWidget {
  final double size;
  const _DecoRing({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
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

// ── 3dot 로딩 인디케이터 ──────────────────────────────────────────
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
          width: 5.w, height: 5.w,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.highlightColor,
          ),
        ),
      ),
    );
  }
}
