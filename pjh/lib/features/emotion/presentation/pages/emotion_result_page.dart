import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/emotion_analysis.dart';
import '../bloc/emotion_analysis_bloc.dart';
import '../widgets/emotion_radar_chart.dart';

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

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
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
    final dominantEmoji = _getEmotionEmoji(dominant);
    final dominantValue = _getEmotionValue(dominant);
    final emotionColor = AppTheme.getEmotionColor(dominant);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _buildAppBar(dominantEmoji, dominantName, emotionColor),
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
                      // 상단: 사진 + 주감정 카드
                      _buildHeroCard(
                        dominant, dominantName, dominantEmoji,
                        dominantValue, emotionColor,
                      ),
                      SizedBox(height: 14.h),
                      // 중단: 감정 바
                      _buildEmotionBarsCard(),
                      SizedBox(height: 14.h),
                      // 레이더 차트
                      _buildRadarCard(),
                      SizedBox(height: 14.h),
                      // 하단 추천
                      _buildRecommendCard(dominant, emotionColor),
                      SizedBox(height: 14.h),
                      // 메모
                      _buildMemoCard(),
                    ],
                  ),
                ),
              ),
            ),
            // 하단 고정 버튼
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      String emoji, String name, Color emotionColor) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black87),
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
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.black87),
          onPressed: _shareResult,
        ),
      ],
    );
  }

  // ── 상단: 사진 + 주감정 ──
  Widget _buildHeroCard(String dominant, String name, String emoji,
      double value, Color color) {
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
          // 상단 컬러 헤더
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
                Text(
                  emoji,
                  style: TextStyle(fontSize: 32.sp),
                ),
                SizedBox(width: 10.w),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(value * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '신뢰도',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 사진 + 날짜
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
                          Icon(Icons.access_time, size: 13.w, color: Colors.grey),
                          SizedBox(width: 4.w),
                          Text(
                            _formatDateTime(widget.analysis.analyzedAt),
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey[600],
                            ),
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

  // ── 중단: 감정 바 ──
  Widget _buildEmotionBarsCard() {
    final emotions = [
      ('happiness', '기쁨', '😊', widget.analysis.emotions.happiness),
      ('sadness', '슬픔', '😢', widget.analysis.emotions.sadness),
      ('anxiety', '불안', '😰', widget.analysis.emotions.anxiety),
      ('sleepiness', '졸림', '😴', widget.analysis.emotions.sleepiness),
      ('curiosity', '호기심', '🤔', widget.analysis.emotions.curiosity),
    ];
    final dominant = widget.analysis.emotions.dominantEmotion;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded,
                  size: 16.w, color: AppTheme.primaryColor),
              SizedBox(width: 6.w),
              Text(
                '감정 분포',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          ...emotions.map((e) {
            final key = e.$1;
            final name = e.$2;
            final emoji = e.$3;
            final value = e.$4;
            final color = AppTheme.getEmotionColor(key);
            final isMain = key == dominant;

            return Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                children: [
                  Text(emoji, style: TextStyle(fontSize: 18.sp)),
                  SizedBox(width: 8.w),
                  SizedBox(
                    width: 44.w,
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
                        fontWeight: isMain
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isMain ? color : Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── 레이더 차트 ──
  Widget _buildRadarCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.radar, size: 16.w, color: AppTheme.primaryColor),
              SizedBox(width: 6.w),
              Text(
                '감정 레이더',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Center(
            child: EmotionRadarChart(
              emotions: widget.analysis.emotions,
              size: 180.w,
            ),
          ),
        ],
      ),
    );
  }

  // ── 다중 사진 썸네일 ──
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
    // 2장 이상: 첫 번째 큰 썸네일 + 나머지 작은 썸네일 스택
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
          // 장수 뱃지
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

  // ── 추천 한 가지 ──
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
            child: Center(
              child: Text(rec.emoji, style: TextStyle(fontSize: 20.sp)),
            ),
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

  // ── 메모 카드 ──
  Widget _buildMemoCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, size: 16.w, color: AppTheme.primaryColor),
              SizedBox(width: 6.w),
              Text(
                '메모',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
            ],
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
              // 공유 버튼
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
              SizedBox(width: 10.w),
              // 저장 버튼
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

  void _saveAnalysis() {
    context.read<EmotionAnalysisBloc>().add(
          SaveAnalysisRequested(memo: _memoController.text.trim()),
        );
  }

  Future<void> _shareResult() async {
    try {
      final dominant = widget.analysis.emotions.dominantEmotion;
      final value = _getEmotionValue(dominant);
      final name = _getEmotionName(dominant);
      final emoji = _getEmotionEmoji(dominant);

      final text = '''
$emoji 펫페이스 AI 감정 분석 결과

주요 감정: $name (${(value * 100).toInt()}%)
분석 시간: ${_formatDateTime(widget.analysis.analyzedAt)}

😊 기쁨: ${(widget.analysis.emotions.happiness * 100).toInt()}%
😢 슬픔: ${(widget.analysis.emotions.sadness * 100).toInt()}%
😰 불안: ${(widget.analysis.emotions.anxiety * 100).toInt()}%
😴 졸림: ${(widget.analysis.emotions.sleepiness * 100).toInt()}%
🤔 호기심: ${(widget.analysis.emotions.curiosity * 100).toInt()}%

#펫페이스 #반려동물감정분석 #AI감정분석
''';

      if (widget.imagePaths.isNotEmpty) {
        await Share.shareXFiles(
          [XFile(widget.imagePaths.first)],
          text: text,
          subject: '반려동물 AI 감정 분석 결과',
        );
      } else {
        await Share.share(text, subject: '반려동물 AI 감정 분석 결과');
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

  String _getEmotionEmoji(String emotion) {
    switch (emotion) {
      case 'happiness': return '😊';
      case 'sadness':   return '😢';
      case 'anxiety':   return '😰';
      case 'sleepiness':return '😴';
      case 'curiosity': return '🤔';
      default: return '🐾';
    }
  }

  String _getShortDescription(String emotion) {
    switch (emotion) {
      case 'happiness': return '지금 이 순간, 아이가 행복해 보여요 🌟';
      case 'sadness':   return '오늘은 조금 기운이 없어 보이네요 💙';
      case 'anxiety':   return '살짝 긴장하고 있는 것 같아요. 안심시켜 주세요 🤗';
      case 'sleepiness':return '스르르 졸음이 오고 있어요. 편히 쉬게 해주세요 😴';
      case 'curiosity': return '무언가에 호기심이 가득한 눈빛이에요! 🌿';
      default: return '오늘 아이의 상태를 확인했어요';
    }
  }

  _Recommendation _getSingleRecommendation(String emotion) {
    switch (emotion) {
      case 'happiness':
        return _Recommendation(
          emoji: '🎾',
          title: '함께 놀아주세요',
          body: '지금이 함께 산책하거나 좋아하는 놀이를 즐기기에 가장 좋은 타이밍이에요!',
        );
      case 'curiosity':
        return _Recommendation(
          emoji: '🧩',
          title: '탐색 시간을 주세요',
          body: '새로운 장난감이나 안전한 공간을 탐색하게 해주면 자연스러운 호기심을 충족할 수 있어요.',
        );
      case 'anxiety':
        return _Recommendation(
          emoji: '🫂',
          title: '조용히 곁에 있어주세요',
          body: '부드러운 목소리와 가벼운 스킨십으로 안심감을 전달해 주세요. 익숙한 물건이 도움이 돼요.',
        );
      case 'sadness':
        return _Recommendation(
          emoji: '💙',
          title: '따뜻한 스킨십이 필요해요',
          body: '좋아하는 간식이나 장난감으로 기분 전환을 도와주세요. 우울이 지속되면 수의사에게 상담하세요.',
        );
      case 'sleepiness':
        return _Recommendation(
          emoji: '🛏️',
          title: '편안한 잠자리를 만들어주세요',
          body: '따뜻하고 조용한 공간에서 충분히 쉬게 해주세요. 수면은 아이의 건강에 매우 중요해요.',
        );
      default:
        return _Recommendation(
          emoji: '🐾',
          title: '오늘도 잘 보살펴주세요',
          body: '반려동물의 상태를 꾸준히 관찰하고 기록하면 건강 변화를 빠르게 파악할 수 있어요.',
        );
    }
  }
}

class _Recommendation {
  final String emoji;
  final String title;
  final String body;
  _Recommendation({required this.emoji, required this.title, required this.body});
}
