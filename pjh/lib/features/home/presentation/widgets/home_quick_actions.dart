import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';

/// 홈 상단 퀵 액션 — 원형 아이콘 버튼 5개 가로 배치.
/// 아이콘은 임시(Material Icons)이며, 추후 전용 일러스트/에셋으로 교체 예정.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        // 플레이스 = 기존 동물병원 찾기
        icon: Icons.place_rounded,
        label: '플레이스',
        color: const Color(0xFF4CAF50),
        onTap: () => context.push('/hospital'),
      ),
      _QuickAction(
        icon: Icons.psychology_rounded,
        label: 'MBTI 검사',
        color: const Color(0xFF7E57C2),
        // push로 진입해야 뒤로가기(앱·하드웨어)로 홈 복귀 가능
        onTap: () => context.push('/mbti'),
      ),
      _QuickAction(
        icon: Icons.directions_walk_rounded,
        label: '산책 기록',
        color: const Color(0xFF009688),
        // 미구현 — 버튼만 노출, 탭 시 안내 스낵바
        onTap: () => _showComingSoon(context),
      ),
      _QuickAction(
        icon: Icons.auto_awesome_rounded,
        label: '오늘의 운세',
        color: const Color(0xFFFF9800),
        onTap: () => context.push('/fortune'),
      ),
      _QuickAction(
        icon: Icons.quiz_rounded,
        label: 'O/X 퀴즈',
        color: AppTheme.accentColor,
        onTap: () => context.push('/quiz/play'),
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Row(
        // 5개가 가로 폭에 균등하게 들어가도록 Expanded 배치
        children: actions
            .map((a) => Expanded(child: _buildItem(context, a)))
            .toList(),
      ),
    );
  }

  Widget _buildItem(BuildContext context, _QuickAction action) {
    return GestureDetector(
      onTap: action.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: action.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(action.icon, size: 24.w, color: action.color),
          ),
          SizedBox(height: 8.h),
          Text(
            action.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('산책 기록은 곧 추가될 예정이에요 🐾'),
          duration: Duration(seconds: 2),
        ),
      );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
