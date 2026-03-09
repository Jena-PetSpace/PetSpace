import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../widgets/health_record_card.dart';
import '../widgets/emotion_trend_mini_chart.dart';
import '../widgets/health_alert_card.dart';

class HealthMainPage extends StatefulWidget {
  const HealthMainPage({super.key});

  @override
  State<HealthMainPage> createState() => _HealthMainPageState();
}

class _HealthMainPageState extends State<HealthMainPage> {
  @override
  Widget build(BuildContext context) {
    const String petName = '반려동물';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              '건강관리',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            Text(
              '$petName의 건강 기록',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 건강 알림 카드
            const HealthAlertCard(),
            SizedBox(height: 20.h),

            // 주간 감정 트렌드
            Text(
              '주간 감정 트렌드',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 12.h),
            const EmotionTrendMiniChart(),
            SizedBox(height: 20.h),

            // 건강 기록 리스트
            Text(
              '건강 기록',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 12.h),
            const HealthRecordCard(
              icon: Icons.vaccines,
              iconColor: AppTheme.highlightColor,
              title: '예방접종',
              subtitle: '광견병 예방접종',
              date: '2026.04.15',
              status: '예정',
              statusColor: AppTheme.highlightColor,
            ),
            SizedBox(height: 12.h),
            const HealthRecordCard(
              icon: Icons.health_and_safety,
              iconColor: Color(0xFF4CAF50),
              title: '건강검진',
              subtitle: '정기 건강검진',
              date: '2026.02.20',
              status: '완료',
              statusColor: Color(0xFF4CAF50),
            ),
            SizedBox(height: 12.h),
            const HealthRecordCard(
              icon: Icons.monitor_weight,
              iconColor: AppTheme.accentColor,
              title: '체중기록',
              subtitle: '4.2kg',
              date: '2026.03.01',
              status: '정상',
              statusColor: AppTheme.accentColor,
            ),
          ],
        ),
      ),
    );
  }
}
