import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../social/domain/repositories/social_repository.dart';

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
  final ValueNotifier<int>? checkNotifier;

  const HomeQuestCard({super.key, this.checkNotifier});

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
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadQuestStatus();
    _loadPoints();
    widget.checkNotifier?.addListener(_onCheckNotified);
  }

  @override
  void dispose() {
    widget.checkNotifier?.removeListener(_onCheckNotified);
    super.dispose();
  }

  void _onCheckNotified() {
    _verifyAllPendingQuests();
  }

  /// 홈 복귀 시 아직 완료 안 된 퀘스트들을 일괄 DB 검증
  Future<void> _verifyAllPendingQuests() async {
    for (final quest in _quests) {
      if (_completed[quest.id] == true) continue;
      await _verifyAndComplete(quest);
    }
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
    final result = await sl<SocialRepository>().getUserPoints(auth.user.uid);
    if (!mounted) return;
    result.fold(
      (failure) =>
          dev.log('포인트 조회 실패: ${failure.message}', name: 'QuestCard'),
      (balance) => setState(() => _totalPoints = balance),
    );
  }

  /// 퀘스트 탭 → 해당 페이지로 이동 (복귀 시 GoRouter listener가 _verifyAllPendingQuests 호출)
  void _onQuestTap(_Quest quest) {
    context.push(quest.route);
  }

  /// DB에서 오늘 실제 수행 여부 확인 후 포인트 지급
  Future<void> _verifyAndComplete(_Quest quest) async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;

    final uid = auth.user.uid;
    final repo = sl<SocialRepository>();

    final activityResult = await repo.hasQuestActivityToday(
        userId: uid, questType: quest.id);
    final achieved = activityResult.fold((_) => false, (v) => v);
    if (!achieved || !mounted) return;

    // 이미 완료 처리된 경우 skip (SharedPreferences 기준)
    final prefs = await SharedPreferences.getInstance();
    final key = 'quest_${quest.id}_${_todayKey()}';
    if (prefs.getBool(key) == true) return;

    await prefs.setBool(key, true);

    final incrementResult = await repo.incrementUserPoints(
        userId: uid, points: quest.points);
    incrementResult.fold(
      (failure) =>
          dev.log('포인트 지급 실패: ${failure.message}', name: 'QuestCard'),
      (_) {},
    );

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
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더 (탭으로 접기/펼치기)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: _isExpanded
                    ? BorderRadius.vertical(top: Radius.circular(16.r))
                    : BorderRadius.circular(16.r),
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
                  SizedBox(width: 8.w),
                  // 접기/펼치기 아이콘
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      key: ValueKey(_isExpanded),
                      size: 22.w,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 접기/펼치기 영역
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            secondChild: const SizedBox.shrink(),
            firstChild: Column(
              children: [
                const Divider(height: 1, thickness: 1, color: AppTheme.dividerColor),
                // 퀘스트 목록
                Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 12.h),
                  child: Column(
                    children: _quests.map((quest) {
                      final done = _completed[quest.id] == true;
                      return GestureDetector(
                        onTap: done ? null : () => _onQuestTap(quest),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(bottom: 8.h),
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
          ),
        ],
      ),
    );
  }
}
