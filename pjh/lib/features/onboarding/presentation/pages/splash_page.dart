import 'package:flutter/material.dart';
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

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _logoVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _startSequence();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startSequence() async {
    // 발바닥 Lottie 애니메이션 재생
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // 로고 페이드인
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _logoVisible = true);

    // 총 1.8초 후 인증 상태 확인 → 네비게이션
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _navigate();
  }

  void _navigate() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.go('/home');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lottie 발바닥 애니메이션
              SizedBox(
                width: 160.w,
                height: 160.w,
                child: Lottie.asset(
                  'assets/lottie/splash.json',
                  controller: _controller,
                  onLoaded: (composition) {
                    _controller
                      ..duration = composition.duration
                      ..forward();
                  },
                  errorBuilder: (context, error, stackTrace) {
                    // Lottie 오류 시 아이콘으로 fallback
                    return Container(
                      width: 120.w,
                      height: 120.w,
                      decoration: const BoxDecoration(
                        color: AppTheme.highlightColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.pets,
                        size: 60.w,
                        color: Colors.white,
                      ),
                    );
                  },
                  repeat: false,
                ),
              ),
              SizedBox(height: 24.h),

              // PetSpace 로고 텍스트 (페이드인)
              AnimatedOpacity(
                opacity: _logoVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                child: Column(
                  children: [
                    PetSpaceLogo(variant: LogoVariant.dark, height: 36.h),
                    SizedBox(height: 8.h),
                    Text(
                      '반려동물과 더 가까이',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
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
