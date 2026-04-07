import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
import '../widgets/result/emotion_share_card.dart';

part '../widgets/result/emotion_result_helpers.dart';
part '../widgets/result/emotion_result_cards_a.dart';
part '../widgets/result/emotion_result_cards_b.dart';
part '../widgets/result/emotion_result_cards_c.dart';
part '../widgets/result/emotion_result_bottom.dart';


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
    } catch (e) {
      log('[EmotionResult] 이전 분석 로딩 실패: $e', name: 'EmotionResult');
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
    } catch (e) {
      log('[EmotionResult] 다른 펫 분석 로딩 실패: $e', name: 'EmotionResult');
    }
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
    } catch (e) {
      log('[EmotionResult] 품종 평균 로딩 실패: $e', name: 'EmotionResult');
    }
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
                      // isSleepy 생리지표 배너
                      if (widget.analysis.isSleepy) ...[
                        _buildSleepyBanner(),
                        SizedBox(height: 10.h),
                      ],
                      // 0. 감정 요약 메시지
                      _buildEmotionSummaryCard(dominant, emotionColor),
                      SizedBox(height: 14.h),
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
                      // 13. 이론 출처
                      _buildTheoryAttribution(),
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

  // ── isSleepy 생리지표 배너 ──
  Widget _buildSleepyBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppTheme.physiologicalColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppTheme.physiologicalColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Text('💤', style: TextStyle(fontSize: 18.sp)),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              '졸린 상태가 감지됐어요. 편히 쉴 수 있는 공간을 만들어주세요.',
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.primaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 0. 감정 요약 메시지 카드 ──
  Widget _buildEmotionSummaryCard(String dominant, Color emotionColor) {
    final summaryMap = {
      'happiness':  '오늘 반려동물이 매우 행복해 보여요! 😊',
      'calm':       '편안하고 안정적인 상태예요. 좋은 환경을 유지해주세요 😌',
      'excitement': '에너지가 넘치는 흥분 상태예요! 함께 놀아주세요 🤩',
      'curiosity':  '호기심이 가득해 보여요! 새로운 놀이를 해보세요 🧐',
      'anxiety':    '불안한 모습이 보여요. 편안한 환경을 만들어주세요 😰',
      'fear':       '무언가를 무서워하고 있어요. 안전한 공간을 제공해주세요 😨',
      'sadness':    '조금 우울해 보이네요. 많이 안아주세요 😢',
      'discomfort': '불편한 것이 있어 보여요. 몸 상태를 확인해주세요 😣',
    };

    final summary = summaryMap[dominant] ?? '감정 분석이 완료되었습니다.';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          gradient: LinearGradient(
            colors: [
              emotionColor.withValues(alpha: 0.15),
              emotionColor.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Text(
          summary,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryTextColor,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ),
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

    if (!ctx.mounted) return;

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

  String _getEmotionNameForShare(String emotion) =>
      AppTheme.getEmotionLabel(emotion);

  double _getEmotionValueForShare(String emotion) {
    final e = widget.analysis.emotions;
    switch (emotion) {
      case 'happiness':  return e.happiness;
      case 'calm':       return e.calm;
      case 'excitement': return e.excitement;
      case 'curiosity':  return e.curiosity;
      case 'anxiety':    return e.anxiety;
      case 'fear':       return e.fear;
      case 'sadness':    return e.sadness;
      case 'discomfort': return e.discomfort;
      default:           return 0.0;
    }
  }

  Future<void> _shareResult() async {
    try {
      await EmotionShareHelper.shareAsCard(
        context,
        analysis: widget.analysis,
        petName: widget.analysis.petName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공유 중 오류가 발생했습니다: $e')),
      );
    }
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

  // ── 이미지 썸네일 ──
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
}
