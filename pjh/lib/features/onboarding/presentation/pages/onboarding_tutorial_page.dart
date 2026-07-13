import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/icon_badge_circle.dart';
import '../../../../shared/widgets/petspace_app_bar.dart';

class OnboardingTutorialPage extends StatefulWidget {
  const OnboardingTutorialPage({super.key});

  @override
  State<OnboardingTutorialPage> createState() => _OnboardingTutorialPageState();
}

class _OnboardingTutorialPageState extends State<OnboardingTutorialPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 4;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: PetSpaceAppBar.page(
        title: '감정 분석 가이드',
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/onboarding/pet-registration');
          }
        },
        trailing: TextButton(
          onPressed: _skip,
          child: Text(
            '건너뛰기',
            style: TextStyle(
              color: AppTheme.secondaryTextColor,
              fontWeight: FontWeight.w500,
              fontSize: 14.sp,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildWelcomePage(),
                  _buildPhotoTipsPage(),
                  _buildAnalysisProcessPage(),
                  _buildResultsPage(),
                ],
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    // 튜토리얼은 스킵 가능한 '가이드'이므로 의무 가입단계(세그먼트바 + N/3)와
    // 구분되도록 콘텐츠 페이지 닷(캐러셀 표기)을 사용한다. (안 A — 구분)
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalPages, (index) {
          final active = index == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            width: active ? 24.w : 8.w,
            height: 8.h,
            decoration: BoxDecoration(
              color: active ? AppTheme.primaryColor : AppTheme.neutral300,
              borderRadius: BorderRadius.circular(4.r),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconBadgeCircle(
            icon: Icons.psychology,
            size: 150.w,
            tone: BadgeTone.neutral,
          ),
          SizedBox(height: 40.h),
          Text(
            '감정 분석 시작하기',
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          Text(
            'AI가 반려동물의 표정과 행동을 분석하여\n감정 상태를 알려드립니다',
            style: TextStyle(
              fontSize: 16.sp,
              color: AppTheme.neutral600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Colors.blue[700],
                  size: 32.w,
                ),
                SizedBox(height: 12.h),
                Text(
                  '더 정확한 분석을 위해\n몇 가지 팁을 알려드릴게요!',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTipsPage() {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20.h),
          Text(
            '좋은 사진 촬영 팁',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '더 정확한 감정 분석을 위한 사진 촬영 방법',
            style: TextStyle(
              fontSize: 16.sp,
              color: AppTheme.neutral600,
            ),
          ),
          SizedBox(height: 32.h),
          Expanded(
            child: ListView(
              children: [
                _buildTipItem(
                  Icons.visibility,
                  '얼굴이 선명하게',
                  '반려동물의 얼굴이 잘 보이도록 촬영해주세요',
                  Colors.green,
                ),
                SizedBox(height: 20.h),
                _buildTipItem(
                  Icons.wb_sunny,
                  '충분한 조명',
                  '밝은 곳에서 촬영하면 더 정확한 분석이 가능해요',
                  Colors.orange,
                ),
                SizedBox(height: 20.h),
                _buildTipItem(
                  Icons.center_focus_strong,
                  '가까운 거리에서',
                  '너무 멀리서 찍지 마시고 가까이서 촬영해주세요',
                  Colors.blue,
                ),
                SizedBox(height: 20.h),
                _buildTipItem(
                  Icons.block,
                  '방해 요소 제거',
                  '배경이 복잡하지 않고 깔끔한 곳에서 촬영해주세요',
                  AppTheme.errorColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(
      IconData icon, String title, String description, Color color) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(25.r),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28.w,
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
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.neutral700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisProcessPage() {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20.h),
          Text(
            '분석 과정',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'AI가 반려동물의 감정을 분석하는 방법',
            style: TextStyle(
              fontSize: 16.sp,
              color: AppTheme.neutral600,
            ),
          ),
          SizedBox(height: 32.h),
          Expanded(
            child: ListView(
              children: [
                _buildProcessStep(
                  1,
                  '이미지 업로드',
                  '촬영한 사진을 AI 서버로 전송합니다',
                  Icons.cloud_upload,
                ),
                SizedBox(height: 20.h),
                _buildProcessStep(
                  2,
                  '얼굴 인식',
                  '반려동물의 얼굴과 표정을 감지합니다',
                  Icons.face,
                ),
                SizedBox(height: 20.h),
                _buildProcessStep(
                  3,
                  '감정 분석',
                  '표정, 자세, 행동을 종합적으로 분석합니다',
                  Icons.psychology,
                ),
                SizedBox(height: 20.h),
                _buildProcessStep(
                  4,
                  '결과 제공',
                  '감정 점수와 상세한 분석 결과를 제공합니다',
                  Icons.assessment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessStep(
      int step, String title, String description, IconData icon) {
    return Row(
      children: [
        Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Center(
            child: Text(
              step.toString(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppTheme.neutral50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppTheme.neutral200),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 32.w,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppTheme.neutral600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsPage() {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 완료/성공 비주얼은 complete 기준(발바닥 + 성공 체크)으로 통일 — 회색 별 폐기
          IconBadgeCircle(
            icon: Icons.pets,
            size: 150.w,
            tone: BadgeTone.success,
            ring: true,
            cornerBadge: SuccessCheckBadge(size: 40.w),
          ),
          SizedBox(height: 40.h),
          Text(
            '준비 완료!',
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          Text(
            '이제 반려동물의 감정을 분석해보세요!\n첫 번째 분석을 시작해볼까요?',
            style: TextStyle(
              fontSize: 16.sp,
              color: AppTheme.neutral600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.pets,
                  color: Colors.green[700],
                  size: 32.w,
                ),
                SizedBox(height: 12.h),
                Text(
                  '반려동물과 함께하는\n특별한 순간들을 기록해보세요!',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                child: Text('이전', style: TextStyle(fontSize: 16.sp)),
              ),
            ),
          if (_currentPage > 0) SizedBox(width: 16.w),
          Expanded(
            flex: _currentPage == 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _currentPage == _totalPages - 1
                  ? _startFirstAnalysis
                  : _nextPage,
              child: Text(
                _currentPage == _totalPages - 1 ? '첫 분석 시작하기' : '다음',
                style: TextStyle(fontSize: 16.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skip() {
    context.go('/onboarding/complete');
  }

  void _startFirstAnalysis() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('튜토리얼 완료! 첫 번째 감정 분석을 시작해보세요')),
    );
    context.go('/onboarding/complete');
  }
}
