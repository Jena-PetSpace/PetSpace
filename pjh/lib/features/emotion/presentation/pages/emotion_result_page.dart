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
import '../../domain/entities/emotion_analysis.dart';
import '../../domain/repositories/emotion_repository.dart';
import '../../data/services/emotion_insights_service.dart';
import '../../data/services/emotion_diary_service.dart';
import '../bloc/emotion_analysis_bloc.dart';
import '../widgets/emotion_radar_chart.dart';
import '../../../../core/services/image_upload_service.dart';

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
          final hasCurrentAnalysis =
              history.any((a) => a.id == widget.analysis.id);
          if (!hasCurrentAnalysis) {
            _fullHistory = [widget.analysis, ...history];
          } else {
            _fullHistory = history;
          }
          // A-5: 이전 분석 찾기
          final prev =
              _fullHistory.where((a) => a.id != widget.analysis.id).toList();
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
          .where((a) =>
              a.analyzedAt.isAfter(mondayOfThisWeek) ||
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

    captionController.text =
        '$dominantName $dominantPct% 🐾 AI 감정 분석 결과를 공유합니다';

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
                    style: TextStyle(
                        fontSize: 18.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 16.h),

                // 감정 미리보기 카드
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.psychology,
                          color: AppTheme.primaryColor, size: 28.w),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI 감정 분석 결과 첨부됨',
                                style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppTheme.secondaryTextColor)),
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
                    hintStyle:
                        TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r)),
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
                        onPressed: isPosting
                            ? null
                            : () => _postToFeed(ctx,
                                captionController.text.trim(), selectedTags),
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
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600)),
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

  Future<void> _postToFeed(
      BuildContext ctx, String caption, List<String> tags) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    // 1. 이미지 URL 결정: Supabase URL이 있으면 그대로, 없으면 로컬 파일 업로드
    String? finalImageUrl;

    if (widget.analysis.imageUrl.isNotEmpty) {
      finalImageUrl = widget.analysis.imageUrl;
    } else if (widget.imagePaths.isNotEmpty) {
      try {
        final uploadService = sl<ImageUploadService>();
        final result = await uploadService.uploadPostImage(
          File(widget.imagePaths.first),
        );
        finalImageUrl = result['url'];
      } catch (e) {
        // 업로드 실패해도 이미지 없이 게시 진행
        finalImageUrl = null;
      }
    }

    if (!mounted) return;

    final post = Post(
      id: '',
      authorId: authState.user.uid,
      authorName: authState.user.displayName,
      authorProfileImage: authState.user.photoURL,
      type: PostType.emotionAnalysis,
      content: caption.isEmpty ? null : caption,
      imageUrls: finalImageUrl != null ? [finalImageUrl] : [],
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
      case 'happiness':
        return e.happiness;
      case 'sadness':
        return e.sadness;
      case 'anxiety':
        return e.anxiety;
      case 'sleepiness':
        return e.sleepiness;
      case 'curiosity':
        return e.curiosity;
      default:
        return 0.0;
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
      case 'happiness':
        return widget.analysis.emotions.happiness;
      case 'sadness':
        return widget.analysis.emotions.sadness;
      case 'anxiety':
        return widget.analysis.emotions.anxiety;
      case 'sleepiness':
        return widget.analysis.emotions.sleepiness;
      case 'curiosity':
        return widget.analysis.emotions.curiosity;
      default:
        return 0.0;
    }
  }

  String _getEmotionName(String emotion) {
    switch (emotion) {
      case 'happiness':
        return '기쁨';
      case 'sadness':
        return '슬픔';
      case 'anxiety':
        return '불안';
      case 'sleepiness':
        return '졸림';
      case 'curiosity':
        return '호기심';
      default:
        return '알 수 없음';
    }
  }

  IconData _getEmotionIcon(String emotion) {
    switch (emotion) {
      case 'happiness':
        return Icons.sentiment_very_satisfied;
      case 'sadness':
        return Icons.sentiment_very_dissatisfied;
      case 'anxiety':
        return Icons.psychology_alt;
      case 'sleepiness':
        return Icons.bedtime;
      case 'curiosity':
        return Icons.explore;
      default:
        return Icons.pets;
    }
  }

  String _getShortDescription(String emotion) {
    switch (emotion) {
      case 'happiness':
        return '지금 이 순간, 아이가 행복해 보여요!';
      case 'sadness':
        return '오늘은 조금 기운이 없어 보이네요.';
      case 'anxiety':
        return '살짝 긴장하고 있는 것 같아요. 안심시켜 주세요.';
      case 'sleepiness':
        return '스르르 졸음이 오고 있어요. 편히 쉬게 해주세요.';
      case 'curiosity':
        return '무언가에 호기심이 가득한 눈빛이에요!';
      default:
        return '오늘 아이의 상태를 확인했어요';
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

  // ══════════════════════════════════════════════════════════════════════════
  // Methods from emotion_result_hero.dart
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHeroCard(
      String dominant, String name, IconData icon, double value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.r),
                topRight: Radius.circular(20.r),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(icon, size: 28.w, color: Colors.white),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '주요 감정',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${(value * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                if (widget.imagePaths.isNotEmpty)
                  _buildImageThumbnails()
                else
                  Container(
                    width: 88.w,
                    height: 88.w,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(Icons.pets, size: 40.w, color: color),
                  ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 13.w, color: Colors.grey),
                          SizedBox(width: 4.w),
                          Text(
                            _formatDateTime(widget.analysis.analyzedAt),
                            style: TextStyle(
                                fontSize: 11.sp, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          _getShortDescription(dominant),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: color,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. A-5: 이전 분석 대비 카드 ──
  Widget _buildDeltaCard() {
    if (!_historyLoaded) return const SizedBox.shrink();

    if (_previousAnalysis == null) {
      // 첫 분석
      if (widget.analysis.petId == null) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(bottom: 14.h),
        child: _cardContainer(
          child: Row(
            children: [
              Icon(Icons.timeline_rounded, size: 18.w, color: Colors.grey[400]),
              SizedBox(width: 8.w),
              Text(
                '첫 분석이에요! 다음 분석부터 변화를 추적할 수 있어요.',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    final cur = widget.analysis.emotions;
    final prev = _previousAnalysis!.emotions;
    final deltas = [
      ('기쁨', cur.happiness - prev.happiness),
      ('슬픔', cur.sadness - prev.sadness),
      ('불안', cur.anxiety - prev.anxiety),
      ('졸림', cur.sleepiness - prev.sleepiness),
      ('호기심', cur.curiosity - prev.curiosity),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: _cardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이전 분석 대비 변화',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: deltas.map((d) {
                final delta = d.$2;
                final pct = (delta.abs() * 100).toInt();
                if (pct == 0) return const SizedBox.shrink();
                final isUp = delta > 0;
                return Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: (isUp ? Colors.green : Colors.red)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(d.$1,
                          style: TextStyle(
                              fontSize: 12.sp, color: Colors.grey[700])),
                      SizedBox(width: 4.w),
                      Icon(
                        isUp
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 14.w,
                        color: isUp ? Colors.green : Colors.red,
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: isUp ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 8.h),
            Text(
              '${_formatDateTime(_previousAnalysis!.analyzedAt)} 대비',
              style: TextStyle(fontSize: 10.sp, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Methods from emotion_result_distribution.dart
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEmotionDistributionCard() {
    final emotions = [
      ('happiness', '😊 기쁨', widget.analysis.emotions.happiness),
      ('sadness', '😢 슬픔', widget.analysis.emotions.sadness),
      ('anxiety', '😰 불안', widget.analysis.emotions.anxiety),
      ('sleepiness', '😴 졸림', widget.analysis.emotions.sleepiness),
      ('curiosity', '🧐 호기심', widget.analysis.emotions.curiosity),
    ];
    emotions.sort((a, b) => b.$3.compareTo(a.$3));
    final dominant = widget.analysis.emotions.dominantEmotion;
    final hasFacial = widget.analysis.emotions.facialFeatures != null &&
        widget.analysis.emotions.facialFeatures!.isNotEmpty;

    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '감정 분포',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 14.h),
          ...emotions.map((e) {
            final key = e.$1;
            final name = e.$2;
            final value = e.$3;
            final color = AppTheme.getEmotionColor(key);
            final isMain = key == dominant;

            return Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                children: [
                  SizedBox(
                    width: 64.w,
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight:
                            isMain ? FontWeight.bold : FontWeight.normal,
                        color: isMain
                            ? AppTheme.primaryTextColor
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 10.h,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5.r),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: value,
                          child: Container(
                            height: 10.h,
                            decoration: BoxDecoration(
                              color: isMain
                                  ? color
                                  : color.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  SizedBox(
                    width: 34.w,
                    child: Text(
                      '${(value * 100).toInt()}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight:
                            isMain ? FontWeight.bold : FontWeight.normal,
                        color: isMain ? color : Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 4.h),
          // 토글 버튼들
          Row(
            children: [
              Expanded(
                child: _buildToggleButton(
                  label: '감정 레이더',
                  icon: Icons.radar,
                  isActive: _chartMode == _ChartMode.radar,
                  onTap: () => setState(() => _chartMode =
                      _chartMode == _ChartMode.radar
                          ? _ChartMode.none
                          : _ChartMode.radar),
                ),
              ),
              if (hasFacial) ...[
                SizedBox(width: 8.w),
                Expanded(
                  child: _buildToggleButton(
                    label: '부위별 분석',
                    icon: Icons.visibility_outlined,
                    isActive: _chartMode == _ChartMode.facial,
                    onTap: () => setState(() => _chartMode =
                        _chartMode == _ChartMode.facial
                            ? _ChartMode.none
                            : _ChartMode.facial),
                  ),
                ),
              ],
            ],
          ),
          // 토글 콘텐츠
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _buildChartModeContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(8.r),
          border: isActive
              ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.keyboard_arrow_up : icon,
              size: 16.w,
              color: AppTheme.primaryColor,
            ),
            SizedBox(width: 4.w),
            Text(
              isActive ? '$label 접기' : label,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartModeContent() {
    switch (_chartMode) {
      case _ChartMode.radar:
        return Padding(
          padding: EdgeInsets.only(top: 56.h, bottom: 8.h),
          child: Center(
            child: EmotionRadarChart(
              emotions: widget.analysis.emotions,
              size: 180.w,
            ),
          ),
        );
      case _ChartMode.facial:
        return _buildFacialFeaturesContent();
      case _ChartMode.none:
        return const SizedBox.shrink();
    }
  }

  // A-1: 부위별 분석 콘텐츠
  Widget _buildFacialFeaturesContent() {
    final features = widget.analysis.emotions.facialFeatures;
    if (features == null || features.isEmpty) return const SizedBox.shrink();

    final partLabels = {
      'eyes': ('눈', Icons.remove_red_eye_outlined),
      'ears': ('귀', Icons.hearing_outlined),
      'mouth': ('입', Icons.mood_outlined),
      'posture': ('자세', Icons.accessibility_new_outlined),
    };

    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: Column(
        children: features.entries.map((entry) {
          final part = partLabels[entry.key];
          final label = part?.$1 ?? entry.key;
          final icon = part?.$2 ?? Icons.circle_outlined;
          final feature = entry.value;

          return Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18.w, color: AppTheme.primaryColor),
                  SizedBox(width: 10.w),
                  SizedBox(
                    width: 32.w,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      feature.state,
                      style:
                          TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                    ),
                  ),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      feature.signal,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Methods from emotion_result_stress.dart
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStressCard() {
    final stress = widget.analysis.emotions.stressLevel;
    final stressColor = stress >= 70
        ? const Color(0xFFE74C3C)
        : stress >= 40
            ? const Color(0xFFF39C12)
            : const Color(0xFF2ECC71);
    final stressLabel = stress >= 70
        ? '높음'
        : stress >= 40
            ? '보통'
            : '낮음';
    final stressDesc = stress >= 70
        ? '스트레스가 높은 상태예요. 편안한 환경과 충분한 휴식이 필요합니다.'
        : stress >= 40
            ? '약간의 긴장 상태예요. 부드러운 스킨십으로 안정시켜 주세요.'
            : '안정적인 상태예요. 지금처럼 편안한 환경을 유지해 주세요.';

    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '스트레스 지수',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: stressColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  stressLabel,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: stressColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$stress',
                style: TextStyle(
                  fontSize: 42.sp,
                  fontWeight: FontWeight.bold,
                  color: stressColor,
                  height: 1,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 6.h, left: 2.w),
                child: Text(
                  '/ 100',
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: LinearProgressIndicator(
              value: stress / 100,
              minHeight: 8.h,
              backgroundColor: Colors.grey.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(stressColor),
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: stressColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14.w, color: stressColor),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    stressDesc,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          // 더보기 토글 버튼
          InkWell(
            onTap: () => setState(() => _showStressDetail = !_showStressDetail),
            borderRadius: BorderRadius.circular(8.r),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showStressDetail
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16.w,
                    color: AppTheme.primaryColor,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    _showStressDetail ? '접기' : '관련 분석 더보기',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 더보기 콘텐츠
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showStressDetail
                ? _buildStressDetailContent(stress, stressColor)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildStressDetailContent(int stress, Color stressColor) {
    final emotions = widget.analysis.emotions;

    // 스트레스 관련 분석
    final analysisItems = <String>[];

    // 감정별 스트레스 영향 분석
    if (emotions.anxiety > 0.3) {
      analysisItems.add(
          '불안 수치가 ${(emotions.anxiety * 100).toInt()}%로 다소 높아 스트레스에 영향을 줄 수 있어요.');
    }
    if (emotions.sadness > 0.3) {
      analysisItems.add(
          '슬픔 수치가 ${(emotions.sadness * 100).toInt()}%로 감정적 피로가 누적되었을 수 있어요.');
    }
    if (emotions.happiness < 0.2) {
      analysisItems.add('기쁨 수치가 낮아 전반적인 기분 개선이 필요해 보여요.');
    }
    if (emotions.sleepiness > 0.4) {
      analysisItems.add('졸림 수치가 높아 수면 부족이나 체력 저하가 의심돼요.');
    }

    // 감정 조합 기반 심층 분석
    if (emotions.anxiety > 0.3 && emotions.sadness > 0.3) {
      analysisItems.add('불안과 슬픔이 동시에 높아요. 분리불안이나 환경 변화로 인한 복합 스트레스일 수 있어요.');
    }
    if (emotions.anxiety > 0.3 && emotions.curiosity > 0.3) {
      analysisItems.add('불안 속에서도 호기심이 있어요. 새로운 환경에 대한 경계와 탐구가 공존하는 상태예요.');
    }
    if (emotions.sleepiness > 0.3 && emotions.sadness > 0.2) {
      analysisItems.add('졸림과 슬픔이 함께 나타나요. 무기력함이나 우울 경향을 주의 깊게 관찰해 주세요.');
    }
    if (emotions.happiness > 0.5 && stress >= 40) {
      analysisItems.add('기쁨은 높지만 스트레스도 있어요. 흥분 상태로 인한 과각성일 수 있어요.');
    }

    // 스트레스 수준별 종합 판단
    if (stress >= 80) {
      analysisItems.add('스트레스 수치가 매우 높아 즉각적인 안정 조치가 필요해요.');
    } else if (stress >= 60) {
      analysisItems.add('스트레스가 경계 수준이에요. 지속되면 건강에 영향을 줄 수 있어요.');
    } else if (stress <= 20) {
      analysisItems.add('스트레스가 매우 낮아 매우 안정적인 상태예요.');
    }

    // 감정 균형도 분석
    final emotionValues = [
      emotions.happiness,
      emotions.sadness,
      emotions.anxiety,
      emotions.sleepiness,
      emotions.curiosity,
    ];
    final maxEmotion = emotionValues.reduce((a, b) => a > b ? a : b);
    final minEmotion = emotionValues.reduce((a, b) => a < b ? a : b);
    if (maxEmotion - minEmotion > 0.5) {
      analysisItems.add('감정 편차가 커요. 특정 감정에 크게 치우친 상태로 보여요.');
    } else if (maxEmotion - minEmotion < 0.15 && stress < 40) {
      analysisItems.add('감정이 고르게 분포되어 있어 심리적으로 균형 잡힌 상태예요.');
    }

    if (analysisItems.isEmpty) {
      analysisItems.add('현재 감정 상태가 비교적 안정적이에요.');
    }

    // 스트레스 수준별 행동 요령
    final tips = stress >= 70
        ? [
            '조용하고 안전한 공간으로 이동시켜 주세요',
            '과도한 자극(소음, 낯선 사람)을 줄여주세요',
            '좋아하는 간식이나 장난감으로 기분 전환을 시도하세요',
            '부드럽게 쓰다듬어 안정감을 줘주세요',
            '일시적으로 다른 동물과의 접촉을 줄여주세요',
            '차분한 목소리로 이름을 불러 안심시켜 주세요',
            '증상이 지속되면 수의사 상담을 권장합니다',
          ]
        : stress >= 40
            ? [
                '규칙적인 산책과 운동으로 에너지를 발산시켜 주세요',
                '편안한 음악이나 조명으로 환경을 안정시켜 주세요',
                '일상 루틴을 유지해 안정감을 줘주세요',
                '스킨십 시간을 늘려주세요',
                '좋아하는 놀이를 통해 긍정적 경험을 쌓아주세요',
                '충분한 수면 환경을 제공해 주세요',
              ]
            : [
                '현재 환경이 잘 맞는 것 같아요. 유지해 주세요',
                '규칙적인 식사와 산책을 계속 이어가세요',
                '긍정적인 상호작용을 꾸준히 해주세요',
                '새로운 놀이나 간식으로 즐거운 자극을 줘보세요',
                '다른 반려동물이나 사람과의 사회화도 좋아요',
              ];

    // 간식/음식 추천
    final foodTips = stress >= 70
        ? [
            '캐모마일 성분이 든 진정 간식을 줘보세요',
            '따뜻한 물에 적신 사료로 식사를 편안하게 해주세요',
            '트립토판이 풍부한 닭가슴살 간식이 안정에 도움돼요',
          ]
        : stress >= 40
            ? [
                '호박, 고구마 등 소화가 편한 간식을 줘보세요',
                '오메가3가 풍부한 연어 간식이 기분 개선에 좋아요',
                '블루베리 등 항산화 과일 간식도 추천해요',
              ]
            : [
                '좋아하는 간식으로 긍정적 보상을 해주세요',
                '수분 보충이 되는 수박, 오이 간식도 좋아요',
                '노즈워크 간식으로 두뇌 자극을 줘보세요',
              ];

    // 환경/생활 추천
    final lifeTips = stress >= 70
        ? [
            '조명을 어둡게 하고 조용한 음악을 틀어주세요',
            '익숙한 냄새가 나는 담요나 옷을 곁에 두세요',
          ]
        : stress >= 40
            ? [
                '하루 2회 이상 짧은 산책을 해보세요',
                '놀이 시간을 정해서 루틴을 만들어 주세요',
              ]
            : [
                '새로운 산책 코스를 시도해 보세요',
                '다양한 질감의 장난감으로 자극을 줘보세요',
              ];

    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 상태 분석
          _buildStressSection(
            title: '상태 분석',
            icon: Icons.analytics_outlined,
            color: stressColor,
            items: analysisItems,
          ),
          SizedBox(height: 12.h),
          // 2. 행동 요령
          _buildStressSection(
            title: '행동 요령',
            icon: Icons.directions_walk_outlined,
            color: const Color(0xFF3498DB),
            items: tips,
          ),
          SizedBox(height: 12.h),
          // 3. 간식/음식 추천
          _buildStressSection(
            title: '간식/음식 추천',
            icon: Icons.restaurant_outlined,
            color: const Color(0xFFE67E22),
            items: foodTips,
          ),
          SizedBox(height: 12.h),
          // 4. 환경/생활 추천
          _buildStressSection(
            title: '환경/생활 추천',
            icon: Icons.home_outlined,
            color: const Color(0xFF27AE60),
            items: lifeTips,
          ),
        ],
      ),
    );
  }

  Widget _buildStressSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16.w, color: color),
              SizedBox(width: 6.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ...items.map((item) => Padding(
                padding: EdgeInsets.only(bottom: 5.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 6.h),
                      width: 4.w,
                      height: 4.w,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Methods from emotion_result_insights.dart
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHealthTipsCard() {
    final tips = widget.analysis.emotions.healthTips;
    if (tips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: _cardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '건강 체크 알림',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 10.h),
            ...tips.map((tip) => Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 16.w, color: const Color(0xFF2ECC71)),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          tip,
                          style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[700],
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),
            SizedBox(height: 6.h),
            Text(
              '* AI 분석 결과로 참고용입니다. 정확한 진단은 수의사와 상담하세요.',
              style: TextStyle(fontSize: 10.sp, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  // ── C-1: 멀티펫 비교 카드 ──
  Widget _buildMultiPetCard() {
    if (_otherPetAnalyses.isEmpty) return const SizedBox.shrink();

    final cur = widget.analysis.emotions;
    final emotionNames = {
      'happiness': '기쁨',
      'sadness': '슬픔',
      'anxiety': '불안',
      'sleepiness': '졸림',
      'curiosity': '호기심'
    };

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: _cardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '다른 반려동물과 비교',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 12.h),
            ..._otherPetAnalyses.take(3).map((other) {
              final otherE = other.emotions;
              return Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '펫 ${other.petId?.substring(0, 6) ?? ""}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          ...emotionNames.entries.map((entry) {
                            final curVal =
                                _getEmotionValueByKey(cur, entry.key);
                            final otherVal =
                                _getEmotionValueByKey(otherE, entry.key);
                            final diff = curVal - otherVal;
                            if (diff.abs() < 0.05)
                              return const SizedBox.shrink();
                            return Padding(
                              padding: EdgeInsets.only(right: 8.w),
                              child: Text(
                                '${entry.value} ${diff > 0 ? "+" : ""}${(diff * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: diff > 0 ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  double _getEmotionValueByKey(EmotionScores e, String key) {
    switch (key) {
      case 'happiness':
        return e.happiness;
      case 'sadness':
        return e.sadness;
      case 'anxiety':
        return e.anxiety;
      case 'sleepiness':
        return e.sleepiness;
      case 'curiosity':
        return e.curiosity;
      default:
        return 0.0;
    }
  }

  // ── C-2: 커뮤니티 벤치마크 카드 ──
  Widget _buildCommunityCard() {
    if (_breedAverage == null) return const SizedBox.shrink();

    final avg = _breedAverage!;
    final count = (avg['count'] as num?)?.toInt() ?? 0;
    if (count == 0) return const SizedBox.shrink();

    final cur = widget.analysis.emotions;
    final comparisons = [
      ('기쁨', cur.happiness, (avg['happiness'] as num?)?.toDouble() ?? 0),
      ('슬픔', cur.sadness, (avg['sadness'] as num?)?.toDouble() ?? 0),
      ('불안', cur.anxiety, (avg['anxiety'] as num?)?.toDouble() ?? 0),
      ('졸림', cur.sleepiness, (avg['sleepiness'] as num?)?.toDouble() ?? 0),
      ('호기심', cur.curiosity, (avg['curiosity'] as num?)?.toDouble() ?? 0),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: _cardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '같은 품종 평균 대비',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '$count건 기준',
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            ...comparisons.map((c) {
              final name = c.$1;
              final mine = c.$2;
              final breedAvg = c.$3;
              final diff = mine - breedAvg;

              return Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44.w,
                      child: Text(name,
                          style: TextStyle(
                              fontSize: 12.sp, color: Colors.grey[700])),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 8.h,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                          // 품종 평균 마커
                          Positioned(
                            left: (breedAvg * 100).clamp(0, 100) /
                                100 *
                                (MediaQuery.of(context).size.width - 130.w),
                            child: Container(
                              width: 2.w,
                              height: 8.h,
                              color: Colors.grey[400],
                            ),
                          ),
                          // 현재 값 바
                          FractionallySizedBox(
                            widthFactor: mine.clamp(0.0, 1.0),
                            child: Container(
                              height: 8.h,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6.w),
                    SizedBox(
                      width: 40.w,
                      child: Text(
                        '${diff > 0 ? "+" : ""}${(diff * 100).toInt()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: diff.abs() < 0.05
                              ? Colors.grey[500]
                              : diff > 0
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            SizedBox(height: 4.h),
            Text(
              '회색 선: 같은 품종 평균',
              style: TextStyle(fontSize: 10.sp, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  // ── 9. B-1: 웰빙 점수 카드 ──
  Widget _buildWellbeingCard() {
    if (!_historyLoaded) return const SizedBox.shrink();

    if (!_insights.hasEnoughData) {
      return Padding(
        padding: EdgeInsets.only(bottom: 14.h),
        child: _cardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '웰빙 점수',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                _insights.emptyStateMessage,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    final score = _insights.wellbeingScore;
    final color = score >= 70
        ? const Color(0xFF2ECC71)
        : score >= 40
            ? const Color(0xFFF39C12)
            : const Color(0xFFE74C3C);
    final label = score >= 70
        ? '좋음'
        : score >= 40
            ? '보통'
            : '관심 필요';

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: _cardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '웰빙 점수',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${score.toInt()}',
                  style: TextStyle(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 4.h, left: 2.w),
                  child: Text(
                    '/ 100',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 6.h,
                backgroundColor: Colors.grey.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '최근 분석 기록 기반 종합 웰빙 지수입니다.',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // ── 10. B-3: 감정 안정성 카드 ──
  Widget _buildStabilityCard() {
    if (!_historyLoaded) return const SizedBox.shrink();

    if (!_insights.hasEnoughData) {
      return Padding(
        padding: EdgeInsets.only(bottom: 14.h),
        child: _cardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '감정 안정성',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                _insights.emptyStateMessage,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    final emotionNames = {
      'happiness': '기쁨',
      'sadness': '슬픔',
      'anxiety': '불안',
      'sleepiness': '졸림',
      'curiosity': '호기심',
    };

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: _cardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '감정 안정성',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '종합 ${(_insights.stabilityIndex * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _insights.emotionStability.entries.map((entry) {
                final name = emotionNames[entry.key] ?? entry.key;
                final stability = entry.value;
                final isStable = stability >= 0.6;
                final color = isStable
                    ? const Color(0xFF2ECC71)
                    : const Color(0xFFF39C12);

                return Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style:
                            TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                      ),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          isStable ? '안정' : '변동',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 8.h),
            Text(
              '최근 분석 기록을 기반으로 각 감정의 변동 정도를 분석했어요.',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // ── 11. B-4: 이번주 감정 일기 카드 ──
  Widget _buildDiaryCard() {
    if (!_historyLoaded) return const SizedBox.shrink();

    if (_fullHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: _cardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이번주 감정 일기',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 10.h),
            if (_diaryText != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF8E44AD).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  _diaryText!,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey[700],
                    height: 1.6,
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _diaryLoading ? null : _generateDiary,
                  icon: _diaryLoading
                      ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child:
                              const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.auto_awesome, size: 16.w),
                  label: Text(
                    _diaryLoading ? '생성 중...' : '이번주 일기 생성하기',
                    style: TextStyle(fontSize: 13.sp),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8E44AD),
                    side: const BorderSide(color: Color(0xFF8E44AD)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Methods from emotion_result_social.dart
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildImageThumbnails() {
    final paths = widget.imagePaths;
    if (paths.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Image.file(
          File(paths.first),
          width: 88.w,
          height: 88.w,
          fit: BoxFit.cover,
        ),
      );
    }
    return SizedBox(
      width: 88.w,
      height: 88.w,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Image.file(
              File(paths.first),
              width: 88.w,
              height: 88.w,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            bottom: 4.h,
            right: 4.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                '${paths.length}장',
                style: TextStyle(fontSize: 9.sp, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 9. 추천 카드 ──
  Widget _buildRecommendCard(String dominant, Color color) {
    final rec = _getSingleRecommendation(dominant);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(rec.icon, size: 22.w, color: color),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 추천',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  rec.title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  rec.body,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Methods from emotion_result_memo.dart
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMemoCard() {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '메모',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 10.h),
          TextField(
            controller: _memoController,
            maxLines: 3,
            style: TextStyle(fontSize: 13.sp),
            decoration: InputDecoration(
              hintText: '이 순간에 대한 메모를 남겨보세요 (선택사항)',
              hintStyle:
                  TextStyle(fontSize: 12.sp, color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFF5F6FA),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 공통 카드 컨테이너 ──
  Widget _cardContainer({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── 하단 고정 버튼 ──
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
        builder: (context, state) {
          final isLoading = state is EmotionAnalysisSaving;
          return Row(
            children: [
              SizedBox(
                height: 48.h,
                width: 48.h,
                child: OutlinedButton(
                  onPressed: _shareResult,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Icon(Icons.share_outlined,
                      size: 20.w, color: Colors.grey[700]),
                ),
              ),
              SizedBox(width: 8.w),
              // 피드에 공유 버튼
              SizedBox(
                height: 48.h,
                width: 48.h,
                child: OutlinedButton(
                  onPressed: () => _showShareToFeedSheet(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    side: BorderSide(
                        color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                  ),
                  child: Icon(Icons.dynamic_feed_outlined,
                      size: 20.w, color: AppTheme.primaryColor),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: SizedBox(
                  height: 48.h,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _saveAnalysis,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 0,
                    ),
                    icon: isLoading
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.bookmark_add_outlined, size: 18.w),
                    label: Text(
                      isLoading ? '저장 중...' : '결과 저장',
                      style: TextStyle(
                          fontSize: 14.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _ChartMode { none, radar, facial }

class _Recommendation {
  final IconData icon;
  final String title;
  final String body;
  _Recommendation(
      {required this.icon, required this.title, required this.body});
}
