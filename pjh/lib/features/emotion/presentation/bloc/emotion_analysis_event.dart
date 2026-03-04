part of 'emotion_analysis_bloc.dart';

abstract class EmotionAnalysisEvent extends Equatable {
  const EmotionAnalysisEvent();

  @override
  List<Object?> get props => [];
}

class AnalyzeEmotionRequested extends EmotionAnalysisEvent {
  final List<String> imagePaths;
  final String? petId;
  final String? petType;
  final String? breed;

  const AnalyzeEmotionRequested({
    required this.imagePaths,
    this.petId,
    this.petType,
    this.breed,
  });

  @override
  List<Object?> get props => [imagePaths, petId, petType, breed];
}

class SaveAnalysisRequested extends EmotionAnalysisEvent {
  final String? memo;
  final List<String> tags;

  const SaveAnalysisRequested({this.memo, this.tags = const []});

  @override
  List<Object?> get props => [memo, tags];
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