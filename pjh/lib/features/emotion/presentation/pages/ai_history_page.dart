import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../config/injection_container.dart';
import '../../../../core/error/failures.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_state.dart';
import '../../data/models/health_analysis_model.dart';
import '../../domain/entities/ai_history.dart';
import '../../domain/entities/health_analysis.dart';
import '../../domain/repositories/emotion_repository.dart';
import '../bloc/ai_history_bloc.dart';
import '../models/ai_history_presentation.dart';
import '../widgets/analysis_input/analysis_sub_tab.dart';
import '../widgets/history/ai_history_filter_bar.dart';
import '../widgets/history/ai_history_filter_sheet.dart';
import '../widgets/history/ai_history_pet_inline_dropdown.dart';
import '../widgets/history/ai_history_record_card.dart';
import 'health_result_page.dart';

class AiHistoryPage extends StatelessWidget {
  final bool selectMode;
  final AiHistoryBloc? historyBloc;

  const AiHistoryPage({
    super.key,
    this.selectMode = false,
    this.historyBloc,
  });

  @override
  Widget build(BuildContext context) {
    final view = _AiHistoryView(selectMode: selectMode);
    if (historyBloc != null) {
      return BlocProvider.value(value: historyBloc!, child: view);
    }
    return BlocProvider(
      create: (_) => AiHistoryBloc(
        repository: sl<EmotionRepository>(),
        preferences: sl<SharedPreferences>(),
        emotionOnly: selectMode,
      ),
      child: view,
    );
  }
}

class _AiHistoryView extends StatefulWidget {
  final bool selectMode;

  const _AiHistoryView({required this.selectMode});

  @override
  State<_AiHistoryView> createState() => _AiHistoryViewState();
}

class _AiHistoryViewState extends State<_AiHistoryView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncContext());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 360) {
      context.read<AiHistoryBloc>().add(const AiHistoryNextPageRequested());
    }
  }

  void _syncContext() {
    if (!mounted) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final petState = context.read<PetBloc>().state;
    final pets = switch (petState) {
      PetLoaded(:final pets) => pets,
      PetOperationSuccess(:final pets) => pets,
      _ => const <Pet>[],
    };
    context.read<AiHistoryBloc>().add(
          AiHistoryContextChanged(
            userId: authState.user.uid,
            pets: pets,
            petsFailed: petState is PetError,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(listener: (_, __) => _syncContext()),
        BlocListener<PetBloc, PetState>(listener: (_, __) => _syncContext()),
      ],
      child: BlocBuilder<AiHistoryBloc, AiHistoryState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppTheme.subtleBackground,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Text(
                widget.selectMode ? '감정 분석 선택' : 'AI 분석 기록',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              centerTitle: true,
            ),
            body: Column(
              children: [
                _buildControls(state),
                Expanded(
                  child: widget.selectMode ||
                          state.segment == AiHistorySegment.records
                      ? _buildRecords(state)
                      : _buildFlow(state),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControls(AiHistoryState state) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
        child: Column(
          children: [
            if (!widget.selectMode) ...[
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(30.r),
                ),
                padding: EdgeInsets.all(3.w),
                child: Row(
                  children: [
                    AnalysisSubTab(
                      label: '기록',
                      index: 0,
                      currentIndex:
                          state.segment == AiHistorySegment.records ? 0 : 1,
                      onSelected: (_) => context.read<AiHistoryBloc>().add(
                            const AiHistorySegmentChanged(
                                AiHistorySegment.records),
                          ),
                    ),
                    AnalysisSubTab(
                      label: '흐름',
                      index: 1,
                      currentIndex:
                          state.segment == AiHistorySegment.records ? 0 : 1,
                      onSelected: (_) => context.read<AiHistoryBloc>().add(
                            const AiHistorySegmentChanged(
                                AiHistorySegment.flow),
                          ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),
            ],
            AiHistoryPetInlineDropdown(
              pets: state.pets,
              scope: state.scope,
              flowMode:
                  !widget.selectMode && state.segment == AiHistorySegment.flow,
              enabled: !state.petsFailed,
              onChanged: (scope) => context.read<AiHistoryBloc>().add(
                    AiHistoryScopeChanged(scope),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecords(AiHistoryState state) {
    if (state.userId.isEmpty || state.status == AiHistoryLoadStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == AiHistoryLoadStatus.loading && state.records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == AiHistoryLoadStatus.failure && state.records.isEmpty) {
      return _errorState(
        '기록을 불러오지 못했어요',
        () => context.read<AiHistoryBloc>().add(
              const AiHistoryRefreshRequested(),
            ),
      );
    }

    final children = <Widget>[
      _buildRecordFilters(state),
      if (!widget.selectMode) _buildSafetyNotice(),
      if (!widget.selectMode && _hasAttentionRecord(state))
        _buildAttentionBanner(),
      if (state.errorMessage != null && state.records.isNotEmpty)
        _inlineError(
          '일부 기록을 새로 불러오지 못했어요. 현재 목록은 계속 확인할 수 있어요.',
        ),
    ];
    if (state.records.isEmpty) {
      children.add(_buildEmptyState(state));
      if (state.reachedUnlinkedScanLimit) {
        children.add(_scanLimitNotice());
      }
      if (state.isLoadingMore) {
        children.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: const Center(child: CircularProgressIndicator()),
          ),
        );
      } else if (state.hasMore) {
        children.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: OutlinedButton(
              onPressed: () => context.read<AiHistoryBloc>().add(
                    const AiHistoryNextPageRequested(),
                  ),
              child: const Text('다음 기록 범위 확인'),
            ),
          ),
        );
      }
    } else {
      String? currentGroup;
      for (final record in state.records) {
        final group = _dateGroup(record.analyzedAt);
        if (group != currentGroup) {
          currentGroup = group;
          children.add(
            Padding(
              padding: EdgeInsets.only(top: 18.h, bottom: 10.h),
              child: Text(
                group,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryTextColor,
                ),
              ),
            ),
          );
        }
        children.add(
          Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: AiHistoryRecordCard(
              record: record,
              petLabel: _recordPetLabel(state, record),
              selectionMode: widget.selectMode,
              onTap: () => _openRecord(state, record),
            ),
          ),
        );
      }
      if (state.reachedUnlinkedScanLimit) {
        children.add(_scanLimitNotice());
      }
      if (state.isLoadingMore) {
        children.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: const Center(child: CircularProgressIndicator()),
          ),
        );
      } else if (state.hasMore) {
        children.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: OutlinedButton(
              onPressed: () => context.read<AiHistoryBloc>().add(
                    const AiHistoryNextPageRequested(),
                  ),
              child: const Text('기록 더 보기'),
            ),
          ),
        );
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<AiHistoryBloc>().add(const AiHistoryRefreshRequested());
        await context.read<AiHistoryBloc>().stream.firstWhere(
              (value) => !value.isRefreshing,
            );
      },
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
        children: children,
      ),
    );
  }

  Widget _buildRecordFilters(AiHistoryState state) {
    return AiHistoryFilterBar(
      type: state.typeFilter,
      dateRange: state.dateRange,
      healthAttentionOnly: state.healthAttentionOnly,
      emotionOnly: widget.selectMode,
      onTap: () => _showFilters(state),
    );
  }

  Widget _buildSafetyNotice() {
    return Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.all(13.w),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20.sp, color: AppTheme.primaryColor),
          SizedBox(width: 9.w),
          Expanded(
            child: Text(
              AiHistoryPresentation.safetyCopy,
              style: TextStyle(
                fontSize: 12.sp,
                height: 1.5,
                color: AppTheme.secondaryTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionBanner() {
    void openAttentionRecords() => context.read<AiHistoryBloc>().add(
          const AiHistoryAttentionChanged(true),
        );
    return Semantics(
      button: true,
      label: '확인할 건강 기록 보기',
      onTap: openAttentionRecords,
      excludeSemantics: true,
      child: InkWell(
        onTap: openAttentionRecords,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          margin: EdgeInsets.only(top: 10.h),
          padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3DD),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_outlined, color: Color(0xFF8B5A12)),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '현재 목록 기준 · 확인하거나 지켜볼 건강 기록이 있어요',
                  style: TextStyle(
                    fontSize: 12.sp,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6F4A14),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF8B5A12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AiHistoryState state) {
    final scoped = state.scope.kind != AiHistoryPetScopeKind.all;
    final filtered = state.dateRange != AiHistoryDateRange.all ||
        (!widget.selectMode &&
            (state.typeFilter != AiHistoryTypeFilter.all ||
                state.healthAttentionOnly));
    final title = state.hasMore
        ? '조건에 맞는 기록을 더 확인할 수 있어요'
        : filtered
            ? '현재 필터에 맞는 기록이 없어요'
            : scoped
                ? '이 범위에 연결된 기록이 없어요'
                : '아직 저장된 분석 기록이 없어요';
    final description = state.hasMore
        ? '앞선 저장 구간에는 일치하는 항목이 없었어요. 아래 버튼으로 다음 기록 범위를 이어서 확인해 주세요.'
        : filtered
            ? '필터를 초기화하거나 다른 기간과 유형을 선택해 보세요.'
            : scoped
                ? '전체 기록이나 다른 반려동물 범위를 확인해 보세요.'
                : 'AI 분석 후 저장된 결과를 여기에서 다시 볼 수 있어요.';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 72.h, horizontal: 20.w),
      child: Column(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 52.sp,
            color: AppTheme.neutral400,
          ),
          SizedBox(height: 16.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              height: 1.5,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          SizedBox(height: 22.h),
          if (filtered) ...[
            OutlinedButton(
              onPressed: () => context.read<AiHistoryBloc>().add(
                    AiHistoryFiltersApplied(
                      type: widget.selectMode
                          ? AiHistoryTypeFilter.emotion
                          : AiHistoryTypeFilter.all,
                      dateRange: AiHistoryDateRange.all,
                      healthAttentionOnly: false,
                    ),
                  ),
              child: const Text('필터 초기화'),
            ),
            SizedBox(height: 10.h),
          ],
          if (scoped && !state.hasMore)
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => context.read<AiHistoryBloc>().add(
                        const AiHistoryScopeChanged(AiHistoryPetScope.all()),
                      ),
                  child: const Text('전체 기록 보기'),
                ),
                OutlinedButton(
                  onPressed: () => context.read<AiHistoryBloc>().add(
                        const AiHistoryScopeChanged(
                            AiHistoryPetScope.unlinked()),
                      ),
                  child: const Text('연결 안 된 기록 보기'),
                ),
              ],
            ),
          if (!filtered && !scoped && !widget.selectMode && !state.hasMore)
            FilledButton(
              onPressed: () => context.push('/emotion'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('AI 분석 시작'),
            ),
          if (widget.selectMode) ...[
            SizedBox(height: 12.h),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('게시물 작성으로 돌아가기'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlow(AiHistoryState state) {
    if (state.petsFailed) {
      return _errorState('반려동물 목록을 불러오지 못했어요', _syncContext);
    }
    if (state.scope.kind != AiHistoryPetScopeKind.registered) {
      return _buildPetFlowPrompt(state);
    }
    if (state.flowStatus == AiHistoryLoadStatus.loading ||
        state.flowStatus == AiHistoryLoadStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.flowStatus == AiHistoryLoadStatus.failure) {
      return _errorState(
        '흐름을 불러오지 못했어요',
        () => context.read<AiHistoryBloc>().add(
              const AiHistoryRefreshRequested(),
            ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        context.read<AiHistoryBloc>().add(const AiHistoryRefreshRequested());
        await context.read<AiHistoryBloc>().stream.firstWhere(
              (value) => value.flowStatus != AiHistoryLoadStatus.loading,
            );
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 32.h),
        children: [
          _flowPeriodSelector(state),
          SizedBox(height: 14.h),
          _flowSummaryCard(state),
          SizedBox(height: 12.h),
          _daySignalsCard(state),
          SizedBox(height: 12.h),
          _recentHealthCard(state),
          SizedBox(height: 12.h),
          _buildSafetyNotice(),
        ],
      ),
    );
  }

  Widget _buildPetFlowPrompt(AiHistoryState state) {
    return ListView(
      padding: EdgeInsets.all(24.w),
      children: [
        SizedBox(height: 54.h),
        Icon(Icons.timeline_rounded, size: 56.sp, color: AppTheme.primaryColor),
        SizedBox(height: 18.h),
        Text(
          state.pets.isEmpty
              ? '반려동물을 등록하면 기록 흐름을 볼 수 있어요'
              : '위에서 반려동물을 선택해 주세요',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryTextColor,
          ),
        ),
        SizedBox(height: 9.h),
        Text(
          state.pets.isEmpty
              ? '기존 연결 안 된 감정 기록은 새 반려동물에 자동으로 연결되지 않아요.'
              : '반려동물 선택 영역을 열어 아이 한 마리를 선택하면 흐름을 보여드려요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.sp,
            height: 1.55,
            color: AppTheme.secondaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _flowPeriodSelector(AiHistoryState state) {
    return Row(
      children: [7, 30, 90]
          .map(
            (days) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: days == 90 ? 0 : 8.w),
                child: ChoiceChip(
                  label: SizedBox(
                    width: double.infinity,
                    child: Text('$days일', textAlign: TextAlign.center),
                  ),
                  selected: state.flowDays == days,
                  showCheckmark: false,
                  onSelected: (_) => context.read<AiHistoryBloc>().add(
                        AiHistoryFlowPeriodChanged(days),
                      ),
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: state.flowDays == days
                        ? Colors.white
                        : AppTheme.primaryTextColor,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _flowSummaryCard(AiHistoryState state) {
    final count = state.daySignals.fold<int>(
      0,
      (sum, signal) => sum + signal.analysisCount,
    );
    final dominantCounts = <String, int>{};
    for (final signal in state.daySignals) {
      dominantCounts.update(
        signal.dominantEmotion,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final dominant = dominantCounts.entries.isEmpty
        ? null
        : (dominantCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '최근 ${state.flowDays}일 기록을 날짜별로 모아봤어요',
            style: TextStyle(
              fontSize: 13.sp,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          SizedBox(height: 7.h),
          Text(
            dominant == null
                ? '아직 흐름을 만들 기록이 부족해요'
                : '${AiHistoryPresentation.emotionLabel(dominant)} 신호가 자주 관찰됐어요',
            style: TextStyle(
              fontSize: 17.sp,
              height: 1.4,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 7.h),
          Text(
            '최근 ${state.flowDays}일 기록 $count건',
            style: TextStyle(
              fontSize: 12.sp,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _daySignalsCard(AiHistoryState state) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '감정 흐름',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '기록이 있는 날만 표시해요',
            style: TextStyle(
              fontSize: 12.sp,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          SizedBox(height: 14.h),
          if (state.daySignals.length < 2)
            _smallEmpty('기록이 다른 날에 1건 더 쌓이면 흐름을 볼 수 있어요')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0;
                        index < state.daySignals.length;
                        index++) ...[
                      if (index > 0) SizedBox(width: 10.w),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: 108.w,
                          maxWidth: 132.w,
                          minHeight: 118.h,
                        ),
                        child: Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: AppTheme.subtleBackground,
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Builder(
                            builder: (context) {
                              final signal = state.daySignals[index];
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${signal.day.month}/${signal.day.day}',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: AppTheme.secondaryTextColor,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Icon(
                                    signal.hasMixedSignals
                                        ? Icons.blur_circular_rounded
                                        : AppTheme.getEmotionIcon(
                                            signal.dominantEmotion,
                                          ),
                                    color: AppTheme.getEmotionColor(
                                      signal.dominantEmotion,
                                    ),
                                  ),
                                  SizedBox(height: 5.h),
                                  Flexible(
                                    child: Text(
                                      signal.hasMixedSignals
                                          ? '여러 신호 함께'
                                          : AiHistoryPresentation.emotionLabel(
                                              signal.dominantEmotion,
                                            ),
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryTextColor,
                                      ),
                                    ),
                                  ),
                                  if (signal.analysisCount > 1) ...[
                                    SizedBox(height: 3.h),
                                    Text(
                                      '${signal.analysisCount}건 평균',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: AppTheme.secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _recentHealthCard(AiHistoryState state) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '건강 최근 상태 · 연결된 기록 기준',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 12.h),
          if (state.recentHealth.isEmpty)
            _smallEmpty('연결된 건강 기록이 아직 없어요')
          else
            ...state.recentHealth.map((record) {
              final health = record.health!;
              return InkWell(
                onTap: () => _openRecord(state, record),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 9.h),
                  child: Row(
                    children: [
                      Icon(
                        AiHistoryPresentation.healthStateIcon(health),
                        color: AiHistoryPresentation.healthStateColor(health),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          AiHistoryPresentation.healthAreaLabel(health),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AiHistoryPresentation.healthStateLabel(health),
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: AiHistoryPresentation.healthStateColor(
                                health,
                              ),
                            ),
                          ),
                          Text(
                            '${health.analyzedAt.toLocal().month}/${health.analyzedAt.toLocal().day}',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _smallEmpty(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppTheme.subtleBackground,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13.sp,
          height: 1.5,
          color: AppTheme.secondaryTextColor,
        ),
      ),
    );
  }

  Widget _errorState(String message, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48.sp,
              color: AppTheme.neutral400,
            ),
            SizedBox(height: 14.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                height: 1.5,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 16.h),
            OutlinedButton(onPressed: retry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }

  Widget _inlineError(String message) {
    return Container(
      margin: EdgeInsets.only(top: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppTheme.subtleBackground,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 12.sp)),
          ),
        ],
      ),
    );
  }

  Widget _scanLimitNotice() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Text(
        '최근 250건에서 찾은 기록이에요. 더 오래된 기록은 다음 기록 범위 확인을 이용해 주세요.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.sp,
          height: 1.45,
          color: AppTheme.secondaryTextColor,
        ),
      ),
    );
  }

  bool _hasAttentionRecord(AiHistoryState state) => state.records.any(
        (record) =>
            record.health != null &&
            AiHistoryPresentation.healthState(record.health!) !=
                HealthObservationState.stable,
      );

  Future<void> _showFilters(AiHistoryState state) async {
    final value = await AiHistoryFilterSheet.show(
      context,
      emotionOnly: widget.selectMode,
      initial: AiHistoryFilterSelection(
        type: state.typeFilter,
        dateRange: state.dateRange,
        healthAttentionOnly: state.healthAttentionOnly,
      ),
    );
    if (!mounted || value == null) return;
    context.read<AiHistoryBloc>().add(
          AiHistoryFiltersApplied(
            type: value.type,
            dateRange: value.dateRange,
            healthAttentionOnly: value.healthAttentionOnly,
          ),
        );
  }

  void _openRecord(AiHistoryState state, AiHistoryRecord record) {
    if (widget.selectMode) {
      if (record.emotion == null) return;
      Navigator.of(context).pop(
        record.emotion!.copyWith(
          petName: _resolvedPetName(state, record.petId),
        ),
      );
      return;
    }
    if (record.kind == AiHistoryKind.emotion) {
      context.push('/emotion/result/${record.id}');
      return;
    }
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _HealthHistoryLoaderPage(
            record: record,
            petLabel: _recordPetLabel(state, record),
          ),
        ),
      ),
    );
  }

  String _recordPetLabel(AiHistoryState state, AiHistoryRecord record) {
    return _resolvedPetName(state, record.petId) ??
        (record.petName?.trim().isNotEmpty == true
            ? record.petName!.trim()
            : '반려동물 정보 없음');
  }

  String? _resolvedPetName(AiHistoryState state, String? petId) {
    if (petId == null || petId.isEmpty) return null;
    for (final pet in state.pets) {
      if (pet.id == petId) return pet.name;
    }
    return null;
  }

  String _dateGroup(DateTime value) {
    final date = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return '오늘';
    if (difference == 1) return '어제';
    if (difference >= 2 && difference <= 6) {
      return '${date.month}월 ${date.day}일';
    }
    return '${date.year}년 ${date.month}월';
  }
}

class _HealthHistoryLoaderPage extends StatefulWidget {
  final AiHistoryRecord record;
  final String petLabel;

  const _HealthHistoryLoaderPage({
    required this.record,
    required this.petLabel,
  });

  @override
  State<_HealthHistoryLoaderPage> createState() =>
      _HealthHistoryLoaderPageState();
}

class _HealthHistoryLoaderPageState extends State<_HealthHistoryLoaderPage> {
  HealthAnalysisModel? _analysis;
  String? _error;
  bool _canRetry = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<EmotionRepository>().getHealthAnalysisById(
      widget.record.id,
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _canRetry =
            failure is! NotFoundFailure && failure is! UnauthorizedFailure;
      }),
      (analysis) => setState(() {
        if (analysis is HealthAnalysisModel) {
          _analysis = analysis;
        } else {
          _error = '저장된 건강 기록 형식을 확인할 수 없어요.';
          _canRetry = false;
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_analysis != null) {
      return HealthResultPage(result: _analysis!, fromHistory: true);
    }
    return Scaffold(
      backgroundColor: AppTheme.subtleBackground,
      appBar: AppBar(title: const Text('저장된 건강 기록'), centerTitle: true),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            AiHistoryRecordCard(
              record: widget.record,
              petLabel: widget.petLabel,
              onTap: () {},
            ),
            SizedBox(height: 28.h),
            if (_error == null)
              const CircularProgressIndicator()
            else ...[
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.sp),
              ),
              if (_canRetry) ...[
                SizedBox(height: 14.h),
                OutlinedButton(
                  onPressed: () {
                    setState(() => _error = null);
                    _load();
                  },
                  child: const Text('다시 시도'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
