import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../domain/entities/emotion_analysis.dart';
import '../../domain/entities/health_analysis.dart';
import '../bloc/emotion_analysis_bloc.dart';

// ── 통합 히스토리 아이템 모델 ──────────────────────────────────
class _HistoryItem {
  final bool isEmotion;
  final DateTime date;
  final String? petName;
  final String title;
  final String subtitle;
  final String badge;
  final String badgeType; // 'emot' | 'good' | 'warn' | 'bad'

  const _HistoryItem({
    required this.isEmotion,
    required this.date,
    this.petName,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeType,
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
  const AiHistoryPage({super.key});

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

  String _filterType = '전체';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSelectedPet();
      _loadDashboard();
    });
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
    try {
      final auth = context.read<AuthBloc>().state;
      if (auth is! AuthAuthenticated) return;

      final result = await Supabase.instance.client.rpc(
        'get_latest_health_by_area',
        params: {
          'p_user_id': auth.user.uid,
          'p_pet_id': _showUnregistered ? null : _selectedPet?.id,
        },
      );

      final rows = (result as List).cast<Map<String, dynamic>>();
      final statuses = HealthArea.values.map((area) {
        final found = rows
            .where((r) => r['area'] == area.displayName)
            .firstOrNull;
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

      if (mounted) setState(() => _areaStatuses = statuses);
    } catch (e) {
      log('Dashboard load error: $e', name: 'AiHistory');
    } finally {
      if (mounted) setState(() => _dashboardLoading = false);
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
                      'AI분석 히스토리',
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
            children: [
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(14.w),
      child: Column(children: [
        _buildPetDropdown(),
        SizedBox(height: 10.h),
        _showUnregistered
            ? _buildUnregisteredGuide()
            : _buildHealthDashboard(),
        SizedBox(height: 10.h),
        _buildRiskBanner(),
        _buildEmotionChart(),
      ]),
    );
  }

  Widget _buildPetDropdown() {
    final petState = context.read<PetBloc>().state;
    final pets = petState is PetLoaded ? petState.pets : <Pet>[];

    return GestureDetector(
      onTap: () => _showPetPicker(pets),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.pets, size: 16.w, color: AppTheme.primaryColor),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _showUnregistered
                      ? '미등록 분석'
                      : (_selectedPet?.name ?? '반려동물 선택'),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                if (!_showUnregistered && _selectedPet != null)
                  Text(
                    '${_selectedPet!.typeDisplayName} · ${_selectedPet!.displayAge}',
                    style: TextStyle(
                        fontSize: 10.sp, color: AppTheme.secondaryTextColor),
                  ),
              ],
            ),
          ),
          Icon(Icons.keyboard_arrow_down,
              color: AppTheme.secondaryTextColor, size: 20.w),
        ]),
      ),
    );
  }

  void _showPetPicker(List<Pet> pets) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: 8.h),
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 12.h),
          ...pets.map((pet) => ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                      pet.type == PetType.dog ? '🐶' : '🐱'),
                ),
                title: Text(pet.name,
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w500)),
                subtitle: Text(
                    '${pet.typeDisplayName} · ${pet.displayAge}',
                    style: TextStyle(fontSize: 11.sp)),
                onTap: () {
                  setState(() {
                    _selectedPet = pet;
                    _showUnregistered = false;
                  });
                  Navigator.pop(ctx);
                  _loadDashboard();
                },
              )),
          const Divider(),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade100,
              child: Icon(Icons.remove_circle_outline,
                  color: Colors.grey, size: 18.w),
            ),
            title: Text('미등록 분석',
                style: TextStyle(
                    fontSize: 14.sp, fontWeight: FontWeight.w500)),
            subtitle: Text('반려동물 없이 진행한 분석',
                style:
                    TextStyle(fontSize: 11.sp, color: Colors.grey)),
            onTap: () {
              setState(() {
                _showUnregistered = true;
                _selectedPet = null;
              });
              Navigator.pop(ctx);
              _loadDashboard();
            },
          ),
          SizedBox(height: 8.h),
        ]),
      ),
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
            backgroundColor: AppTheme.primaryColor,
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
      Text('건강 현황',
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
      bgColor = const Color(0xFFF9F9F9);
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
      borderColor = const Color(0xFFEF9F27);
      iconColor = const Color(0xFFEF9F27);
      statusWidget = Text('주의',
          style: TextStyle(
              fontSize: 8.5.sp,
              color: const Color(0xFF854F0B),
              fontWeight: FontWeight.w500));
    } else if (s.status == '위험') {
      borderColor = AppTheme.highlightColor;
      bgColor = const Color(0xFFFFF5F4);
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
                            backgroundColor: AppTheme.primaryColor,
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

  Widget _buildRiskBanner() {
    final hasRisk = _areaStatuses.any((s) => s.riskAlert == true);
    if (!hasRisk) return const SizedBox.shrink();

    final riskAreas = _areaStatuses
        .where((s) => s.riskAlert == true)
        .map((s) => s.area.displayName)
        .join(', ');

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppTheme.highlightColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18.w),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            '$riskAreas → 수의사 상담 권장',
            style: TextStyle(
                fontSize: 11.sp,
                color: Colors.white,
                fontWeight: FontWeight.w500),
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/hospital'),
          child: Container(
            padding:
                EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: Text('병원찾기',
                style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.highlightColor)),
          ),
        ),
      ]),
    );
  }

  Widget _buildEmotionChart() {
    return BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
      builder: (context, state) {
        if (state is! EmotionAnalysisHistoryLoaded) {
          return const SizedBox.shrink();
        }
        final history = state.history;
        if (history.isEmpty) return const SizedBox.shrink();

        final recent = history.take(6).toList().reversed.toList();
        final maxIdx = recent.length - 1;

        return Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('최근 감정 흐름',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryTextColor)),
              const Spacer(),
              Text(_dominantLabel(history),
                  style: TextStyle(
                      fontSize: 10.sp,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500)),
            ]),
            SizedBox(height: 4.h),
            Text('최근 ${recent.length}회 분석',
                style: TextStyle(
                    fontSize: 9.sp, color: AppTheme.secondaryTextColor)),
            SizedBox(height: 10.h),
            SizedBox(
              height: 60.h,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: recent.asMap().entries.map((e) {
                  final score = _positiveScore(e.value);
                  final isNeg =
                      _isNegative(e.value.emotions.dominantEmotion);
                  final color = isNeg
                      ? AppTheme.highlightColor
                      : AppTheme.primaryColor;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: 50.h * score,
                            decoration: BoxDecoration(
                              color: color.withValues(
                                  alpha:
                                      e.key == maxIdx ? 1.0 : 0.4),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            '${e.value.analyzedAt.month}/${e.value.analyzedAt.day}',
                            style: TextStyle(
                                fontSize: 7.sp,
                                color: AppTheme.secondaryTextColor),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 8.h),
            Row(children: [
              _chartLegend(AppTheme.primaryColor, '긍정 감정'),
              SizedBox(width: 12.w),
              _chartLegend(AppTheme.highlightColor, '부정 감정'),
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
              color: c, borderRadius: BorderRadius.circular(2.r)),
        ),
        SizedBox(width: 4.w),
        Text(label,
            style: TextStyle(
                fontSize: 9.sp, color: AppTheme.secondaryTextColor)),
      ]);

  String _dominantLabel(List<EmotionAnalysis> history) {
    final counts = <String, int>{};
    for (final a in history) {
      final d = a.emotions.dominantEmotion;
      counts[d] = (counts[d] ?? 0) + 1;
    }
    if (counts.isEmpty) return '';
    final top = counts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    return AppTheme.getEmotionLabel(top);
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
        final history = state is EmotionAnalysisHistoryLoaded
            ? state.history
            : <EmotionAnalysis>[];
        final monthGroups = _groupByMonth(history);

        if (monthGroups.isEmpty) {
          return _buildEmptyState('분석 기록이 없어요');
        }

        final entries = monthGroups.entries.toList();
        return ListView.builder(
          padding: EdgeInsets.all(14.w),
          itemCount: entries.length,
          itemBuilder: (_, i) {
            final isFirst = i == 0;
            final month = entries[i].key;
            final analyses = entries[i].value;
            final dominant = _dominantLabelFromList(analyses);

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
                      Text('${analyses.length}회 분석',
                          style: TextStyle(
                              fontSize: 9.sp,
                              color: AppTheme.secondaryTextColor)),
                    ]),
                    SizedBox(height: 10.h),
                    Row(children: [
                      _reportStat('${analyses.length}', '감정분석',
                          AppTheme.primaryColor),
                    ]),
                    SizedBox(height: 8.h),
                    Text('$dominant 감정이 많았어요',
                        style: TextStyle(
                            fontSize: 11.sp,
                            color: AppTheme.primaryTextColor,
                            height: 1.4)),
                  ]),
            );
          },
        );
      },
    );
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
      builder: (context, state) {
        final emotionHistory = state is EmotionAnalysisHistoryLoaded
            ? state.history
            : <EmotionAnalysis>[];
        final items = _mergeHistory(emotionHistory);
        final filtered = _applyFilter(items);
        final monthGroups = _groupItemsByMonth(filtered);

        return Column(children: [
          // 필터 칩
          Container(
            color: Colors.white,
            padding:
                EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['전체', '감정분석', '건강분석', '주의만'].map((f) {
                  final isOn = _filterType == f;
                  final isWarn = f == '주의만';
                  return GestureDetector(
                    onTap: () => setState(() => _filterType = f),
                    child: Container(
                      margin: EdgeInsets.only(right: 7.w),
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: isOn
                            ? (isWarn
                                ? AppTheme.highlightColor
                                : AppTheme.primaryColor)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
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
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 0.5, thickness: 0.5),
          Expanded(
            child: filtered.isEmpty
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

  List<_HistoryItem> _mergeHistory(List<EmotionAnalysis> emotions) {
    return emotions.map((a) {
      final label =
          AppTheme.getEmotionLabel(a.emotions.dominantEmotion);
      return _HistoryItem(
        isEmotion: true,
        date: a.analyzedAt,
        petName: a.petName,
        title:
            '감정분석${a.petName != null ? " · ${a.petName}" : ""}',
        subtitle:
            '${a.analyzedAt.month}/${a.analyzedAt.day} · $label',
        badge: label,
        badgeType: 'emot',
      );
    }).toList()
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
      'warn': (const Color(0xFFEF9F27).withValues(alpha: 0.1),
          const Color(0xFF854F0B)),
      'bad': (AppTheme.errorColor.withValues(alpha: 0.1),
          AppTheme.errorColor),
    };
    final (bgColor, textColor) =
        colors[item.badgeType] ?? (Colors.grey.shade100, Colors.grey);

    return Container(
      margin: EdgeInsets.only(bottom: 7.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(children: [
        Container(
          width: 30.w,
          height: 30.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            color: item.isEmotion
                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                : AppTheme.successColor.withValues(alpha: 0.08),
          ),
          child: Icon(
            item.isEmotion
                ? Icons.psychology_outlined
                : Icons.health_and_safety_outlined,
            size: 16.w,
            color: item.isEmotion
                ? AppTheme.primaryColor
                : AppTheme.successColor,
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
        Container(
          padding:
              EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
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
      ]),
    );
  }

  Widget _buildEmptyState(String msg) => Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 40.w, color: Colors.grey.shade300),
              SizedBox(height: 12.h),
              Text(msg,
                  style: TextStyle(
                      fontSize: 13.sp,
                      color: AppTheme.secondaryTextColor)),
            ]),
      );
}
