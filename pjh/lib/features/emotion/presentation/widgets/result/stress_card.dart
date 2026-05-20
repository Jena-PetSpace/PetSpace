import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theme/emotion_result_tokens.dart';

/// 스트레스 지수 카드.
/// - 헤더: 라벨 + 상태 칩 (높음/보통/낮음)
/// - 점수: NN/100 (코랄)
/// - 게이지: amberSoft 배경 + 코랄 채움
/// - 본문 + 행동요령 2x2 그리드 (80+ 케이스만)
class StressCard extends StatelessWidget {
  final int score; // 0~100

  const StressCard({super.key, required this.score});

  bool get _isHigh => score >= 80;
  bool get _isMid => score >= 50 && score < 80;

  String get _label {
    if (_isHigh) return '높음';
    if (_isMid) return '보통';
    return '낮음';
  }

  Color get _chipBg {
    if (_isHigh) return EmotionResultTokens.coralMid;
    if (_isMid) return EmotionResultTokens.amberSoft;
    return EmotionResultTokens.navyLight;
  }

  Color get _chipFg {
    if (_isHigh) return EmotionResultTokens.coralDark;
    if (_isMid) return EmotionResultTokens.amberDark;
    return EmotionResultTokens.navy;
  }

  Color get _gaugeFill {
    if (_isHigh) return EmotionResultTokens.coral;
    if (_isMid) return EmotionResultTokens.amber;
    return EmotionResultTokens.navy;
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '스트레스 지수',
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: EmotionResultTokens.textPrimary,
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: _chipBg,
            borderRadius: BorderRadius.circular(EmotionResultTokens.radiusChip.r),
          ),
          child: Text(
            _label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: _chipFg,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScore() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$score',
          style: TextStyle(
            fontSize: 30.sp,
            fontWeight: FontWeight.w600,
            color: _gaugeFill,
          ),
        ),
        SizedBox(width: 2.w),
        Text(
          '/100',
          style: TextStyle(
            fontSize: 14.sp,
            color: EmotionResultTokens.grayText,
          ),
        ),
      ],
    );
  }

  Widget _buildGauge() {
    return Stack(
      children: [
        Container(
          height: 6.h,
          decoration: BoxDecoration(
            color: EmotionResultTokens.amberSoft,
            borderRadius: BorderRadius.circular(3.r),
          ),
        ),
        FractionallySizedBox(
          widthFactor: (score / 100).clamp(0.0, 1.0),
          child: Container(
            height: 6.h,
            decoration: BoxDecoration(
              color: _gaugeFill,
              borderRadius: BorderRadius.circular(3.r),
            ),
          ),
        ),
      ],
    );
  }

  String get _bodyText {
    if (_isHigh) return '강한 스트레스 신호가 보여요. 지금 바로 자극을 줄여주세요.';
    if (_isMid) return '약간 긴장한 상태예요. 차분한 환경을 만들어 주세요.';
    return '편안한 상태예요. 평소 루틴을 그대로 유지해 주세요.';
  }

  /// 高(>=80) 케이스 행동요령 4가지.
  static const List<_StressAction> _highActions = [
    _StressAction(
      icon: Icons.block,
      label: '자극 제거',
      hint: '큰 소리·낯선 사람',
    ),
    _StressAction(
      icon: Icons.home_outlined,
      label: '조용한 공간',
      hint: '방·울타리로 이동',
    ),
    _StressAction(
      icon: Icons.favorite_border,
      label: '차분한 쓰다듬',
      hint: '낮은 톤·천천히',
    ),
    _StressAction(
      icon: Icons.toys_outlined,
      label: '친숙한 사물',
      hint: '담요·장난감',
    ),
  ];

  /// 中(50~79) 케이스 행동요령 4가지.
  static const List<_StressAction> _midActions = [
    _StressAction(
      icon: Icons.volume_off_outlined,
      label: '자극 줄이기',
      hint: 'TV 소리·사람 왕래',
    ),
    _StressAction(
      icon: Icons.air,
      label: '느린 호흡',
      hint: '옆에 앉아 호흡 맞추기',
    ),
    _StressAction(
      icon: Icons.pan_tool_outlined,
      label: '부드러운 쓰다듬',
      hint: '등·가슴 가볍게',
    ),
    _StressAction(
      icon: Icons.home_outlined,
      label: '익숙한 환경',
      hint: '좋아하는 자리로',
    ),
  ];

  /// 低(<50) 케이스 행동요령 4가지 — 평소 루틴 유지 가이드.
  static const List<_StressAction> _lowActions = [
    _StressAction(
      icon: Icons.bedtime_outlined,
      label: '충분한 휴식',
      hint: '깊은 잠을 위한 어두운 공간',
    ),
    _StressAction(
      icon: Icons.directions_walk,
      label: '규칙적 산책',
      hint: '매일 같은 시간대',
    ),
    _StressAction(
      icon: Icons.restaurant_outlined,
      label: '균형 잡힌 식사',
      hint: '정해진 양·시간',
    ),
    _StressAction(
      icon: Icons.favorite_outline,
      label: '함께하는 시간',
      hint: '눈 맞춤·짧은 대화',
    ),
  ];

  /// 현재 stressLevel에 해당하는 행동요령 4개.
  List<_StressAction> get _currentActions {
    if (_isHigh) return _highActions;
    if (_isMid) return _midActions;
    return _lowActions;
  }

  /// 구간별 액션 카드 보더 색.
  Color get _actionBorderColor {
    if (_isHigh) return EmotionResultTokens.coralBorder;
    if (_isMid) return EmotionResultTokens.amberMid;
    return EmotionResultTokens.dividerLight;
  }

  /// 구간별 액션 카드 아이콘 배경.
  Color get _actionIconBg {
    if (_isHigh) return EmotionResultTokens.coralLight;
    if (_isMid) return EmotionResultTokens.amberLight;
    return EmotionResultTokens.navyLight;
  }

  Widget _buildActionItem(_StressAction a) {
    return Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: EmotionResultTokens.cardSurface,
        border: Border.all(color: _actionBorderColor),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Container(
            width: 28.r,
            height: 28.r,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _actionIconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(a.icon, size: 16.r, color: _gaugeFill),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  a.label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: EmotionResultTokens.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  a.hint,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: EmotionResultTokens.grayText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8.h,
      crossAxisSpacing: 8.w,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.6,
      children: _currentActions.map(_buildActionItem).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: EmotionResultTokens.cardSurface,
        borderRadius: BorderRadius.circular(EmotionResultTokens.radiusCard.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          SizedBox(height: 12.h),
          _buildScore(),
          SizedBox(height: 8.h),
          _buildGauge(),
          SizedBox(height: 12.h),
          Text(
            _bodyText,
            style: TextStyle(
              fontSize: 12.sp,
              color: EmotionResultTokens.textSecondary,
              height: 1.5,
            ),
          ),
          SizedBox(height: 12.h),
          _buildActions(),
        ],
      ),
    );
  }
}

class _StressAction {
  final IconData icon;
  final String label;
  final String hint;
  const _StressAction({
    required this.icon,
    required this.label,
    required this.hint,
  });
}
