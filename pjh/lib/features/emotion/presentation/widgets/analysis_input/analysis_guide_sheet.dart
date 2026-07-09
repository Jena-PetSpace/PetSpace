// v2-review: 촬영 가이드 장식 그라데이션 — 일러스트 트랙과 함께 재검토, 치환 보류.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../shared/themes/app_theme.dart';
import 'guide_tip_row.dart';

/// 감정 분석 첫 방문 시 표시되는 전체 화면 사용 가이드 시트.
/// - 아이콘·제목·설명·"좋은 분석을 위한 팁" 4종(GuideTipRow)·"분석 시작하기" 버튼
/// "다시 안 보기"(SharedPreferences) 저장과 _showFullGuide 토글은 부모가 관리,
/// 위젯은 표시 + 버튼 탭 시 onDismiss 콜백 호출만.
class AnalysisGuideSheet extends StatelessWidget {
  final VoidCallback onDismiss;

  const AnalysisGuideSheet({
    super.key,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0F4FF), Color(0xFFFEFAF6)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            children: [
              SizedBox(height: 60.h),

              // 아이콘
              Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.1),
                      AppTheme.primaryColor.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.pets,
                      size: 40.w,
                      color: AppTheme.primaryColor,
                    ),
                    Positioned(
                      right: 20.w,
                      top: 20.h,
                      child: Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.psychology,
                          size: 14.w,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32.h),

              // 제목
              Text(
                'AI 감정 분석',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'AI가 반려동물의 표정과 행동을 분석하여\n감정 상태를 알려드립니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppTheme.secondaryTextColor,
                  height: 1.5,
                ),
              ),

              SizedBox(height: 40.h),

              // 팁 카드
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '좋은 분석을 위한 팁',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    const GuideTipRow(
                      icon: Icons.face,
                      color: Colors.blue,
                      title: '얼굴이 선명하게',
                      subtitle: '반려동물의 얼굴이 잘 보이도록 촬영해주세요',
                    ),
                    SizedBox(height: 16.h),
                    const GuideTipRow(
                      icon: Icons.wb_sunny,
                      color: Colors.orange,
                      title: '충분한 조명',
                      subtitle: '밝은 곳에서 촬영하면 더 정확해요',
                    ),
                    SizedBox(height: 16.h),
                    const GuideTipRow(
                      icon: Icons.zoom_in,
                      color: Colors.green,
                      title: '가까운 거리에서',
                      subtitle: '너무 멀리서 찍지 마시고 가까이서 촬영해주세요',
                    ),
                    SizedBox(height: 16.h),
                    const GuideTipRow(
                      icon: Icons.crop_free,
                      color: AppTheme.errorColor,
                      title: '깔끔한 배경',
                      subtitle: '배경이 복잡하지 않은 곳에서 촬영해주세요',
                    ),
                  ],
                ),
              ),

              SizedBox(height: 40.h),

              // 분석 시작하기 버튼
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    '분석 시작하기',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }
}
