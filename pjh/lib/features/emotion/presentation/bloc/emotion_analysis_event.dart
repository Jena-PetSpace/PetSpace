part of 'emotion_analysis_bloc.dart';

abstract class EmotionAnalysisEvent extends Equatable {
  const EmotionAnalysisEvent();

  @override
  List<Object?> get props => [];
}

class AnalyzeEmotionRequested extends EmotionAnalysisEvent {
  final String imagePath;
  final String? petId;

  const AnalyzeEmotionRequested({
    required this.imagePath,
    this.petId,
  });

  @override
  List<Object?> get props => [imagePath, petId];
}

class SaveAnalysisRequested extends EmotionAnalysisEvent {
  final String? memo;

  const SaveAnalysisRequested({this.memo});

  @override
  List<Object?> get props => [memo];
}

class LoadAnalysisHistory extends EmotionAnalysisEvent {
  final String userId;
  final String? petId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int limit;

  const LoadAnalysisHistory({
    required this.userId,
    this.petId,
    this.startDate,
    this.endDate,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [userId, petId, startDate, endDate, limit];
}

class DeleteAnalysisRequested extends EmotionAnalysisEvent {
  final String analysisId;

  const DeleteAnalysisRequested({required this.analysisId});

  @override
  List<Object?> get props => [analysisId];
}

class LoadEmotionStatistics extends EmotionAnalysisEvent {
  final String userId;
  final String? petId;
  final DateTime? startDate;
  final DateTime? endDate;

  const LoadEmotionStatistics({
    required this.userId,
    this.petId,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [userId, petId, startDate, endDate];
}