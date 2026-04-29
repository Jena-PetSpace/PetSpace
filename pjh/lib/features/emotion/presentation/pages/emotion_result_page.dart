import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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
import '../widgets/multi_image_gallery_widget.dart';
import '../widgets/result/emotion_share_card.dart';

part '../widgets/result/emotion_result_helpers.dart';
part '../widgets/result/emotion_result_cards_a.dart';
part '../widgets/result/emotion_result_cards_b.dart';
part '../widgets/result/emotion_result_cards_c.dart';
part '../widgets/result/emotion_result_bottom.dart';


class EmotionResultPage extends StatefulWidget {
  final EmotionAnalysis analysis;
  final List<String> imagePaths;
  /// 히스토리에서 열렸을 때 true — 하단 버튼이 push 대신 pop으로 동작
  final bool fromHistory;

  const EmotionResultPage({
    super.key,
    required this.analysis,
    this.imagePaths = const [],
    this.fromHistory = false,
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
  int _facialViewMode = 0; // 0: 카드형 그리드, 1: 타임라인형 목록

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
    log('[ResultPage] imageUrl="${widget.analysis.imageUrl}" imagePaths=${widget.imagePaths.length}장 fromHistory=${widget.fromHistory}', name: 'EmotionResult');
    _loadPreviousAnalysis();
    _loadMultiPetData();
    _loadBreedAverage();
    // 히스토리에서 열린 경우 재저장 방지
    if (!widget.fromHistory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _saveAnalysis();
      });
    }
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
          // 자동 저장 완료 시 조용히 처리 (화면 전환 없음)
          if (state is EmotionAnalysisError) {
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
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        '감정 분석 결과',
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryTextColor,
        ),
      ),
      centerTitle: true,
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
                              '$dominantName $dominantPct%',
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

    // write-ahead 패턴: post_id를 클라이언트에서 미리 생성
    final postId = const Uuid().v4();

    // 이미지 소스 결정: 로컬 파일 우선, 없으면 Supabase URL에서 다운로드
    List<File> imageFiles = [];

    if (widget.imagePaths.isNotEmpty) {
      // 케이스 A: 방금 분석한 로컬 파일
      imageFiles = widget.imagePaths.map((p) => File(p)).toList();
    } else if (widget.analysis.imageUrl.isNotEmpty) {
      // 케이스 B: History에서 공유 — 원격 URL 다운로드 후 임시 파일로
      try {
        final response = await http.get(Uri.parse(widget.analysis.imageUrl));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File(
            '${tempDir.path}/emotion_share_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await tempFile.writeAsBytes(response.bodyBytes);
          imageFiles = [tempFile];
        }
      } catch (e) {
        log('[ResultPage] 이미지 다운로드 실패: $e', name: 'EmotionResult');
        // 실패해도 이미지 없이 게시 진행
      }
    }

    if (!ctx.mounted) return;

    final post = Post(
      id: postId,
      authorId: authState.user.uid,
      authorName: authState.user.displayName,
      authorProfileImage: authState.user.photoURL,
      type: PostType.emotionAnalysis,
      content: caption.isEmpty ? null : caption,
      imageUrls: const [], // DataSource가 업로드 후 채움
      emotionAnalysis: widget.analysis,
      tags: tags,
      createdAt: DateTime.now(),
    );

    ctx.read<FeedBloc>().add(CreatePostRequested(
      post: post,
      images: imageFiles,
    ));
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

}
