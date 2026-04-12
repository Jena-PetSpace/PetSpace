import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class _Quest {
  final String id;
  final String title;
  final String desc;
  final String emoji;
  final int points;
  final String route;

  const _Quest({
    required this.id,
    required this.title,
    required this.desc,
    required this.emoji,
    required this.points,
    required this.route,
  });
}

class HomeQuestCard extends StatefulWidget {
  const HomeQuestCard({super.key});

  @override
  State<HomeQuestCard> createState() => _HomeQuestCardState();
}

class _HomeQuestCardState extends State<HomeQuestCard> {
  static const List<_Quest> _quests = [
    _Quest(
      id: 'analyze',
      title: 'AI 감정 분석',
      desc: '오늘 반려동물 감정을 분석해요',
      emoji: '🧠',
      points: 30,
      route: '/emotion',
    ),
    _Quest(
      id: 'post',
      title: '게시글 작성',
      desc: '일상을 커뮤니티에 공유해요',
      emoji: '✍️',
      points: 20,
      route: '/feed',
    ),
    _Quest(
      id: 'like',
      title: '게시글 좋아요',
      desc: '다른 반려동물 이야기에 공감해요',
      emoji: '❤️',
      points: 10,
      route: '/feed',
    ),
  ];

  Map<String, bool> _completed = {};
  int _totalPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadQuestStatus();
    _loadPoints();
  }

  Future<void> _loadQuestStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final Map<String, bool> status = {};
    for (final q in _quests) {
      status[q.id] = prefs.getBool('quest_${q.id}_$today') ?? false;
    }
    if (mounted) setState(() => _completed = status);
  }

  Future<void> _loadPoints() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    try {
      final res = await Supabase.instance.client
          .from('user_points')
          .select('balance')
          .eq('user_id', auth.user.uid)
          .maybeSingle();
      if (mounted && res != null) {
        setState(() => _totalPoints = res['balance'] as int? ?? 0);
      }
    } catch (e) {
      dev.log('포인트 조회 실패: $e', name: 'QuestCard');
    }
  }

  /// 퀘스트 탭 → 페이지 이동 후 실제 수행 여부를 DB로 검증
  Future<void> _onQuestTap(_Quest quest) async {
    await context.push(quest.route);
    if (!mounted) return;
    // 페이지에서 돌아오면 실제 완료 여부 검증
    await _verifyAndComplete(quest);
  }

  /// DB에서 오늘 실제 수행 여부 확인 후 포인트 지급
  Future<void> _verifyAndComplete(_Quest quest) async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    final uid = auth.user.uid;
    final supabase = Supabase.instance.client;
    final todayStart = DateTime.now().copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);

    bool achieved = false;
    try {
      switch (quest.id) {
        case 'analyze':
          // 오늘 감정 분석 기록이 있는지 확인
          final rows = await supabase
              .from('emotion_history')
              .select('id')
              .eq('user_id', uid)
              .gte('created_at', todayStart.toIso8601String())
              .limit(1);
          achieved = (rows as List).isNotEmpty;
          break;
        case 'post':
          // 오늘 게시글을 작성했는지 확인
          final rows = await supabase
              .from('posts')
              .select('id')
              .eq('author_id', uid)
              .isFilter('deleted_at', null)
              .gte('created_at', todayStart.toIso8601String())
              .limit(1);
          achieved = (rows as List).isNotEmpty;
          break;
        case 'like':
          // 오늘 좋아요를 눌렀는지 확인
          final rows = await supabase
              .from('post_likes')
              .select('id')
              .eq('user_id', uid)
              .gte('created_at', todayStart.toIso8601String())
              .limit(1);
          achieved = (rows as List).isNotEmpty;
          break;
      }
    } catch (e) {
      dev.log('퀘스트 검증 실패: $e', name: 'QuestCard');
      return;
    }

    if (!achieved || !mounted) return;

    // 이미 완료 처리된 경우 skip (SharedPreferences 기준)
    final prefs = await SharedPreferences.getInstance();
    final key = 'quest_${quest.id}_${_todayKey()}';
    if (prefs.getBool(key) == true) return;

    await prefs.setBool(key, true);

    try {
      await supabase.rpc('increment_user_points', params: {
        'p_user_id': uid,
        'p_points': quest.points,
      });
    } catch (e) {
      dev.log('포인트 지급 실패: $e', name: 'QuestCard');
    }

    if (!mounted) return;
    setState(() {
      _completed[quest.id] = true;
      _totalPoints += quest.points;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${quest.emoji} +${quest.points}pt 획득!'),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  int get _completedCount => _completed.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Row(
              children: [
                Text('🎯', style: TextStyle(fontSize: 18.sp)),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘의 퀘스트',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Text(
                        '$_completedCount/${_quests.length} 완료',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // 포인트 배지
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: AppTheme.highlightColor,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    children: [
                      Text('⭐', style: TextStyle(fontSize: 12.sp)),
                      SizedBox(width: 4.w),
                      Text(
                        '$_totalPoints pt',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 진행 바
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: _quests.isEmpty ? 0 : _completedCount / _quests.length,
                backgroundColor: AppTheme.subtleBackground,
                valueColor: AlwaysStoppedAnimation<Color>(
                    _completedCount == _quests.length
                        ? AppTheme.successColor
                        : AppTheme.primaryColor),
                minHeight: 6,
              ),
            ),
          ),

          // 퀘스트 목록
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
            child: Column(
              children: _quests.map((quest) {
                final done = _completed[quest.id] == true;
                return GestureDetector(
                  onTap: done ? null : () => _onQuestTap(quest),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(bottom: 6.h),
                    padding: EdgeInsets.symmetric(
                        horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: done
                          ? AppTheme.successColor.withValues(alpha: 0.08)
                          : AppTheme.subtleBackground,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: done
                            ? AppTheme.successColor.withValues(alpha: 0.3)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(quest.emoji,
                            style: TextStyle(fontSize: 20.sp)),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quest.title,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: done
                                      ? AppTheme.successColor
                                      : AppTheme.primaryTextColor,
                                  decoration: done
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                              Text(
                                quest.desc,
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: AppTheme.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: done
                                ? AppTheme.successColor
                                : AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            done ? '완료' : '+${quest.points}pt',
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                              color: done
                                  ? Colors.white
                                  : AppTheme.primaryColor,
                            ),
                          ),
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
}
