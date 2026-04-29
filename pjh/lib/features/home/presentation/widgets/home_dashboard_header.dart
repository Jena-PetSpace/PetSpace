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
import '../../../chat/presentation/bloc/chat_badge/chat_badge_bloc.dart';
import '../../../social/presentation/bloc/notification_badge/notification_badge_bloc.dart';

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
                  // 로고 + 인사말
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PetSpaceLogo(variant: LogoVariant.dark, height: 28.h),
                      SizedBox(height: 2.h),
                      _buildGreeting(context),
                    ],
                  ),
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

  // ── 시간대별 인사말 ───────────────────────────────────
  Widget _buildGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final String greeting;
    if (hour < 6) {
      greeting = '🌙 늦은 밤이에요';
    } else if (hour < 12) {
      greeting = '☀️ 좋은 아침이에요';
    } else if (hour < 18) {
      greeting = '🌤 즐거운 오후예요';
    } else {
      greeting = '🌙 편안한 저녁이에요';
    }

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final name = state is AuthAuthenticated
            ? state.user.displayName.split(' ').first
            : '';
        final label = name.isNotEmpty ? '$greeting, $name님' : greeting;
        return Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.white.withValues(alpha: 0.75),
            fontWeight: FontWeight.w500,
          ),
        );
      },
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

  // ── 반려동물 대시보드 카드 ─────────────────────────────
  Widget _buildPetDashboard(BuildContext context) {
    return BlocBuilder<PetBloc, PetState>(
      builder: (context, petState) {
        final pet = _getSelectedPet(petState);
        if (pet == null) return _buildNoPetCard(context);
        return _buildPetCard(context, pet);
      },
    );
  }

  Widget _buildPetCard(BuildContext context, Pet pet) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 반려동물 정보 + AI 분석 버튼
          Row(
            children: [
              _buildPetAvatar(context, pet),
              SizedBox(width: 12.w),
              Expanded(child: _buildPetInfo(context, pet)),
              _buildAnalysisButton(context),
            ],
          ),
          SizedBox(height: 12.h),
          // 주간 스트릭 바
          _buildWeeklyStreak(context),
        ],
      ),
    );
  }

  Widget _buildPetAvatar(BuildContext context, Pet pet) {
    return Stack(
      children: [
        Container(
          width: 56.w,
          height: 56.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.25),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: pet.avatarUrl != null && pet.avatarUrl!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    pet.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultPetIcon(),
                  ),
                )
              : _defaultPetIcon(),
        ),
        // 감정 이모지 오버레이
        Positioned(
          bottom: 0,
          right: 0,
          child: BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
            builder: (context, state) {
              final emoji = _getLatestEmotionEmoji(state);
              return Container(
                width: 22.w,
                height: 22.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                ),
                child: Center(
                  child: Text(emoji, style: TextStyle(fontSize: 11.sp)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _defaultPetIcon() {
    return const Center(
      child: Text('🐾', style: TextStyle(fontSize: 24)),
    );
  }

  Widget _buildPetInfo(BuildContext context, Pet pet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pet.name,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          '${pet.typeDisplayName} · ${pet.displayAge}',
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: 6.h),
        // 감정 한 줄 요약
        BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
          builder: (context, state) {
            final summary = _getEmotionSummary(state);
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                summary,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnalysisButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/emotion'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppTheme.highlightColor,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: AppTheme.highlightColor.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🧠', style: TextStyle(fontSize: 20.sp)),
            SizedBox(height: 4.h),
            Text(
              'AI\n분석',
              style: TextStyle(
                fontSize: 9.sp,
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyStreak(BuildContext context) {
    return BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
      builder: (context, state) {
        final weekDays = _getWeekAnalysisDays(state);
        final streak = _calculateStreak(state);
        final dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  streak > 0 ? '🔥 $streak일 연속 분석 중!' : '오늘 감정 분석해볼까요?',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/emotion/history'),
                  child: Text(
                    '기록 보기 >',
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: List.generate(7, (i) {
                final isAnalyzed = weekDays[i];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2.w),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 200 + i * 50),
                          height: 28.h,
                          decoration: BoxDecoration(
                            color: isAnalyzed
                                ? AppTheme.highlightColor
                                : Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Center(
                            child: Text(
                              isAnalyzed ? '✓' : '',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          dayLabels[i],
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
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

  /// 이번 주 월~일 분석 여부 (7개 bool)
  List<bool> _getWeekAnalysisDays(EmotionAnalysisState state) {
    final now = DateTime.now();
    // 이번 주 월요일 0시
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final mondayDate = DateTime(monday.year, monday.month, monday.day);

    final analyzedDates = <DateTime>{};
    if (state is EmotionAnalysisHistoryLoaded) {
      for (final a in state.history) {
        final d = a.analyzedAt;
        final dateOnly = DateTime(d.year, d.month, d.day);
        analyzedDates.add(dateOnly);
      }
    }

    return List.generate(7, (i) {
      final day = mondayDate.add(Duration(days: i));
      return analyzedDates.contains(day);
    });
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

  String _getLatestEmotionEmoji(EmotionAnalysisState state) {
    if (state is EmotionAnalysisHistoryLoaded && state.history.isNotEmpty) {
      return AppTheme.getEmotionEmoji(state.history.first.emotions.dominantEmotion);
    }
    return '🐾';
  }

  String _getEmotionSummary(EmotionAnalysisState state) {
    if (state is EmotionAnalysisHistoryLoaded && state.history.isNotEmpty) {
      final top = state.history.first.emotions.dominantEmotion;
      final map = {
        'happiness': '오늘 행복해 보여요 😊',
        'calm': '오늘 편안해 보여요 😌',
        'excitement': '오늘 신나 보여요 🎉',
        'curiosity': '궁금한 게 많아요 🤔',
        'anxiety': '불안해 보여요 😰',
        'fear': '무서워하는 것 같아요 😨',
        'sadness': '조금 슬퍼 보여요 😢',
        'discomfort': '불편해 보여요 😣',
      };
      return map[top] ?? '분석 결과 확인하기';
    }
    return '오늘 AI 분석 해볼까요?';
  }
}
