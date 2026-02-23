import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/emotion_analysis.dart';
import '../../domain/usecases/analyze_emotion.dart';
import '../../domain/usecases/save_emotion_analysis.dart';
import '../../domain/usecases/get_emotion_history.dart';
import '../../domain/usecases/get_emotion_statistics.dart';
import '../../domain/usecases/delete_emotion_analysis.dart';

part 'emotion_analysis_event.dart';
part 'emotion_analysis_state.dart';

class EmotionAnalysisBloc extends Bloc<EmotionAnalysisEvent, EmotionAnalysisState> {
  final AnalyzeEmotion _analyzeEmotion;
  final SaveEmotionAnalysis _saveEmotionAnalysis;
  final GetEmotionHistory _getEmotionHistory;
  final GetEmotionStatistics _getEmotionStatistics;
  final DeleteEmotionAnalysis _deleteEmotionAnalysis;

  EmotionAnalysisBloc({
    required AnalyzeEmotion analyzeEmotion,
    required SaveEmotionAnalysis saveEmotionAnalysis,
    required GetEmotionHistory getEmotionHistory,
    required GetEmotionStatistics getEmotionStatistics,
    required DeleteEmotionAnalysis deleteEmotionAnalysis,
  })  : _analyzeEmotion = analyzeEmotion,
        _saveEmotionAnalysis = saveEmotionAnalysis,
        _getEmotionHistory = getEmotionHistory,
        _getEmotionStatistics = getEmotionStatistics,
        _deleteEmotionAnalysis = deleteEmotionAnalysis,
        super(EmotionAnalysisInitial()) {
    on<AnalyzeEmotionRequested>(_onAnalyzeEmotionRequested);
    on<SaveAnalysisRequested>(_onSaveAnalysisRequested);
    on<LoadAnalysisHistory>(_onLoadAnalysisHistory);
    on<DeleteAnalysisRequested>(_onDeleteAnalysisRequested);
    on<LoadEmotionStatistics>(_onLoadEmotionStatistics);
  }

  Future<void> _onAnalyzeEmotionRequested(
    AnalyzeEmotionRequested event,
    Emitter<EmotionAnalysisState> emit,
  ) async {
    emit(EmotionAnalysisLoading());

    final result = await _analyzeEmotion(AnalyzeEmotionParams(
      imagePath: event.imagePath,
      petId: event.petId,
    ));

    result.fold(
      (failure) => emit(EmotionAnalysisError(failure.message)),
      (analysis) => emit(EmotionAnalysisSuccess(analysis)),
    );
  }

  Future<void> _onSaveAnalysisRequested(
    SaveAnalysisRequested event,
    Emitter<EmotionAnalysisState> emit,
  ) async {
    if (state is! EmotionAnalysisSuccess) return;

    final currentState = state as EmotionAnalysisSuccess;
    emit(EmotionAnalysisSaving(currentState.analysis));

    final updatedAnalysis = event.memo != null
        ? currentState.analysis.copyWith(memo: event.memo)
        : currentState.analysis;

    final result = await _saveEmotionAnalysis(SaveEmotionAnalysisParams(
      analysis: updatedAnalysis,
      memo: event.memo,
    ));

    result.fold(
      (failure) => emit(EmotionAnalysisError(failure.message)),
      (_) => emit(EmotionAnalysisSaved(updatedAnalysis)),
    );
  }

  Future<void> _onLoadAnalysisHistory(
    LoadAnalysisHistory event,
    Emitter<EmotionAnalysisState> emit,
  ) async {
    emit(EmotionAnalysisHistoryLoading());

    final result = await _getEmotionHistory(GetEmotionHistoryParams(
      userId: event.userId,
      petId: event.petId,
      startDate: event.startDate,
      endDate: event.endDate,
      limit: event.limit,
    ));

    result.fold(
      (failure) => emit(EmotionAnalysisError(failure.message)),
      (history) => emit(EmotionAnalysisHistoryLoaded(history)),
    );
  }

  Future<void> _onDeleteAnalysisRequested(
    DeleteAnalysisRequested event,
    Emitter<EmotionAnalysisState> emit,
  ) async {
    final result = await _deleteEmotionAnalysis(DeleteEmotionAnalysisParams(
      analysisId: event.analysisId,
    ));

    result.fold(
      (failure) => emit(EmotionAnalysisError(failure.message)),
      (_) => emit(const EmotionAnalysisDeleted()),
    );
  }

  Future<void> _onLoadEmotionStatistics(
    LoadEmotionStatistics event,
    Emitter<EmotionAnalysisState> emit,
  ) async {
    emit(EmotionStatisticsLoading());

    final result = await _getEmotionStatistics(GetEmotionStatisticsParams(
      userId: event.userId,
      petId: event.petId,
      startDate: event.startDate,
      endDate: event.endDate,
    ));

    result.fold(
      (failure) => emit(EmotionAnalysisError(failure.message)),
      (statistics) => emit(EmotionStatisticsLoaded(statistics)),
    );
  }
}