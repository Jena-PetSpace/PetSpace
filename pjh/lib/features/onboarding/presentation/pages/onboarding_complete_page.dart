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
        // 작은 화면(예: iPhone 17 Pro 402×874)에서 고정 Column이 19px 넘치던 문제 수정.
        // 뷰포트보다 콘텐츠가 크면 스크롤되고, 작으면 Spacer로 중앙 정렬 유지.
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        _buildSuccessAnimation(),
                        SizedBox(height: 24.h),
                        _buildWelcomeMessage(),
                        SizedBox(height: 24.h),
                        _buildFeatureHighlights(),
                        // (세션6 C-3) "지금 바로 AI 첫 분석" 배너 제거. 하단 2버튼은 유지.
                        const Spacer(flex: 3),
                        _buildActionButtons(),
                        SizedBox(height: 16.h),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
            width: 140.w,
            height: 140.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: Center(
              // (세션6 C-1) 우상단 초록 체크 아이콘 제거. 펫 아이콘 원만 유지.
              child: Icon(
                Icons.pets,
                size: 56.w,
                color: AppTheme.primaryColor,
              ),
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
            '준비가 완료됐어요',
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.brandDeep,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          Text(
            '반려동물의 일상과 건강을 기록하고\n믿을 수 있는 이웃과 나눌 수 있어요.',
            style: TextStyle(
              fontSize: 16.sp,
              color: AppTheme.neutral600,
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
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Text(
              '이제 이렇게 시작해보세요',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.neutral800,
              ),
            ),
            SizedBox(height: 20.h),
            _buildFeatureItem(
              Icons.camera_alt,
              '감정 분석',
              '사진으로 표정과 감정 신호를 살펴보세요',
              AppTheme.accentColor,
            ),
            SizedBox(height: 16.h),
            _buildFeatureItem(
              Icons.timeline,
              '건강 분석 및 기록',
              '변화를 놓치지 않도록 건강 기록을 남겨보세요',
              AppTheme.subColor,
            ),
            SizedBox(height: 16.h),
            _buildFeatureItem(
              Icons.people,
              '커뮤니티 참여',
              '피드와 커뮤니티에서 경험을 나눠보세요',
              AppTheme.highlightColor,
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
                  color: AppTheme.neutral600,
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
            height: 52.h,
            child: ElevatedButton(
              onPressed: _startUsingApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.actionBase,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd.r),
                ),
              ),
              child: Text(
                'PetSpace 시작하기',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          SizedBox(
            height: 44.h,
            child: TextButton(
              onPressed: _tryFirstAnalysis,
              child: Text(
                '첫 감정 분석부터 해보기',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
      // 온보딩 완료 이벤트 발생
      authBloc.add(AuthOnboardingCompleted(
        displayName: authState.user.displayName,
        avatarUrl: authState.user.photoURL,
      ));

      // AuthBloc의 상태 변경을 기다림 (isOnboardingCompleted가 true로 업데이트될 때까지)
      // 서버 지연 등으로 stream이 응답하지 않을 경우 5초 후 현재 state로 fallback
      await authBloc.stream
          .firstWhere(
            (state) =>
                state is AuthAuthenticated && state.user.isOnboardingCompleted,
            orElse: () => authState,
          )
          .timeout(const Duration(seconds: 5), onTimeout: () => authState);

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
