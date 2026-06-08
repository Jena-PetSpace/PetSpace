import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_logo.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../emotion/presentation/bloc/emotion_analysis_bloc.dart';
import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../chat/presentation/bloc/chat_badge/chat_badge_bloc.dart';
import '../../../social/presentation/bloc/notification_badge/notification_badge_bloc.dart';
import 'pet_passport_card.dart';

/// 홈 화면 전체 헤더
/// 딥블루 배경 + 로고 + 스트릭 + 반려동물 감정 대시보드
class HomeDashboardHeader extends StatelessWidget {
  const HomeDashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── 로고 + 액션 바 ──────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Row(
                children: [
                  // 로고 (하단 인사말 제거 · 크기 확대)
                  PetSpaceLogo(variant: LogoVariant.dark, height: 40.h),
                  const Spacer(),
                  // 스트릭 배지
                  _buildStreakBadge(context),
                  SizedBox(width: 6.w),
                  // 검색 아이콘
                  GestureDetector(
                    onTap: () => context.push('/search'),
                    child: Icon(Icons.search_rounded, color: Colors.white, size: 24.w),
                  ),
                  SizedBox(width: 6.w),
                  // 알림 아이콘
                  _buildNotificationIcon(context),
                  SizedBox(width: 4.w),
                  // 채팅 아이콘
                  _buildChatIcon(context),
                ],
              ),
            ),

            // ── 반려동물 대시보드 카드 ──────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
              child: _buildPetDashboard(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── 스트릭 배지 ───────────────────────────────────────
  Widget _buildStreakBadge(BuildContext context) {
    return BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
      builder: (context, state) {
        final streak = _calculateStreak(state);
        if (streak == 0) return const SizedBox.shrink();
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: AppTheme.highlightColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🔥', style: TextStyle(fontSize: 13.sp)),
              SizedBox(width: 4.w),
              Text(
                '$streak일',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 알림 아이콘 ───────────────────────────────────────
  Widget _buildNotificationIcon(BuildContext context) {
    return BlocBuilder<NotificationBadgeBloc, NotificationBadgeState>(
      builder: (context, notiState) {
        return GestureDetector(
          onTap: () {
            context.push('/notifications');
            final authState = context.read<AuthBloc>().state;
            if (authState is AuthAuthenticated) {
              context.read<NotificationBadgeBloc>().add(
                    NotificationBadgeLoadRequested(userId: authState.user.uid),
                  );
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SvgPicture.asset('assets/svg/icon_notification.svg', width: 24.w, height: 24.w, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
              if (notiState.count > 0)
                Positioned(
                  top: -3.h,
                  right: -3.w,
                  child: Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                      color: AppTheme.highlightColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── 채팅 아이콘 ───────────────────────────────────────
  Widget _buildChatIcon(BuildContext context) {
    return BlocBuilder<ChatBadgeBloc, ChatBadgeState>(
      builder: (context, badgeState) {
        return GestureDetector(
          onTap: () => context.push('/chat'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SvgPicture.asset('assets/svg/icon_message.svg', width: 24.w, height: 24.w, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
              if (badgeState.count > 0)
                Positioned(
                  top: -4.h,
                  right: -5.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: AppTheme.highlightColor,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: AppTheme.primaryColor, width: 1.5),
                    ),
                    constraints: BoxConstraints(minWidth: 16.w, minHeight: 16.w),
                    child: Text(
                      badgeState.count > 99 ? '99+' : '${badgeState.count}',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── 반려동물 대시보드 카드(= 펫 여권 카드) ──────────────
  Widget _buildPetDashboard(BuildContext context) {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, petState) {
        final pet = _getSelectedPet(petState);
        if (pet == null) return _buildNoPetCard(context);
        return BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
          builder: (context, emotionState) {
            return PetPassportCard(
              pet: pet,
              mood: _todayMood(emotionState, pet),
              onHealthTap: () => context.go('/emotion'),
              onHistoryTap: () => context.push('/ai-history-page'),
              onAnalyzeTap: () => context.go('/emotion'),
            );
          },
        );
      },
    );
  }

  /// 오늘의 기분(분포 1위 감정 + 비율). 오늘 분석이 없으면 null → "오늘 분석하기".
  /// ⚠️ 비율은 감정 **분포값**이지 신뢰도(confidence) 점수가 아니다.
  PassportMood? _todayMood(EmotionAnalysisState state, Pet pet) {
    if (state is! EmotionAnalysisHistoryLoaded || state.history.isEmpty) {
      return null;
    }
    final today = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == today.year && d.month == today.month && d.day == today.day;

    // 선택된 펫의 오늘 분석 중 최신 1건.
    EmotionAnalysis? latest;
    for (final a in state.history) {
      final matchesPet = a.petId == null || a.petId == pet.id;
      if (matchesPet && isToday(a.analyzedAt)) {
        if (latest == null || a.analyzedAt.isAfter(latest.analyzedAt)) {
          latest = a;
        }
      }
    }
    if (latest == null) return null;

    final scores = latest.emotions;
    final total = scores.total;
    if (total <= 0) return null;

    final dominant = scores.dominantEmotion;
    final value = _emotionValue(scores, dominant);
    final percent = ((value / total) * 100).round();

    return PassportMood(
      label: AppTheme.getEmotionLabel(dominant),
      percent: percent,
      emoji: AppTheme.getEmotionEmoji(dominant),
    );
  }

  double _emotionValue(EmotionScores s, String key) {
    switch (key) {
      case 'happiness':
        return s.happiness;
      case 'calm':
        return s.calm;
      case 'excitement':
        return s.excitement;
      case 'curiosity':
        return s.curiosity;
      case 'anxiety':
        return s.anxiety;
      case 'fear':
        return s.fear;
      case 'sadness':
        return s.sadness;
      case 'discomfort':
        return s.discomfort;
      default:
        return 0;
    }
  }


  Widget _buildNoPetCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/pets'),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🐾', style: TextStyle(fontSize: 24.sp)),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '반려동물을 등록해보세요',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'AI 감정 분석을 시작할 수 있어요',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.6), size: 16.w),
          ],
        ),
      ),
    );
  }

  // ── 헬퍼 메서드 ───────────────────────────────────────
  Pet? _getSelectedPet(PetState state) {
    if (state is PetLoaded && state.pets.isNotEmpty) {
      return state.selectedPet ?? state.pets.first;
    }
    if (state is PetOperationSuccess && state.pets.isNotEmpty) {
      return state.pets.first;
    }
    return null;
  }

  /// 연속 분석 일수 계산
  int _calculateStreak(EmotionAnalysisState state) {
    if (state is! EmotionAnalysisHistoryLoaded || state.history.isEmpty) {
      return 0;
    }
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final analyzedDates = state.history
        .map((a) {
          final d = a.analyzedAt;
          return DateTime(d.year, d.month, d.day);
        })
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (analyzedDates.isEmpty) return 0;
    if (analyzedDates.first != todayDate &&
        analyzedDates.first != todayDate.subtract(const Duration(days: 1))) {
      return 0;
    }

    int streak = 0;
    DateTime check = analyzedDates.first;
    for (final date in analyzedDates) {
      if (date == check) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }
}
