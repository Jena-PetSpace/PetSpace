import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';

class BadgeDefinition {
  final String id;
  final String emoji;
  final String name;
  final String desc;
  final Color color;

  const BadgeDefinition({
    required this.id,
    required this.emoji,
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
    BadgeDefinition(id: 'first_analysis', emoji: '🏆', name: '첫 분석', desc: '처음으로 AI 감정 분석 완료', color: Color(0xFFFF9800)),
    BadgeDefinition(id: 'streak_7', emoji: '🔥', name: '7일 연속', desc: '7일 연속 감정 분석', color: Color(0xFFE53935)),
    BadgeDefinition(id: 'streak_30', emoji: '⚡', name: '30일 연속', desc: '30일 연속 감정 분석', color: Color(0xFF9C27B0)),
    BadgeDefinition(id: 'pet_owner', emoji: '⭐', name: '견주/집사', desc: '반려동물 프로필 등록', color: Color(0xFF0077B6)),
    BadgeDefinition(id: 'social_10', emoji: '💬', name: '소통왕', desc: '댓글 10개 이상 작성', color: Color(0xFF4CAF50)),
    BadgeDefinition(id: 'post_10', emoji: '📸', name: '포토그래퍼', desc: '게시글 10개 이상 작성', color: Color(0xFF1E3A5F)),
  ];

  Set<String> _earnedIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    try {
      final res = await Supabase.instance.client
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', widget.userId);
      if (mounted) {
        setState(() {
          _earnedIds = Set<String>.from(
            (res as List).map((r) => r['badge_id'] as String),
          );
          _loading = false;
        });
      }
    } catch (e) {
      dev.log('뱃지 로드 실패: $e', name: 'UserBadges');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_earnedIds.isEmpty) return const SizedBox.shrink();

    final earned = _allBadges.where((b) => _earnedIds.contains(b.id)).toList();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: Row(
              children: [
                Text('🏅', style: TextStyle(fontSize: 14.sp)),
                SizedBox(width: 6.w),
                Text(
                  '획득한 뱃지',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppTheme.highlightColor,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    '${earned.length}/${_allBadges.length}',
                    style: TextStyle(fontSize: 9.sp, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: _allBadges.map((badge) {
              final isEarned = _earnedIds.contains(badge.id);
              return GestureDetector(
                onTap: () => _showBadgeDetail(context, badge, isEarned),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 54.w,
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: isEarned
                        ? badge.color.withValues(alpha: 0.1)
                        : AppTheme.subtleBackground,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isEarned
                          ? badge.color.withValues(alpha: 0.4)
                          : AppTheme.dividerColor,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        badge.emoji,
                        style: TextStyle(
                          fontSize: 22.sp,
                          color: isEarned ? null : const Color(0xFFBDBDBD),
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        badge.name,
                        style: TextStyle(
                          fontSize: 8.sp,
                          color: isEarned
                              ? badge.color
                              : AppTheme.lightTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.emoji, style: TextStyle(fontSize: 52.sp)),
            SizedBox(height: 12.h),
            Text(
              badge.name,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: isEarned ? badge.color : AppTheme.lightTextColor,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              badge.desc,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isEarned
                    ? badge.color.withValues(alpha: 0.1)
                    : AppTheme.subtleBackground,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                isEarned ? '✅ 획득 완료' : '🔒 아직 미획득',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: isEarned ? badge.color : AppTheme.secondaryTextColor,
                ),
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
    final client = Supabase.instance.client;
    try {
      // 기존 뱃지 조회
      final existing = await client
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', userId);
      final earnedIds = Set<String>.from(
          (existing as List).map((r) => r['badge_id'] as String));

      final toAward = <String>[];

      // 반려동물 등록 여부
      if (!earnedIds.contains('pet_owner')) {
        final pets = await client.from('pets').select('id').eq('user_id', userId).limit(1);
        if ((pets as List).isNotEmpty) toAward.add('pet_owner');
      }

      // 감정 분석 첫 번째
      if (!earnedIds.contains('first_analysis')) {
        final analyses = await client.from('emotion_analyses').select('id').eq('user_id', userId).limit(1);
        if ((analyses as List).isNotEmpty) toAward.add('first_analysis');
      }

      // 게시글 10개
      if (!earnedIds.contains('post_10')) {
        final posts = await client.from('posts').select('id').eq('author_id', userId);
        if ((posts as List).length >= 10) toAward.add('post_10');
      }

      // 배치 저장
      if (toAward.isNotEmpty) {
        await client.from('user_badges').insert(
          toAward.map((id) => {
            'user_id': userId,
            'badge_id': id,
            'earned_at': DateTime.now().toIso8601String(),
          }).toList(),
        );
      }
    } catch (e) {
      dev.log('뱃지 체크 실패: $e', name: 'BadgeAwarder');
    }
  }
}
