import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../config/injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../social/domain/entities/post.dart';
import '../../../social/presentation/bloc/feed_bloc.dart';
import '../../../social/presentation/bloc/feed_event.dart';
import '../../../social/presentation/bloc/feed_state.dart';
import '../../domain/entities/emotion_analysis.dart';
import '../../domain/repositories/emotion_repository.dart';
import '../../data/services/emotion_insights_service.dart';
import '../../data/services/emotion_diary_service.dart';
import '../bloc/emotion_analysis_bloc.dart';
import '../widgets/emotion_radar_chart.dart';


part 'emotion_result_hero.dart';
part 'emotion_result_distribution.dart';
part 'emotion_result_stress.dart';
part 'emotion_result_insights.dart';
part 'emotion_result_social.dart';
part 'emotion_result_memo.dart';

class EmotionResultPage extends StatefulWidget {
  final EmotionAnalysis analysis;
  final List<String> imagePaths;

  const EmotionResultPage({
    super.key,
    required this.analysis,
    this.imagePaths = const [],
  });

  @override
  State<EmotionResultPage> createState() => _EmotionResultPageState();
}

class _EmotionResultPageState extends State<EmotionResultPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _memoController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // 더보기 모드: none / radar / facial
  _ChartMode _chartMode = _ChartMode.none;

  // A-5: 이전 분석 비교
  EmotionAnalysis? _previousAnalysis;
  bool _historyLoaded = false;

  // B그룹: 히스토리 기반
  EmotionInsights _insights = EmotionInsights.empty;
  List<EmotionAnalysis> _fullHistory = [];

  // B-4: AI 일기
  String? _diaryText;
  bool _diaryLoading = false;

  // C-1: 멀티펫 비교
  List<EmotionAnalysis> _otherPetAnalyses = [];

  // C-2: 커뮤니티 벤치마크
  Map<String, dynamic>? _breedAverage;

  // 스트레스 더보기
  bool _showStressDetail = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadPreviousAnalysis();
    _loadMultiPetData();
    _loadBreedAverage();
  }

  Future<void> _loadPreviousAnalysis() async {
    if (widget.analysis.petId == null) {
      // 펫 없이 분석해도 현재 분석은 히스토리에 포함
      _fullHistory = [widget.analysis];
      setState(() => _historyLoaded = true);
      return;
    }
    try {
      final repo = sl<EmotionRepository>();
      // 히스토리를 더 많이 가져와서 B그룹 인사이트에도 활용
      final result = await repo.getAnalysisHistory(
        userId: widget.analysis.userId,
        petId: widget.analysis.petId,
        limit: 20,
      );
      result.fold(
        (_) {
          // 실패해도 현재 분석은 포함
          _fullHistory = [widget.analysis];
        },
        (history) {
          // 현재 분석이 히스토리에 아직 없으면 추가
          final hasCurrentAnalysis = history.any((a) => a.id == widget.analysis.id);
          if (!hasCurrentAnalysis) {
            _fullHistory = [widget.analysis, ...history];
          } else {
            _fullHistory = history;
          }
          // A-5: 이전 분석 찾기
          final prev = _fullHistory.where((a) => a.id != widget.analysis.id).toList();
          if (prev.isNotEmpty) {
            _previousAnalysis = prev.first;
          }
          // B-1, B-3: 인사이트 계산
          if (_fullHistory.length >= 3) {
            final service = EmotionInsightsService();
            _insights = service.calculate(_fullHistory);
          }
        },
      );
    } catch (_) {
      _fullHistory = [widget.analysis];
    }
    if (mounted) setState(() => _historyLoaded = true);
  }

  Future<void> _loadMultiPetData() async {
    try {
      final repo = sl<EmotionRepository>();
      // 같은 유저의 모든 펫 히스토리에서 최근 1건씩
      final result = await repo.getAnalysisHistory(
        userId: widget.analysis.userId,
        limit: 50,
      );
      result.fold((_) {}, (history) {
        // 다른 펫들의 최근 분석만 추출
        final seen = <String>{};
        final others = <EmotionAnalysis>[];
        for (final a in history) {
          if (a.petId != null &&
              a.petId != widget.analysis.petId &&
              !seen.contains(a.petId)) {
            seen.add(a.petId!);
            others.add(a);
          }
        }
        if (mounted && others.isNotEmpty) {
          setState(() => _otherPetAnalyses = others);
        }
      });
    } catch (_) {}
  }

  Future<void> _loadBreedAverage() async {
    // breed 정보가 있어야 커뮤니티 벤치마크 가능
    // petId로 펫 정보 조회해서 breed 가져오기
    if (widget.analysis.petId == null) return;
    try {
      final repo = sl<EmotionRepository>();
      final petResult = await repo.getPetById(widget.analysis.petId!);
      petResult.fold((_) {}, (pet) async {
        if (pet.breed == null || pet.breed!.isEmpty) return;
        final avgResult = await repo.getBreedAverage(breed: pet.breed!);
        avgResult.fold((_) {}, (avg) {
          if (mounted && (avg['count'] as num? ?? 0) > 0) {
            setState(() => _breedAverage = avg);
          }
        });
      });
    } catch (_) {}
  }

  Future<void> _generateDiary() async {
    if (_diaryLoading || _fullHistory.isEmpty) return;
    setState(() => _diaryLoading = true);
    try {
      // 이번 주(월~일) 데이터만 필터링
      final now = DateTime.now();
      final weekday = now.weekday; // 1=월 ~ 7=일
      final mondayOfThisWeek = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: weekday - 1));
      final weekHistory = _fullHistory
          .where((a) => a.analyzedAt.isAfter(mondayOfThisWeek) ||
              a.analyzedAt.isAtSameMomentAs(mondayOfThisWeek))
          .toList();

      final service = EmotionDiaryService();
      final text = await service.generateDiary(
        weekHistory.isNotEmpty ? weekHistory : _fullHistory.take(3).toList(),
      );
      if (mounted) {
        setState(() {
          _diaryText = text;
          _diaryLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _diaryLoading = false);
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dominant = widget.analysis.emotions.dominantEmotion;
    final dominantName = _getEmotionName(dominant);
    final dominantIcon = _getEmotionIcon(dominant);
    final dominantValue = _getEmotionValue(dominant);
    final emotionColor = AppTheme.getEmotionColor(dominant);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(dominantIcon, dominantName, emotionColor),
      body: BlocListener<EmotionAnalysisBloc, EmotionAnalysisState>(
        listener: (context, state) {
          if (state is EmotionAnalysisSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('분석 결과가 저장되었습니다.')),
            );
            Navigator.of(context).pop();
          } else if (state is EmotionAnalysisError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: Column(
          children: [
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
                  child: Column(
                    children: [
                      // 1. HeroCard
                      _buildHeroCard(dominant, dominantName, dominantIcon,
                          dominantValue, emotionColor),
                      SizedBox(height: 14.h),

                      // 2. 이전 분석 대비
                      _buildDeltaCard(),
                      // 3. 오늘의 추천
                      _buildRecommendCard(dominant, emotionColor),
                      SizedBox(height: 14.h),
                      // 4. 감정 분포
                      _buildEmotionDistributionCard(),
                      SizedBox(height: 14.h),
                      // 5. 스트레스 지수
                      _buildStressCard(),
                      SizedBox(height: 14.h),
                      // 6. 이번주 감정 일기
                      _buildDiaryCard(),
                      // 7. 건강 체크 알림
                      _buildHealthTipsCard(),
                      // 8. 웰빙 점수
                      _buildWellbeingCard(),
                      // 9. 감정 안정성
                      _buildStabilityCard(),
                      // 10. 멀티펫 비교
                      _buildMultiPetCard(),
                      // 11. 커뮤니티 벤치마크
                      _buildCommunityCard(),
                      // 12. 메모
                      _buildMemoCard(),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      IconData icon, String name, Color emotionColor) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black87),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        '종합 분석 결과',
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryTextColor,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.black87),
          onPressed: _shareResult,
        ),
      ],
    );
  }

  // ── 1. 상단: 사진 + 주감정 ──
  void _saveAnalysis() {
    context.read<EmotionAnalysisBloc>().add(
          SaveAnalysisRequested(
            memo: _memoController.text.trim(),
          ),
        );
  }

  // ─── 피드 공유 ───────────────────────────────────────────────────────────
  void _showShareToFeedSheet(BuildContext context) {
    final captionController = TextEditingController();
    final List<String> defaultTags = ['반려동물감정분석', 'AI분석', '펫스페이스'];
    final selectedTags = List<String>.from(defaultTags);

    final dominant = widget.analysis.emotions.dominantEmotion;
    final dominantName = _getEmotionNameForShare(dominant);
    final dominantPct = (_getEmotionValueForShare(dominant) * 100).toInt();

    captionController.text = '$dominantName $dominantPct% 🐾 AI 감정 분석 결과를 공유합니다';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => BlocListener<FeedBloc, FeedState>(
        listener: (ctx, state) {
          if (state is FeedPostCreated) {
            Navigator.pop(sheetContext);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('피드에 공유되었습니다 🎉'),
                action: SnackBarAction(
                  label: '피드 보기',
                  onPressed: () => context.go('/feed'),
                ),
              ),
            );
          } else if (state is FeedError) {
            ScaffoldMessenger.of(sheetContext).showSnackBar(
              SnackBar(content: Text('공유 실패: ${state.message}')),
            );
          }
        },
        child: Padding(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24.h,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 핸들
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                Text('피드에 공유',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 16.h),

                // 감정 미리보기 카드
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.psychology, color: AppTheme.primaryColor, size: 28.w),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI 감정 분석 결과 첨부됨',
                                style: TextStyle(fontSize: 12.sp, color: AppTheme.secondaryTextColor)),
                            Text(
                              '$dominantName $dominantPct% · 신뢰도 ${(widget.analysis.confidence * 100).toInt()}%',
                              style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),

                // 캡션
                TextField(
                  controller: captionController,
                  maxLines: 3,
                  style: TextStyle(fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: '한 마디를 적어주세요...',
                    hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    contentPadding: EdgeInsets.all(14.w),
                  ),
                ),
                SizedBox(height: 16.h),

                // 게시 버튼
                BlocBuilder<FeedBloc, FeedState>(
                  builder: (ctx, state) {
                    final isPosting = state is FeedLoading;
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isPosting ? null : () => _postToFeed(ctx, captionController.text.trim(), selectedTags),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r)),
                          elevation: 0,
                        ),
                        child: isPosting
                            ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text('피드에 올리기',
                                style: TextStyle(
                                    fontSize: 15.sp, fontWeight: FontWeight.w600)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _postToFeed(BuildContext ctx, String caption, List<String> tags) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final post = Post(
      id: '',
      authorId: authState.user.uid,
      authorName: authState.user.displayName ?? '사용자',
      authorProfileImage: authState.user.photoURL,
      type: PostType.emotionAnalysis,
      content: caption.isEmpty ? null : caption,
      imageUrls: widget.analysis.imageUrl.isNotEmpty ? [widget.analysis.imageUrl] : [],
      emotionAnalysis: widget.analysis,
      tags: tags,
      createdAt: DateTime.now(),
    );

    ctx.read<FeedBloc>().add(CreatePostRequested(post: post));
  }

  String _getEmotionNameForShare(String emotion) {
    const map = {
      'happiness': '기쁨',
      'sadness': '슬픔',
      'anxiety': '불안',
      'sleepiness': '졸림',
      'curiosity': '호기심',
    };
    return map[emotion] ?? '알 수 없음';
  }

  double _getEmotionValueForShare(String emotion) {
    final e = widget.analysis.emotions;
    switch (emotion) {
      case 'happiness': return e.happiness;
      case 'sadness': return e.sadness;
      case 'anxiety': return e.anxiety;
      case 'sleepiness': return e.sleepiness;
      case 'curiosity': return e.curiosity;
      default: return 0.0;
    }
  }

    Future<void> _shareResult() async {
    try {
      final dominant = widget.analysis.emotions.dominantEmotion;
      final value = _getEmotionValue(dominant);
      final name = _getEmotionName(dominant);
      final stress = widget.analysis.emotions.stressLevel;

      final text = '''
펫스페이스 AI 종합 분석 결과

주요 감정: $name (${(value * 100).toInt()}%)
스트레스 지수: $stress/100
분석 시간: ${_formatDateTime(widget.analysis.analyzedAt)}

기쁨: ${(widget.analysis.emotions.happiness * 100).toInt()}%
슬픔: ${(widget.analysis.emotions.sadness * 100).toInt()}%
불안: ${(widget.analysis.emotions.anxiety * 100).toInt()}%
졸림: ${(widget.analysis.emotions.sleepiness * 100).toInt()}%
호기심: ${(widget.analysis.emotions.curiosity * 100).toInt()}%

#펫스페이스 #반려동물감정분석 #AI분석
''';

      if (widget.imagePaths.isNotEmpty) {
        await Share.shareXFiles(
          [XFile(widget.imagePaths.first)],
          text: text,
          subject: '반려동물 AI 종합 분석 결과',
        );
      } else {
        await Share.share(text, subject: '반려동물 AI 종합 분석 결과');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공유 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // ── 헬퍼 ──

  String _formatDateTime(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  double _getEmotionValue(String emotion) {
    switch (emotion) {
      case 'happiness': return widget.analysis.emotions.happiness;
      case 'sadness':   return widget.analysis.emotions.sadness;
      case 'anxiety':   return widget.analysis.emotions.anxiety;
      case 'sleepiness':return widget.analysis.emotions.sleepiness;
      case 'curiosity': return widget.analysis.emotions.curiosity;
      default: return 0.0;
    }
  }

  String _getEmotionName(String emotion) {
    switch (emotion) {
      case 'happiness': return '기쁨';
      case 'sadness':   return '슬픔';
      case 'anxiety':   return '불안';
      case 'sleepiness':return '졸림';
      case 'curiosity': return '호기심';
      default: return '알 수 없음';
    }
  }

  IconData _getEmotionIcon(String emotion) {
    switch (emotion) {
      case 'happiness': return Icons.sentiment_very_satisfied;
      case 'sadness':   return Icons.sentiment_very_dissatisfied;
      case 'anxiety':   return Icons.psychology_alt;
      case 'sleepiness':return Icons.bedtime;
      case 'curiosity': return Icons.explore;
      default: return Icons.pets;
    }
  }

  String _getShortDescription(String emotion) {
    switch (emotion) {
      case 'happiness': return '지금 이 순간, 아이가 행복해 보여요!';
      case 'sadness':   return '오늘은 조금 기운이 없어 보이네요.';
      case 'anxiety':   return '살짝 긴장하고 있는 것 같아요. 안심시켜 주세요.';
      case 'sleepiness':return '스르르 졸음이 오고 있어요. 편히 쉬게 해주세요.';
      case 'curiosity': return '무언가에 호기심이 가득한 눈빛이에요!';
      default: return '오늘 아이의 상태를 확인했어요';
    }
  }

  _Recommendation _getSingleRecommendation(String emotion) {
    switch (emotion) {
      case 'happiness':
        return _Recommendation(
          icon: Icons.sports_tennis,
          title: '함께 놀아주세요',
          body: '지금이 함께 산책하거나 좋아하는 놀이를 즐기기에 가장 좋은 타이밍이에요!',
        );
      case 'curiosity':
        return _Recommendation(
          icon: Icons.extension,
          title: '탐색 시간을 주세요',
          body: '새로운 장난감이나 안전한 공간을 탐색하게 해주면 자연스러운 호기심을 충족할 수 있어요.',
        );
      case 'anxiety':
        return _Recommendation(
          icon: Icons.spa,
          title: '조용히 곁에 있어주세요',
          body: '부드러운 목소리와 가벼운 스킨십으로 안심감을 전달해 주세요.',
        );
      case 'sadness':
        return _Recommendation(
          icon: Icons.favorite,
          title: '따뜻한 스킨십이 필요해요',
          body: '좋아하는 간식이나 장난감으로 기분 전환을 도와주세요.',
        );
      case 'sleepiness':
        return _Recommendation(
          icon: Icons.hotel,
          title: '편안한 잠자리를 만들어주세요',
          body: '따뜻하고 조용한 공간에서 충분히 쉬게 해주세요.',
        );
      default:
        return _Recommendation(
          icon: Icons.pets,
          title: '오늘도 잘 보살펴주세요',
          body: '반려동물의 상태를 꾸준히 관찰하고 기록하면 건강 변화를 빠르게 파악할 수 있어요.',
        );
    }
  }
}

enum _ChartMode { none, radar, facial }

class _Recommendation {
  final IconData icon;
  final String title;
  final String body;
  _Recommendation({required this.icon, required this.title, required this.body});
}
