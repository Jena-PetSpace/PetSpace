import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class OnboardingCompletePage extends StatefulWidget {
  const OnboardingCompletePage({super.key});

  @override
  State<OnboardingCompletePage> createState() => _OnboardingCompletePageState();
}

class _OnboardingCompletePageState extends State<OnboardingCompletePage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 40.h),
                _buildSuccessAnimation(),
                SizedBox(height: 40.h),
                _buildWelcomeMessage(),
                SizedBox(height: 32.h),
                _buildFeatureHighlights(),
                SizedBox(height: 32.h),
                _buildActionButtons(),
                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 200.w,
            height: 200.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.pets,
                  size: 80.w,
                  color: AppTheme.primaryColor,
                ),
                Positioned(
                  top: 40.w,
                  right: 40.w,
                  child: Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 8.r,
                          spreadRadius: 2.r,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 24.w,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeMessage() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Text(
            '환영합니다! 🎉',
            style: TextStyle(
              fontSize: 32.sp,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          Text(
            '펫페이스 설정이 완료되었습니다\n이제 반려동물과의 특별한 순간들을\n기록하고 공유해보세요',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey[600],
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureHighlights() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 10.r,
              spreadRadius: 2.r,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '이제 이런 것들을 할 수 있어요!',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 20.h),
            _buildFeatureItem(
              Icons.camera_alt,
              '감정 분석',
              '반려동물의 감정을 AI로 분석해보세요',
              Colors.blue,
            ),
            SizedBox(height: 16.h),
            _buildFeatureItem(
              Icons.timeline,
              '일상 기록',
              '매일의 소중한 순간들을 기록하세요',
              Colors.green,
            ),
            SizedBox(height: 16.h),
            _buildFeatureItem(
              Icons.people,
              '커뮤니티 참여',
              '다른 반려인들과 소통하고 공유하세요',
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
      IconData icon, String title, String description, Color color) {
    return Row(
      children: [
        Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Icon(
            icon,
            color: color,
            size: 22.w,
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: _startUsingApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home, size: 24.w),
                  SizedBox(width: 12.w),
                  Text(
                    '홈으로 이동하기',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: OutlinedButton(
              onPressed: _tryFirstAnalysis,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.psychology, size: 20.w),
                  SizedBox(width: 8.w),
                  Text(
                    '첫 감정 분석 해보기',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.star, color: Colors.amber[700], size: 24.w),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    '언제든지 설정에서 프로필과 반려동물 정보를 수정할 수 있어요',
                    style: TextStyle(
                      color: Colors.amber[800],
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startUsingApp() async {
    // 온보딩 완료 상태를 저장
    final authBloc = context.read<AuthBloc>();
    final authState = authBloc.state;

    if (authState is AuthAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('온보딩 완료! 펫페이스에 오신 것을 환영합니다 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // 온보딩 완료 이벤트 발생
      authBloc.add(AuthOnboardingCompleted(
        displayName: authState.user.displayName,
        avatarUrl: authState.user.photoURL,
      ));

      // AuthBloc의 상태 변경을 기다림 (isOnboardingCompleted가 true로 업데이트될 때까지)
      await authBloc.stream.firstWhere(
        (state) =>
            state is AuthAuthenticated && state.user.isOnboardingCompleted,
        orElse: () => authState,
      );

      if (mounted) {
        // GoRouter의 redirect 로직이 자동으로 홈으로 리다이렉트함
        // 명시적으로 /home으로 이동하면 redirect 로직이 실행됨
        context.go('/home');
      }
    }
  }

  void _tryFirstAnalysis() async {
    // 온보딩 완료 상태를 저장
    final authBloc = context.read<AuthBloc>();
    final authState = authBloc.state;

    if (authState is AuthAuthenticated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('첫 번째 감정 분석을 시작해보세요!')),
        );
      }

      // 온보딩 완료 이벤트 발생
      authBloc.add(AuthOnboardingCompleted(
        displayName: authState.user.displayName,
        avatarUrl: authState.user.photoURL,
      ));

      // AuthBloc의 상태 변경을 기다린 후 감정 분석 페이지로 이동
      await authBloc.stream.firstWhere(
        (state) =>
            state is AuthAuthenticated && state.user.isOnboardingCompleted,
        orElse: () => authState,
      );

      if (mounted) {
        context.go('/emotion');
      }
    }
  }
}
