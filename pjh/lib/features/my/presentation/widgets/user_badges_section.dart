import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../social/domain/repositories/social_repository.dart';

class BadgeDefinition {
  final String id;
  final IconData icon; // v2: 이모지 → 아이콘 단일 체계
  final String name;
  final String desc;
  final Color color;

  const BadgeDefinition({
    required this.id,
    required this.icon,
    required this.name,
    required this.desc,
    required this.color,
  });
}

class UserBadgesSection extends StatefulWidget {
  final String userId;
  const UserBadgesSection({super.key, required this.userId});

  @override
  State<UserBadgesSection> createState() => _UserBadgesSectionState();
}

class _UserBadgesSectionState extends State<UserBadgesSection> {
  static const _allBadges = [
    BadgeDefinition(
      id: 'first_analysis',
      icon: Icons.emoji_events_outlined,
      name: '첫 분석',
      desc: '처음으로 AI 감정 분석 완료',
      color: AppTheme.tilePastelGreen,
    ),
    BadgeDefinition(
      id: 'health_lover',
      icon: Icons.favorite_outline,
      name: '건강왕',
      desc: '건강 기록 10개 달성',
      color: AppTheme.tilePastelPeach,
    ),
    BadgeDefinition(
      id: 'streak_7',
      icon: Icons.star_outline_rounded,
      name: '7일 연속',
      desc: '7일 연속 감정 분석',
      color: AppTheme.tilePastelBlue,
    ),
    BadgeDefinition(
      id: 'social_10',
      icon: Icons.chat_bubble_outline,
      name: '커뮤니티스타',
      desc: '댓글 10개 이상 작성',
      color: AppTheme.tilePastelPink,
    ),
    BadgeDefinition(
      id: 'level_up',
      icon: Icons.spa_outlined,
      name: '레벨업',
      desc: '레벨 5 달성',
      color: AppTheme.tilePastelMint,
    ),
    BadgeDefinition(
      id: 'level_10',
      icon: Icons.military_tech_outlined,
      name: '레벨 10',
      desc: '레벨 10 달성',
      color: AppTheme.tilePastelLavender,
    ),
    BadgeDefinition(
      id: 'mbti_explorer',
      icon: Icons.psychology_outlined,
      name: '성격 탐구가',
      desc: '처음으로 반려동물 MBTI 검사 완료',
      color: AppTheme.tilePastelPurple,
    ),
  ];

  Set<String> _earnedIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    final result =
        await sl<SocialRepository>().getEarnedBadgeIds(widget.userId);
    if (!mounted) return;
    result.fold(
      (failure) {
        dev.log('뱃지 로드 실패: ${failure.message}', name: 'UserBadges');
        setState(() => _loading = false);
      },
      (ids) => setState(() {
        _earnedIds = ids;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border:
            Border(bottom: BorderSide(color: AppTheme.dividerColor, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('활동한 뱃지',
              style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryTextColor)), // v2-review: 888888 근사
          SizedBox(height: 10.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _allBadges.asMap().entries.map((entry) {
                final i = entry.key;
                final badge = entry.value;
                final isEarned = _earnedIds.contains(badge.id);
                return Padding(
                  padding: EdgeInsets.only(right: i < _allBadges.length - 1 ? 16.w : 0),
                  child: GestureDetector(
                    onTap: () => _showBadgeDetail(context, badge, isEarned),
                    child: Column(
                      children: [
                        Opacity(
                          opacity: isEarned ? 1.0 : 0.3,
                          child: Container(
                            width: 48.w,
                            height: 48.w,
                            decoration: BoxDecoration(
                              color: isEarned ? badge.color : AppTheme.tilePastelSand,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(badge.icon,
                                  size: 22.sp, color: AppTheme.brandDeep),
                            ),
                          ),
                        ),
                        SizedBox(height: 5.h),
                        SizedBox(
                          width: 48.w,
                          child: Text(badge.name,
                              style: TextStyle(
                                  fontSize: 10.sp, color: AppTheme.secondaryTextColor), // v2-review: 666666 근사
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showBadgeDetail(
      BuildContext context, BadgeDefinition badge, bool isEarned) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: EdgeInsets.all(16.w),
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badge.icon, size: 52.sp, color: AppTheme.brandDeep),
            SizedBox(height: 12.h),
            Text(badge.name,
                style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: isEarned
                        ? AppTheme.primaryTextColor
                        : AppTheme.lightTextColor)),
            SizedBox(height: 6.h),
            Text(badge.desc,
                style: TextStyle(
                    fontSize: 13.sp, color: AppTheme.secondaryTextColor),
                textAlign: TextAlign.center),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isEarned
                    ? badge.color
                    : AppTheme.subtleBackground,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                isEarned ? '✅ 획득 완료' : '🔒 아직 미획득',
                style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: isEarned
                        ? AppTheme.primaryTextColor
                        : AppTheme.secondaryTextColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 뱃지 획득 처리 유틸리티
class BadgeAwarder {
  static Future<void> checkAndAward(String userId) async {
    final result = await sl<SocialRepository>().checkAndAwardBadges(userId);
    result.fold(
      (failure) => dev.log('뱃지 체크 실패: ${failure.message}',
          name: 'BadgeAwarder'),
      (_) {},
    );
  }
}
