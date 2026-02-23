part of 'emotion_analysis_bloc.dart';

abstract class EmotionAnalysisState extends Equatable {
  const EmotionAnalysisState();

  @override
  List<Object?> get props => [];
}

class EmotionAnalysisInitial extends EmotionAnalysisState {}

class EmotionAnalysisLoading extends EmotionAnalysisState {}

class EmotionAnalysisSuccess extends EmotionAnalysisState {
  final EmotionAnalysis analysis;

  const EmotionAnalysisSuccess(this.analysis);

  @override
  List<Object?> get props => [analysis];
}

class EmotionAnalysisSaving extends EmotionAnalysisState {
  final EmotionAnalysis analysis;

  const EmotionAnalysisSaving(this.analysis);

  @override
  List<Object?> get props => [analysis];
}

class EmotionAnalysisSaved extends EmotionAnalysisState {
  final EmotionAnalysis analysis;

  const EmotionAnalysisSaved(this.analysis);

  @override
  List<Object?> get props => [analysis];
}

class EmotionAnalysisHistoryLoading extends EmotionAnalysisState {}

class EmotionAnalysisHistoryLoaded extends EmotionAnalysisState {
  final List<EmotionAnalysis> history;

  const EmotionAnalysisHistoryLoaded(this.history);

  @override
  List<Object?> get props => [history];
}

class EmotionAnalysisDeleted extends EmotionAnalysisState {
  const EmotionAnalysisDeleted();
}

class EmotionStatisticsLoading extends EmotionAnalysisState {}

class EmotionStatisticsLoaded extends EmotionAnalysisState {
  final Map<String, dynamic> statistics;

  const EmotionStatisticsLoaded(this.statistics);

  @override
  List<Object?> get props => [statistics];
}

class EmotionAnalysisError extends EmotionAnalysisState {
  final String message;

  const EmotionAnalysisError(this.message);

  @override
  List<Object?> get props => [message];
}