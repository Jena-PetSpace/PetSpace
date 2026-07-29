import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../pets/domain/entities/pet.dart';
import '../../domain/entities/ai_history.dart';
import '../../domain/entities/emotion_analysis.dart';
import '../../domain/repositories/emotion_repository.dart';
import '../models/ai_history_presentation.dart';

enum AiHistorySegment { records, flow }

enum AiHistoryLoadStatus { initial, loading, success, failure }

sealed class AiHistoryEvent extends Equatable {
  const AiHistoryEvent();

  @override
  List<Object?> get props => [];
}

class AiHistoryContextChanged extends AiHistoryEvent {
  final String userId;
  final List<Pet> pets;
  final bool petsFailed;

  const AiHistoryContextChanged({
    required this.userId,
    required this.pets,
    this.petsFailed = false,
  });

  @override
  List<Object?> get props => [userId, pets, petsFailed];
}

class AiHistoryScopeChanged extends AiHistoryEvent {
  final AiHistoryPetScope scope;

  const AiHistoryScopeChanged(this.scope);

  @override
  List<Object?> get props => [scope];
}

class AiHistorySegmentChanged extends AiHistoryEvent {
  final AiHistorySegment segment;

  const AiHistorySegmentChanged(this.segment);

  @override
  List<Object?> get props => [segment];
}

class AiHistoryTypeChanged extends AiHistoryEvent {
  final AiHistoryTypeFilter filter;

  const AiHistoryTypeChanged(this.filter);

  @override
  List<Object?> get props => [filter];
}

class AiHistoryDateRangeChanged extends AiHistoryEvent {
  final AiHistoryDateRange range;

  const AiHistoryDateRangeChanged(this.range);

  @override
  List<Object?> get props => [range];
}

class AiHistoryAttentionChanged extends AiHistoryEvent {
  final bool enabled;

  const AiHistoryAttentionChanged(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class AiHistoryFiltersApplied extends AiHistoryEvent {
  final AiHistoryTypeFilter type;
  final AiHistoryDateRange dateRange;
  final bool healthAttentionOnly;

  const AiHistoryFiltersApplied({
    required this.type,
    required this.dateRange,
    required this.healthAttentionOnly,
  });

  @override
  List<Object?> get props => [type, dateRange, healthAttentionOnly];
}

class AiHistoryRefreshRequested extends AiHistoryEvent {
  const AiHistoryRefreshRequested();
}

class AiHistoryNextPageRequested extends AiHistoryEvent {
  const AiHistoryNextPageRequested();
}

class AiHistoryFlowPeriodChanged extends AiHistoryEvent {
  final int days;

  const AiHistoryFlowPeriodChanged(this.days);

  @override
  List<Object?> get props => [days];
}

class AiHistoryState extends Equatable {
  static const _notProvided = Object();

  final String userId;
  final List<Pet> pets;
  final bool petsFailed;
  final AiHistoryPetScope scope;
  final AiHistorySegment segment;
  final AiHistoryTypeFilter typeFilter;
  final AiHistoryDateRange dateRange;
  final bool healthAttentionOnly;
  final AiHistoryLoadStatus status;
  final List<AiHistoryRecord> records;
  final AiHistoryCursor cursor;
  final bool hasMore;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool reachedUnlinkedScanLimit;
  final String? errorMessage;
  final int flowDays;
  final AiHistoryLoadStatus flowStatus;
  final List<AiHistoryDaySignal> daySignals;
  final List<AiHistoryRecord> recentHealth;
  final String? flowErrorMessage;

  const AiHistoryState({
    this.userId = '',
    this.pets = const [],
    this.petsFailed = false,
    this.scope = const AiHistoryPetScope.all(),
    this.segment = AiHistorySegment.records,
    this.typeFilter = AiHistoryTypeFilter.all,
    this.dateRange = AiHistoryDateRange.all,
    this.healthAttentionOnly = false,
    this.status = AiHistoryLoadStatus.initial,
    this.records = const [],
    this.cursor = const AiHistoryCursor.initial(),
    this.hasMore = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.reachedUnlinkedScanLimit = false,
    this.errorMessage,
    this.flowDays = 30,
    this.flowStatus = AiHistoryLoadStatus.initial,
    this.daySignals = const [],
    this.recentHealth = const [],
    this.flowErrorMessage,
  });

  Pet? get selectedPet {
    if (scope.kind != AiHistoryPetScopeKind.registered) return null;
    for (final pet in pets) {
      if (pet.id == scope.petId) return pet;
    }
    return null;
  }

  AiHistoryState copyWith({
    String? userId,
    List<Pet>? pets,
    bool? petsFailed,
    AiHistoryPetScope? scope,
    AiHistorySegment? segment,
    AiHistoryTypeFilter? typeFilter,
    AiHistoryDateRange? dateRange,
    bool? healthAttentionOnly,
    AiHistoryLoadStatus? status,
    List<AiHistoryRecord>? records,
    AiHistoryCursor? cursor,
    bool? hasMore,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? reachedUnlinkedScanLimit,
    Object? errorMessage = _notProvided,
    int? flowDays,
    AiHistoryLoadStatus? flowStatus,
    List<AiHistoryDaySignal>? daySignals,
    List<AiHistoryRecord>? recentHealth,
    Object? flowErrorMessage = _notProvided,
  }) {
    return AiHistoryState(
      userId: userId ?? this.userId,
      pets: pets ?? this.pets,
      petsFailed: petsFailed ?? this.petsFailed,
      scope: scope ?? this.scope,
      segment: segment ?? this.segment,
      typeFilter: typeFilter ?? this.typeFilter,
      dateRange: dateRange ?? this.dateRange,
      healthAttentionOnly: healthAttentionOnly ?? this.healthAttentionOnly,
      status: status ?? this.status,
      records: records ?? this.records,
      cursor: cursor ?? this.cursor,
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      reachedUnlinkedScanLimit:
          reachedUnlinkedScanLimit ?? this.reachedUnlinkedScanLimit,
      errorMessage: identical(errorMessage, _notProvided)
          ? this.errorMessage
          : errorMessage as String?,
      flowDays: flowDays ?? this.flowDays,
      flowStatus: flowStatus ?? this.flowStatus,
      daySignals: daySignals ?? this.daySignals,
      recentHealth: recentHealth ?? this.recentHealth,
      flowErrorMessage: identical(flowErrorMessage, _notProvided)
          ? this.flowErrorMessage
          : flowErrorMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        pets,
        petsFailed,
        scope,
        segment,
        typeFilter,
        dateRange,
        healthAttentionOnly,
        status,
        records,
        cursor,
        hasMore,
        isRefreshing,
        isLoadingMore,
        reachedUnlinkedScanLimit,
        errorMessage,
        flowDays,
        flowStatus,
        daySignals,
        recentHealth,
        flowErrorMessage,
      ];
}

class AiHistoryBloc extends Bloc<AiHistoryEvent, AiHistoryState> {
  final EmotionRepository repository;
  final SharedPreferences preferences;
  int _recordsRequestId = 0;
  int _flowRequestId = 0;
  int _scopeRequestId = 0;

  AiHistoryBloc({
    required this.repository,
    required this.preferences,
    bool emotionOnly = false,
  }) : super(AiHistoryState(
          typeFilter: emotionOnly
              ? AiHistoryTypeFilter.emotion
              : AiHistoryTypeFilter.all,
        )) {
    on<AiHistoryContextChanged>(_onContextChanged);
    on<AiHistoryScopeChanged>(_onScopeChanged);
    on<AiHistorySegmentChanged>(_onSegmentChanged);
    on<AiHistoryTypeChanged>(_onTypeChanged);
    on<AiHistoryDateRangeChanged>(_onDateRangeChanged);
    on<AiHistoryAttentionChanged>(_onAttentionChanged);
    on<AiHistoryFiltersApplied>(_onFiltersApplied);
    on<AiHistoryRefreshRequested>(_onRefresh);
    on<AiHistoryNextPageRequested>(_onNextPage);
    on<AiHistoryFlowPeriodChanged>(_onFlowPeriodChanged);
  }

  String _preferenceKey(String userId) =>
      'ai_history_last_pet_scope_v1:$userId';

  Future<void> _onContextChanged(
    AiHistoryContextChanged event,
    Emitter<AiHistoryState> emit,
  ) async {
    if (event.userId.isEmpty) return;
    final contextChanged = event.userId != state.userId ||
        !_samePets(event.pets, state.pets) ||
        event.petsFailed != state.petsFailed;
    if (!contextChanged) return;

    AiHistoryPetScope scope = state.scope;
    if (event.userId != state.userId ||
        scope.kind != AiHistoryPetScopeKind.registered ||
        !event.pets.any((pet) => pet.id == scope.petId)) {
      final saved = preferences.getString(_preferenceKey(event.userId));
      if (saved != null && event.pets.any((pet) => pet.id == saved)) {
        scope = AiHistoryPetScope.registered(saved);
      } else {
        scope = const AiHistoryPetScope.all();
      }
    }

    emit(
      state.copyWith(
        userId: event.userId,
        pets: event.pets,
        petsFailed: event.petsFailed,
        scope: scope,
      ),
    );
    await _loadRecords(emit, keepExisting: false);
    if (state.segment == AiHistorySegment.flow) {
      await _loadFlow(emit);
    }
  }

  Future<void> _onScopeChanged(
    AiHistoryScopeChanged event,
    Emitter<AiHistoryState> emit,
  ) async {
    if (event.scope == state.scope) return;
    if (event.scope.kind == AiHistoryPetScopeKind.unlinked &&
        state.petsFailed) {
      return;
    }
    if (event.scope.kind == AiHistoryPetScopeKind.registered &&
        !state.pets.any((pet) => pet.id == event.scope.petId)) {
      return;
    }
    final requestId = ++_scopeRequestId;
    final userId = state.userId;
    emit(state.copyWith(scope: event.scope));
    unawaited(_persistScope(event.scope, requestId, userId));
    await _loadRecords(emit, keepExisting: false);
    if (requestId != _scopeRequestId) return;
    if (state.segment == AiHistorySegment.flow) {
      await _loadFlow(emit);
    }
  }

  Future<void> _persistScope(
    AiHistoryPetScope scope,
    int requestId,
    String userId,
  ) async {
    if (scope.kind == AiHistoryPetScopeKind.registered) {
      await preferences.setString(
        _preferenceKey(userId),
        scope.petId!,
      );
    } else {
      await preferences.remove(_preferenceKey(userId));
    }
    if (requestId != _scopeRequestId) {
      if (state.userId != userId) return;
      final latest = state.scope;
      if (latest.kind == AiHistoryPetScopeKind.registered &&
          latest.petId != null) {
        await preferences.setString(
          _preferenceKey(userId),
          latest.petId!,
        );
      } else {
        await preferences.remove(_preferenceKey(userId));
      }
    }
  }

  Future<void> _onSegmentChanged(
    AiHistorySegmentChanged event,
    Emitter<AiHistoryState> emit,
  ) async {
    if (event.segment == state.segment) return;
    emit(state.copyWith(segment: event.segment));
    if (event.segment == AiHistorySegment.flow) await _loadFlow(emit);
  }

  Future<void> _onTypeChanged(
    AiHistoryTypeChanged event,
    Emitter<AiHistoryState> emit,
  ) async {
    emit(
      state.copyWith(
        typeFilter: event.filter,
        healthAttentionOnly: event.filter == AiHistoryTypeFilter.emotion
            ? false
            : state.healthAttentionOnly,
      ),
    );
    await _loadRecords(emit, keepExisting: false);
  }

  Future<void> _onDateRangeChanged(
    AiHistoryDateRangeChanged event,
    Emitter<AiHistoryState> emit,
  ) async {
    emit(state.copyWith(dateRange: event.range));
    await _loadRecords(emit, keepExisting: false);
  }

  Future<void> _onAttentionChanged(
    AiHistoryAttentionChanged event,
    Emitter<AiHistoryState> emit,
  ) async {
    emit(
      state.copyWith(
        healthAttentionOnly: event.enabled,
        typeFilter: event.enabled
            ? AiHistoryTypeFilter.health
            : AiHistoryTypeFilter.all,
      ),
    );
    await _loadRecords(emit, keepExisting: false);
  }

  Future<void> _onFiltersApplied(
    AiHistoryFiltersApplied event,
    Emitter<AiHistoryState> emit,
  ) async {
    final attention = event.type == AiHistoryTypeFilter.emotion
        ? false
        : event.healthAttentionOnly;
    emit(state.copyWith(
      typeFilter: attention ? AiHistoryTypeFilter.health : event.type,
      dateRange: event.dateRange,
      healthAttentionOnly: attention,
    ));
    await _loadRecords(emit, keepExisting: false);
  }

  Future<void> _onRefresh(
    AiHistoryRefreshRequested event,
    Emitter<AiHistoryState> emit,
  ) async {
    if (state.isRefreshing) return;
    await _loadRecords(emit, keepExisting: true, refreshing: true);
    if (state.segment == AiHistorySegment.flow) await _loadFlow(emit);
  }

  Future<void> _onNextPage(
    AiHistoryNextPageRequested event,
    Emitter<AiHistoryState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore) return;
    final requestId = ++_recordsRequestId;
    emit(state.copyWith(isLoadingMore: true, errorMessage: null));
    final result = await _fetchVisibleBatch(
      cursor: state.cursor,
    );
    if (requestId != _recordsRequestId) return;
    if (result.errorMessage != null) {
      emit(
        state.copyWith(
          isLoadingMore: false,
          errorMessage: result.errorMessage,
        ),
      );
      return;
    }
    final batch = result.batch!;
    emit(
      state.copyWith(
        status: AiHistoryLoadStatus.success,
        records: _deduplicate([...state.records, ...batch.records]),
        cursor: batch.nextCursor,
        hasMore: batch.hasMore,
        isLoadingMore: false,
        reachedUnlinkedScanLimit: batch.reachedUnlinkedScanLimit,
        errorMessage: null,
      ),
    );
  }

  Future<void> _onFlowPeriodChanged(
    AiHistoryFlowPeriodChanged event,
    Emitter<AiHistoryState> emit,
  ) async {
    if (event.days == state.flowDays) return;
    emit(state.copyWith(flowDays: event.days));
    await _loadFlow(emit);
  }

  Future<void> _loadRecords(
    Emitter<AiHistoryState> emit, {
    required bool keepExisting,
    bool refreshing = false,
  }) async {
    if (state.userId.isEmpty) return;
    final requestId = ++_recordsRequestId;
    emit(
      state.copyWith(
        status: keepExisting && state.records.isNotEmpty
            ? state.status
            : AiHistoryLoadStatus.loading,
        records: keepExisting ? state.records : const [],
        cursor: const AiHistoryCursor.initial(),
        hasMore: false,
        isRefreshing: refreshing,
        isLoadingMore: false,
        reachedUnlinkedScanLimit: false,
        errorMessage: null,
      ),
    );

    final result = await _fetchVisibleBatch(
      cursor: const AiHistoryCursor.initial(),
    );
    if (requestId != _recordsRequestId) return;
    if (result.errorMessage != null) {
      emit(
        state.copyWith(
          status: keepExisting && state.records.isNotEmpty
              ? AiHistoryLoadStatus.success
              : AiHistoryLoadStatus.failure,
          isRefreshing: false,
          errorMessage: result.errorMessage,
        ),
      );
      return;
    }
    final batch = result.batch!;
    emit(
      state.copyWith(
        status: AiHistoryLoadStatus.success,
        records: batch.records,
        cursor: batch.nextCursor,
        hasMore: batch.hasMore,
        isRefreshing: false,
        reachedUnlinkedScanLimit: batch.reachedUnlinkedScanLimit,
        errorMessage: null,
      ),
    );
  }

  Future<void> _loadFlow(Emitter<AiHistoryState> emit) async {
    final requestId = ++_flowRequestId;
    final userId = state.userId;
    final scope = state.scope;
    final activePetIds =
        state.pets.map((pet) => pet.id).toList(growable: false);
    final flowDays = state.flowDays;
    if (scope.kind == AiHistoryPetScopeKind.all) {
      emit(
        state.copyWith(
          flowStatus: AiHistoryLoadStatus.success,
          daySignals: const [],
          recentHealth: const [],
          flowErrorMessage: null,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        flowStatus: AiHistoryLoadStatus.loading,
        flowErrorMessage: null,
      ),
    );
    if (scope.kind == AiHistoryPetScopeKind.unlinked) {
      final result = await repository.getAiHistoryPage(
        userId: userId,
        petScope: scope,
        activePetIds: activePetIds,
        typeFilter: AiHistoryTypeFilter.health,
        pageSize: 100,
      );
      if (requestId != _flowRequestId || state.scope != scope) return;
      result.fold(
        (failure) => emit(
          state.copyWith(
            flowStatus: AiHistoryLoadStatus.failure,
            flowErrorMessage: failure.message,
          ),
        ),
        (batch) => emit(
          state.copyWith(
            flowStatus: AiHistoryLoadStatus.success,
            daySignals: const [],
            recentHealth: _latestHealthByArea(batch.records),
            flowErrorMessage: null,
          ),
        ),
      );
      return;
    }
    if (scope.petId == null) return;

    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: flowDays - 1));
    final emotionResult = await repository.getAnalysisHistory(
      userId: userId,
      petId: scope.petId,
      startDate: start,
      limit: 250,
    );
    if (requestId != _flowRequestId || state.scope != scope) return;
    final healthResult = await repository.getAiHistoryPage(
      userId: userId,
      petScope: scope,
      activePetIds: activePetIds,
      typeFilter: AiHistoryTypeFilter.health,
      pageSize: 100,
    );
    if (requestId != _flowRequestId || state.scope != scope) return;

    String? failure;
    List<EmotionAnalysis> analyses = const [];
    emotionResult.fold(
      (value) => failure = value.message,
      (value) => analyses = value,
    );
    List<AiHistoryRecord> health = const [];
    healthResult.fold(
      (value) => failure ??= value.message,
      (value) => health = _latestHealthByArea(value.records),
    );
    if (failure != null) {
      emit(
        state.copyWith(
          flowStatus: AiHistoryLoadStatus.failure,
          flowErrorMessage: failure,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        flowStatus: AiHistoryLoadStatus.success,
        daySignals: AiHistoryPresentation.buildDailySignals(analyses),
        recentHealth: health,
        flowErrorMessage: null,
      ),
    );
  }

  Future<_AiHistoryFetchResult> _fetchVisibleBatch({
    required AiHistoryCursor cursor,
    int maxAutomaticScans = 3,
  }) async {
    final userId = state.userId;
    final scope = state.scope;
    final activePetIds =
        state.pets.map((pet) => pet.id).toList(growable: false);
    final typeFilter = state.typeFilter;
    final dateRange = state.dateRange;
    final healthAttentionOnly = state.healthAttentionOnly;
    var nextCursor = cursor;
    var reachedUnlinkedScanLimit = false;

    for (var scan = 0; scan < maxAutomaticScans; scan++) {
      AiHistoryPageBatch? batch;
      String? errorMessage;
      final result = await repository.getAiHistoryPage(
        userId: userId,
        petScope: scope,
        activePetIds: activePetIds,
        typeFilter: typeFilter,
        dateRange: dateRange,
        healthAttentionOnly: healthAttentionOnly,
        cursor: nextCursor,
      );
      result.fold(
        (failure) => errorMessage = failure.message,
        (value) => batch = value,
      );
      if (errorMessage != null) {
        return _AiHistoryFetchResult(errorMessage: errorMessage);
      }

      final current = batch!;
      reachedUnlinkedScanLimit =
          reachedUnlinkedScanLimit || current.reachedUnlinkedScanLimit;
      if (current.records.isNotEmpty || !current.hasMore) {
        return _AiHistoryFetchResult(
          batch: AiHistoryPageBatch(
            records: current.records,
            nextCursor: current.nextCursor,
            hasMore: current.hasMore,
            reachedUnlinkedScanLimit: reachedUnlinkedScanLimit,
          ),
        );
      }
      nextCursor = current.nextCursor;
    }

    return _AiHistoryFetchResult(
      batch: AiHistoryPageBatch(
        records: const [],
        nextCursor: nextCursor,
        hasMore: true,
        reachedUnlinkedScanLimit: reachedUnlinkedScanLimit,
      ),
    );
  }

  static List<AiHistoryRecord> _deduplicate(List<AiHistoryRecord> records) {
    final seen = <String>{};
    return records
        .where((record) => seen.add('${record.kind.name}:${record.id}'))
        .toList(growable: false);
  }

  static List<AiHistoryRecord> _latestHealthByArea(
    List<AiHistoryRecord> records,
  ) {
    final seen = <String>{};
    final latest = <AiHistoryRecord>[];
    for (final record in records) {
      final health = record.health;
      if (health == null) continue;
      final areaKey = health.hasKnownArea
          ? health.area.name
          : 'unknown:${health.sourceAreaName}';
      if (seen.add(areaKey)) latest.add(record);
    }
    return latest;
  }

  static bool _samePets(List<Pet> left, List<Pet> right) {
    if (left.length != right.length) return false;
    final rightById = {for (final pet in right) pet.id: pet};
    return left.every((pet) => rightById[pet.id] == pet);
  }
}

class _AiHistoryFetchResult {
  final AiHistoryPageBatch? batch;
  final String? errorMessage;

  const _AiHistoryFetchResult({this.batch, this.errorMessage});
}
