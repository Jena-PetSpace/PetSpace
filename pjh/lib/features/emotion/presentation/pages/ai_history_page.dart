import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import '../../../../config/injection_container.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../data/models/health_analysis_model.dart';
import '../../domain/entities/emotion_analysis.dart';
import '../../domain/entities/health_analysis.dart';
import '../../domain/repositories/emotion_repository.dart';
import '../../domain/usecases/get_previous_analysis.dart';
import '../bloc/emotion_analysis_bloc.dart';
import '../widgets/pet_inline_dropdown.dart';
import '../theme/emotion_result_tokens.dart';
import 'emotion_result_page.dart';
import 'health_result_page.dart';

// ── 통합 히스토리 아이템 모델 ──────────────────────────────────
class _HistoryItem {
  final bool isEmotion;
  final DateTime date;
  final String? petName;
  final String title;
  final String subtitle;
  final String badge;
  final String badgeType; // 'emot' | 'good' | 'warn' | 'bad'
  final String? thumbnailUrl; // 대표 이미지 URL
  final EmotionAnalysis? emotionData;
  final HealthAnalysisModel? healthData;

  const _HistoryItem({
    required this.isEmotion,
    required this.date,
    this.petName,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeType,
    this.thumbnailUrl,
    this.emotionData,
    this.healthData,
  });
}

// ── 부위별 최신 건강 상태 모델 ────────────────────────────────
class _AreaStatus {
  final HealthArea area;
  final int? score;
  final String? status;
  final bool? riskAlert;
  final DateTime? date;

  _AreaStatus({
    required this.area,
    this.score,
    this.status,
    this.riskAlert,
    this.date,
  });

  bool get hasData => status != null;
}

class AiHistoryPage extends StatefulWidget {
  /// 게시글 작성 등에서 분석 결과를 골라 반환받기 위한 모드.
  /// true 일 때:
  ///   - 3-tab 헤더 숨김. "전체이력" 탭 본문만 표시
  ///   - 헤더 타이틀이 "감정 분석 선택"
  ///   - 감정 카드 탭 시 Navigator.pop(context, emotionAnalysis) 반환
  ///   - 건강 카드는 비활성 (게시글 첨부 호환을 위해 감정만)
  final bool selectMode;

  const AiHistoryPage({super.key, this.selectMode = false});

  @override
  State<AiHistoryPage> createState() => _AiHistoryPageState();
}

class _AiHistoryPageState extends State<AiHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  Pet? _selectedPet;
  bool _showUnregistered = false;

  List<_AreaStatus> _areaStatuses = [];
  bool _dashboardLoading = false;

  List<HealthAnalysisModel> _healthHistory = [];
  bool _healthHistoryLoading = false;

  String _filterType = '전체';

  @override
  void initState() {
    super.initState();
    // selectMode 에서는 "전체이력" 한 탭만 표시. 일반 모드는 3-tab.
    _tabCtrl = TabController(
      length: widget.selectMode ? 1 : 3,
      vsync: this,
    );
    _tabCtrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSelectedPet();
      // selectMode 에서는 히스토리만 필요. 대시보드 로딩 스킵.
      if (!widget.selectMode) {
        _loadDashboard();
        _loadHealthHistory();
      }
      _loadEmotionHistory();
    });
  }

  void _loadEmotionHistory() {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      context.read<EmotionAnalysisBloc>().add(
        LoadAnalysisHistory(userId: auth.user.uid),
      );
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _initSelectedPet() {
    final petState = context.read<PetBloc>().state;
    if (petState is PetLoaded && petState.pets.isNotEmpty) {
      setState(() => _selectedPet = petState.pets.first);
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _dashboardLoading = true);
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      if (mounted) setState(() => _dashboardLoading = false);
      return;
    }
    final result = await sl<EmotionRepository>().getLatestHealthByArea(
      userId: auth.user.uid,
      petId: _showUnregistered ? null : _selectedPet?.id,
    );
    if (!mounted) return;
    result.fold(
      (failure) {
        log('Dashboard load error: ${failure.message}', name: 'AiHistory');
        setState(() => _dashboardLoading = false);
      },
      (rows) {
        final statuses = HealthArea.values.map((area) {
          final found =
              rows.where((r) => r['area'] == area.displayName).firstOrNull;
          return _AreaStatus(
            area: area,
            score: found?['overall_score'] as int?,
            status: found?['status'] as String?,
            riskAlert: found?['risk_alert'] as bool?,
            date: found != null
                ? DateTime.parse(found['created_at'] as String)
                : null,
          );
        }).toList();
        setState(() {
          _areaStatuses = statuses;
          _dashboardLoading = false;
        });
      },
    );
  }

  Future<void> _loadHealthHistory() async {
    setState(() => _healthHistoryLoading = true);
    try {
      final auth = context.read<AuthBloc>().state;
      if (auth is! AuthAuthenticated) return;

      final result =
          await sl<EmotionRepository>().getHealthHistory(auth.user.uid);
      final rows = result.fold((_) => <Map<String, dynamic>>[], (r) => r);
      final models = rows.map(HealthAnalysisModel.fromSupabaseRow).toList();
      if (mounted) setState(() => _healthHistory = models);
    } catch (e) {
      log('Health history load error: $e', name: 'AiHistory');
    } finally {
      if (mounted) setState(() => _healthHistoryLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(children: [
        // ── 딥블루 AppBar ──────────────────────────────────────
        Container(
          color: AppTheme.primaryColor,
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.selectMode ? '감정 분석 선택' : 'AI분석 히스토리',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 48.w),
                ]),
              ),
              // selectMode 에서는 TabBar 숨김 (탭 1개라 의미 없음)
              if (!widget.selectMode)
                TabBar(
                  controller: _tabCtrl,
                  indicatorColor: AppTheme.highlightColor,
                  indicatorWeight: 2.5,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: TextStyle(
                      fontSize: 13.sp, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: TextStyle(
                      fontSize: 13.sp, fontWeight: FontWeight.w400),
                  tabs: const [
                    Tab(text: '현황'),
                    Tab(text: '리포트'),
                    Tab(text: '전체이력'),
                  ],
                ),
            ]),
          ),
        ),
        // ── 탭 본문 ──────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: widget.selectMode
                ? [_buildHistoryTab()]
                : [
                    _buildStatusTab(),
                    _buildReportTab(),
                    _buildHistoryTab(),
                  ],
          ),
        ),
      ]),
    );
  }

  // ────────────────────────────────────────────────────────
  // 현황 탭
  // ────────────────────────────────────────────────────────
  Widget _buildStatusTab() {
    final petState = context.read<PetBloc>().state;
    final pets = petState is PetLoaded ? petState.pets : <Pet>[];

    return SingleChildScrollView(
      padding: EdgeInsets.all(14.w),
      child: Column(children: [
        PetInlineDropdown(
          pets: pets,
          selectedPet: _selectedPet,
          showUnregistered: _showUnregistered,
          onPetSelected: (pet) {
            setState(() {
              _selectedPet = pet;
              _showUnregistered = false;
            });
            _loadDashboard();
            _loadHealthHistory();
          },
          onUnregisteredChanged: (val) {
            setState(() {
              _showUnregistered = val;
              if (val) _selectedPet = null;
            });
            _loadDashboard();
            _loadHealthHistory();
          },
        ),
        SizedBox(height: 10.h),
        _buildEmotionChart(),
        SizedBox(height: 10.h),
        _showUnregistered
            ? _buildUnregisteredGuide()
            : _buildHealthDashboard(),
      ]),
    );
  }

  Widget _buildUnregisteredGuide() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(children: [
        Icon(Icons.pets,
            size: 36.w,
            color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        SizedBox(height: 10.h),
        Text(
          '반려동물을 등록하면\n부위별 건강 현황을 볼 수 있어요',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.sp,
            color: AppTheme.secondaryTextColor,
            height: 1.5,
          ),
        ),
        SizedBox(height: 14.h),
        ElevatedButton(
          onPressed: () => context.push('/pets'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.actionBase,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r)),
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          ),
          child: Text('반려동물 등록하기',
              style: TextStyle(
                  fontSize: 13.sp, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildHealthDashboard() {
    if (_dashboardLoading) {
      return SizedBox(
        height: 160.h,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final areas = _areaStatuses.isEmpty
        ? HealthArea.values.map((a) => _AreaStatus(area: a)).toList()
        : _areaStatuses;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('최근 건강 현황',
          style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.secondaryTextColor)),
      SizedBox(height: 8.h),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8.w,
        mainAxisSpacing: 8.h,
        childAspectRatio: 0.9,
        children: areas.map((a) => _buildAreaCard(a)).toList(),
      ),
    ]);
  }

  Widget _buildAreaCard(_AreaStatus s) {
    Color borderColor;
    Color bgColor = Colors.white;
    Color iconColor;
    Widget statusWidget;

    if (!s.hasData) {
      borderColor = AppTheme.dividerColor;
      bgColor = AppTheme.subtleBackground;
      iconColor = Colors.grey.shade300;
      statusWidget = Text('미분석',
          style:
              TextStyle(fontSize: 8.5.sp, color: Colors.grey.shade400));
    } else if (s.status == '양호') {
      borderColor = AppTheme.successColor;
      iconColor = AppTheme.successColor;
      statusWidget = Text('양호',
          style: TextStyle(
              fontSize: 8.5.sp,
              color: AppTheme.successColor,
              fontWeight: FontWeight.w500));
    } else if (s.status == '주의') {
      borderColor = AppTheme.warningColor; // v2-review: EF9F27 근사
      iconColor = AppTheme.warningColor; // v2-review: EF9F27 근사
      statusWidget = Text('주의',
          style: TextStyle(
              fontSize: 8.5.sp,
              color: EmotionResultTokens.amberDark,
              fontWeight: FontWeight.w500));
    } else if (s.status == '위험') {
      borderColor = AppTheme.highlightColor;
      bgColor = AppTheme.tilePastelRose; // v2-review: FFF5F4 근사
      iconColor = AppTheme.errorColor;
      statusWidget = Text('위험',
          style: TextStyle(
              fontSize: 8.5.sp,
              color: AppTheme.errorColor,
              fontWeight: FontWeight.w600));
    } else {
      borderColor = AppTheme.dividerColor;
      iconColor = AppTheme.secondaryTextColor;
      statusWidget = Text(s.status ?? '',
          style: TextStyle(
              fontSize: 8.5.sp, color: AppTheme.secondaryTextColor));
    }

    return GestureDetector(
      onTap: !s.hasData
          ? () => showModalBottomSheet(
                context: context,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16.r))),
                builder: (_) => SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${s.area.displayName} 분석 기록 없음',
                          style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 8.h),
                      Text('아직 분석하지 않은 부위예요.',
                          style: TextStyle(
                              fontSize: 12.sp,
                              color: AppTheme.secondaryTextColor)),
                      SizedBox(height: 16.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            context.go('/emotion');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.actionBase,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10.r)),
                            elevation: 0,
                          ),
                          child: Text('AI 건강분석 하러 가기',
                              style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ),
                ),
              )
          : null,
      child: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
              color: borderColor,
              width: s.status == '위험' ? 1.5 : 0.8),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_areaIcon(s.area), size: 20.w, color: iconColor),
          SizedBox(height: 4.h),
          Text(s.area.displayName,
              style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryTextColor),
              textAlign: TextAlign.center),
          SizedBox(height: 2.h),
          statusWidget,
          if (s.date != null)
            Text('${s.date!.month}/${s.date!.day}',
                style: TextStyle(
                    fontSize: 7.5.sp, color: Colors.grey.shade400)),
        ]),
      ),
    );
  }

  IconData _areaIcon(HealthArea area) {
    switch (area) {
      case HealthArea.eyes:    return Icons.visibility_outlined;
      case HealthArea.nose:    return Icons.face_outlined;
      case HealthArea.skin:    return Icons.texture;
      case HealthArea.body:    return Icons.monitor_weight_outlined;
      case HealthArea.posture: return Icons.accessibility_new_outlined;
      case HealthArea.overall: return Icons.health_and_safety_outlined;
    }
  }

  Widget _buildEmotionChart() {
    return BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
      builder: (context, state) {
        if (state is! EmotionAnalysisHistoryLoaded) {
          return const SizedBox.shrink();
        }
        final history = state.history;
        if (history.isEmpty) return const SizedBox.shrink();

        final recent = history.take(7).toList().reversed.toList();
        final maxIdx = recent.length - 1;

        return Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── 헤더 ──
            Row(children: [
              Text('최근 감정 현황',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryTextColor)),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '${_dominantLabel(history)} 이 많았어요',
                  style: TextStyle(
                      fontSize: 9.5.sp,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            SizedBox(height: 4.h),
            Text('최근 ${recent.length}회 기준 · 오래된 순 →',
                style: TextStyle(
                    fontSize: 9.sp, color: AppTheme.secondaryTextColor)),
            SizedBox(height: 12.h),

            // ── 이모지 타임라인 ──
            Row(
              children: recent.asMap().entries.map((e) {
                final isLast = e.key == maxIdx;
                final isNeg = _isNegative(e.value.emotions.dominantEmotion);
                final emotion = e.value.emotions.dominantEmotion;
                final score = _positiveScore(e.value);
                final barColor = isNeg
                    ? AppTheme.highlightColor
                    : AppTheme.primaryColor;
                final bgColor = isNeg
                    ? AppTheme.highlightColor.withValues(alpha: isLast ? 0.15 : 0.07)
                    : AppTheme.primaryColor.withValues(alpha: isLast ? 0.13 : 0.06);

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2.5.w),
                    child: Column(
                      children: [
                        // 이모지 버블
                        Container(
                          width: 34.w,
                          height: 34.w,
                          decoration: BoxDecoration(
                            color: bgColor,
                            shape: BoxShape.circle,
                            border: isLast
                                ? Border.all(
                                    color: barColor.withValues(alpha: 0.6),
                                    width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Icon(
                              AppTheme.getEmotionIcon(emotion),
                              size: isLast ? 16.sp : 14.sp,
                              color: AppTheme.getEmotionColor(emotion),
                            ),
                          ),
                        ),
                        SizedBox(height: 4.h),
                        // 점수 바
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3.r),
                          child: SizedBox(
                            width: double.infinity,
                            height: 4.h,
                            child: LinearProgressIndicator(
                              value: score,
                              backgroundColor: Colors.grey.shade100,
                              color: barColor.withValues(
                                  alpha: isLast ? 1.0 : 0.5),
                            ),
                          ),
                        ),
                        SizedBox(height: 3.h),
                        // 회차
                        Text(
                          '${e.key + 1}회',
                          style: TextStyle(
                              fontSize: 7.sp,
                              fontWeight: isLast
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isLast
                                  ? AppTheme.primaryTextColor
                                  : AppTheme.secondaryTextColor),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: 10.h),
            // ── 범례 ──
            Row(children: [
              _chartLegend(AppTheme.primaryColor, '긍정'),
              SizedBox(width: 10.w),
              _chartLegend(AppTheme.highlightColor, '부정'),
              const Spacer(),
              Text('바 길이 = 긍정 비율',
                  style: TextStyle(
                      fontSize: 8.5.sp, color: Colors.grey.shade400)),
            ]),
          ]),
        );
      },
    );
  }

  Widget _chartLegend(Color c, String label) => Row(children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(
              color: c, shape: BoxShape.circle),
        ),
        SizedBox(width: 4.w),
        Text(label,
            style: TextStyle(
                fontSize: 9.sp, color: AppTheme.secondaryTextColor)),
      ]);

  String _dominantEmotion(List<EmotionAnalysis> history) {
    final counts = <String, int>{};
    for (final a in history) {
      final d = a.emotions.dominantEmotion;
      counts[d] = (counts[d] ?? 0) + 1;
    }
    if (counts.isEmpty) return '';
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  String _dominantLabel(List<EmotionAnalysis> history) {
    return AppTheme.getEmotionLabel(_dominantEmotion(history));
  }

  double _positiveScore(EmotionAnalysis a) {
    final e = a.emotions;
    final pos =
        e.happiness + e.calm + e.excitement + e.curiosity;
    final neg =
        e.anxiety + e.fear + e.sadness + e.discomfort;
    final total = pos + neg;
    return total > 0 ? pos / total : 0.5;
  }

  bool _isNegative(String emotion) =>
      ['anxiety', 'fear', 'sadness', 'discomfort'].contains(emotion);

  // ────────────────────────────────────────────────────────
  // 리포트 탭
  // ────────────────────────────────────────────────────────
  Widget _buildReportTab() {
    return BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
      builder: (context, state) {
        final emotionHistory = state is EmotionAnalysisHistoryLoaded
            ? state.history
            : <EmotionAnalysis>[];

        final emotionMonths = _groupByMonth(emotionHistory);
        final healthMonths = _groupHealthByMonth(_healthHistory);

        // 두 맵의 키를 합쳐서 정렬
        final allKeys = {
          ...emotionMonths.keys,
          ...healthMonths.keys,
        }.toList()
          ..sort((a, b) => b.compareTo(a));

        if (allKeys.isEmpty) {
          return _buildEmptyState('분석 기록이 없어요');
        }

        return ListView.builder(
          padding: EdgeInsets.all(14.w),
          itemCount: allKeys.length,
          itemBuilder: (_, i) {
            final isFirst = i == 0;
            final month = allKeys[i];
            final analyses = emotionMonths[month] ?? [];
            final healthItems = healthMonths[month] ?? [];
            final dominant = analyses.isNotEmpty
                ? _dominantLabelFromList(analyses)
                : null;

            return Container(
              margin: EdgeInsets.only(bottom: 10.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isFirst
                      ? AppTheme.primaryColor
                      : AppTheme.dividerColor,
                  width: isFirst ? 1.5 : 0.5,
                ),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(month,
                          style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor)),
                      if (isFirst) ...[
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text('이번달',
                              style: TextStyle(
                                  fontSize: 8.5.sp,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                      const Spacer(),
                      Text('${analyses.length + healthItems.length}회 분석',
                          style: TextStyle(
                              fontSize: 9.sp,
                              color: AppTheme.secondaryTextColor)),
                    ]),
                    SizedBox(height: 10.h),
                    Row(children: [
                      if (analyses.isNotEmpty)
                        _reportStat('${analyses.length}', '감정분석',
                            AppTheme.primaryColor),
                      if (analyses.isNotEmpty && healthItems.isNotEmpty)
                        SizedBox(width: 8.w),
                      if (healthItems.isNotEmpty)
                        _reportStat('${healthItems.length}', '건강분석',
                            AppTheme.successColor),
                    ]),
                    if (dominant != null) ...[
                      SizedBox(height: 8.h),
                      Text('$dominant 감정이 많았어요',
                          style: TextStyle(
                              fontSize: 11.sp,
                              color: AppTheme.primaryTextColor,
                              height: 1.4)),
                    ],
                  ]),
            );
          },
        );
      },
    );
  }

  Map<String, List<HealthAnalysisModel>> _groupHealthByMonth(
      List<HealthAnalysisModel> list) {
    final result = <String, List<HealthAnalysisModel>>{};
    for (final a in list) {
      final key = '${a.analyzedAt.year}년 ${a.analyzedAt.month}월';
      result.putIfAbsent(key, () => []).add(a);
    }
    return result;
  }

  Widget _reportStat(String num, String label, Color color) => Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: AppTheme.subtleBackground,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Column(children: [
            Text(num,
                style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 8.5.sp,
                    color: AppTheme.secondaryTextColor)),
          ]),
        ),
      );

  Map<String, List<EmotionAnalysis>> _groupByMonth(
      List<EmotionAnalysis> list) {
    final result = <String, List<EmotionAnalysis>>{};
    for (final a in list) {
      final key = '${a.analyzedAt.year}년 ${a.analyzedAt.month}월';
      result.putIfAbsent(key, () => []).add(a);
    }
    return result;
  }

  String _dominantLabelFromList(List<EmotionAnalysis> list) {
    final counts = <String, int>{};
    for (final a in list) {
      final d = a.emotions.dominantEmotion;
      counts[d] = (counts[d] ?? 0) + 1;
    }
    if (counts.isEmpty) return '';
    final top = counts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    return AppTheme.getEmotionLabel(top);
  }

  // ────────────────────────────────────────────────────────
  // 전체이력 탭
  // ────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    return BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
      buildWhen: (prev, curr) => curr is EmotionAnalysisHistoryLoaded || curr is EmotionAnalysisHistoryLoading,
      builder: (context, state) {
        final emotionHistory = state is EmotionAnalysisHistoryLoaded
            ? state.history
            : <EmotionAnalysis>[];
        final items = _mergeHistory(emotionHistory, _healthHistory);
        final filtered = _applyFilter(items);
        final monthGroups = _groupItemsByMonth(filtered);

        return Column(children: [
          // 필터 칩 (줄에 꽉 차게 균등 분배)
          Container(
            color: Colors.white,
            padding:
                EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Row(
              children: ['전체', '감정분석', '건강분석', '주의만'].map((f) {
                final isOn = _filterType == f;
                final isWarn = f == '주의만';
                final isLast = f == '주의만';
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _filterType = f),
                    child: Container(
                      margin: EdgeInsets.only(right: isLast ? 0 : 6.w),
                      padding: EdgeInsets.symmetric(vertical: 7.h),
                      decoration: BoxDecoration(
                        color: isOn
                            ? (isWarn
                                ? AppTheme.highlightColor
                                : AppTheme.primaryColor)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: isOn
                              ? (isWarn
                                  ? AppTheme.highlightColor
                                  : AppTheme.primaryColor)
                              : AppTheme.dividerColor,
                        ),
                      ),
                      child: Text(
                        f,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: isOn
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isOn
                              ? Colors.white
                              : AppTheme.secondaryTextColor,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 0.5, thickness: 0.5),
          Expanded(
            child: (_healthHistoryLoading && _healthHistory.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmptyState('해당하는 기록이 없어요')
                    : ListView(
                        padding: EdgeInsets.all(12.w),
                        children: monthGroups.entries.expand((entry) => [
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: 6.h,
                                  top: entry.key ==
                                          monthGroups.keys.first
                                      ? 0
                                      : 8.h,
                                ),
                                child: Text(entry.key,
                                    style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            AppTheme.secondaryTextColor)),
                              ),
                              ...entry.value
                                  .map((item) => _buildHistoryCard(item)),
                            ]).toList(),
                      ),
          ),
        ]);
      },
    );
  }

  List<_HistoryItem> _mergeHistory(
    List<EmotionAnalysis> emotions,
    List<HealthAnalysisModel> healths,
  ) {
    final emotionItems = emotions.map((a) {
      final label = AppTheme.getEmotionLabel(a.emotions.dominantEmotion);
      final thumb = a.imageUrl.isNotEmpty ? a.imageUrl : null;
      return _HistoryItem(
        isEmotion: true,
        date: a.analyzedAt,
        petName: a.petName,
        title: '감정분석${a.petName != null ? " · ${a.petName}" : ""}',
        subtitle: '${a.analyzedAt.month}/${a.analyzedAt.day} · $label',
        badge: label,
        badgeType: 'emot',
        thumbnailUrl: thumb,
        emotionData: a,
      );
    });

    final healthItems = healths.map((h) {
      String badgeType;
      if (h.status == '양호') {
        badgeType = 'good';
      } else if (h.status == '주의') {
        badgeType = 'warn';
      } else if (h.status == '위험') {
        badgeType = 'bad';
      } else {
        badgeType = 'good';
      }
      final thumb = h.imageUrls.isNotEmpty ? h.imageUrls.first : null;
      return _HistoryItem(
        isEmotion: false,
        date: h.analyzedAt,
        petName: h.petName,
        title: '건강분석 · ${h.area.displayName}'
            '${h.petName != null ? " · ${h.petName}" : ""}',
        subtitle: '${h.analyzedAt.month}/${h.analyzedAt.day} · ${h.status}',
        badge: h.status,
        badgeType: badgeType,
        thumbnailUrl: thumb,
        healthData: h,
      );
    });

    return [...emotionItems, ...healthItems]
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<_HistoryItem> _applyFilter(List<_HistoryItem> items) {
    switch (_filterType) {
      case '감정분석':
        return items.where((i) => i.isEmotion).toList();
      case '건강분석':
        return items.where((i) => !i.isEmotion).toList();
      case '주의만':
        return items
            .where((i) =>
                i.badgeType == 'warn' || i.badgeType == 'bad')
            .toList();
      default:
        return items;
    }
  }

  Map<String, List<_HistoryItem>> _groupItemsByMonth(
      List<_HistoryItem> items) {
    final result = <String, List<_HistoryItem>>{};
    for (final item in items) {
      final key =
          '${item.date.year}년 ${item.date.month}월';
      result.putIfAbsent(key, () => []).add(item);
    }
    return result;
  }

  Widget _buildHistoryCard(_HistoryItem item) {
    final colors = <String, (Color, Color)>{
      'emot': (AppTheme.primaryColor.withValues(alpha: 0.1),
          AppTheme.primaryColor),
      'good': (AppTheme.successColor.withValues(alpha: 0.1),
          AppTheme.successColor),
      'warn': (AppTheme.warningColor.withValues(alpha: 0.1), // v2-review: EF9F27 근사
          EmotionResultTokens.amberDark),
      'bad': (AppTheme.errorColor.withValues(alpha: 0.1),
          AppTheme.errorColor),
    };
    final (bgColor, textColor) =
        colors[item.badgeType] ?? (Colors.grey.shade100, Colors.grey);

    final isDisabledInSelectMode = widget.selectMode && !item.isEmotion;
    return Opacity(
      opacity: isDisabledInSelectMode ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: () async {
          // selectMode: 감정 카드만 선택 가능. 건강 카드는 안내.
          if (widget.selectMode) {
            if (item.isEmotion && item.emotionData != null) {
              Navigator.of(context).pop(item.emotionData);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('감정 분석만 선택할 수 있어요')),
              );
            }
            return;
          }
          // 일반 모드: 결과 페이지로 진입
          if (item.isEmotion && item.emotionData != null) {
            final analysis = item.emotionData!;
            // 직전 분석 1건 조회 (과거 열람 맥락 — delta 비교가 자연스러움).
            // 비교 UI는 부가 기능이라 300ms 타임아웃, 실패·지연 시 null로 진행.
            EmotionAnalysis? previous;
            try {
              previous = await sl<GetPreviousAnalysis>()(current: analysis)
                  .timeout(const Duration(milliseconds: 300));
            } catch (_) {
              previous = null;
            }
            if (!mounted) return;
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (_) => sl<EmotionAnalysisBloc>(),
                child: EmotionResultPage(
                  analysis: analysis,
                  previousAnalysis: previous,
                  fromHistory: true,
                ),
              ),
            ));
          } else if (!item.isEmotion && item.healthData != null) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  HealthResultPage(result: item.healthData!, fromHistory: true),
            ));
          }
        },
      child: Container(
        margin: EdgeInsets.only(bottom: 7.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(children: [
          // 썸네일
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: SizedBox(
              width: 44.w,
              height: 44.w,
              child: item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty
                  ? Image.network(
                      item.thumbnailUrl!,
                      width: 44.w,
                      height: 44.w,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : _thumbFallback(item),
                      errorBuilder: (_, __, ___) => _thumbFallback(item),
                    )
                  : _thumbFallback(item),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryTextColor)),
                  Text(item.subtitle,
                      style: TextStyle(
                          fontSize: 9.sp,
                          color: AppTheme.secondaryTextColor,
                          height: 1.4)),
                ]),
          ),
          SizedBox(width: 6.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(item.badge,
                style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor)),
          ),
          SizedBox(width: 4.w),
          Icon(Icons.chevron_right,
              size: 14.w, color: AppTheme.secondaryTextColor),
        ]),
      ),
      ),
    );
  }

  Widget _thumbFallback(_HistoryItem item) {
    return Container(
      color: item.isEmotion
          ? AppTheme.primaryColor.withValues(alpha: 0.08)
          : AppTheme.successColor.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          item.isEmotion
              ? Icons.psychology_outlined
              : Icons.health_and_safety_outlined,
          size: 22.w,
          color: item.isEmotion
              ? AppTheme.primaryColor.withValues(alpha: 0.5)
              : AppTheme.successColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) => EmptyStateWidget(
        icon: Icons.history,
        title: msg,
        subtitle: '반려동물의 감정과 건강을 AI로 분석하고\n변화를 추적해보세요!',
        actionLabel: '첫 분석 시작',
        onAction: () => context.go('/emotion'),
      );
}
