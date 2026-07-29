import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/emotion_analysis.dart';
import '../../domain/repositories/emotion_repository.dart';

enum EmotionMemoStatus { idle, saving, success, failure }

class EmotionMemoState extends Equatable {
  final EmotionMemoStatus status;
  final EmotionAnalysis analysis;
  final String? message;

  const EmotionMemoState({
    required this.analysis,
    this.status = EmotionMemoStatus.idle,
    this.message,
  });

  EmotionMemoState copyWith({
    EmotionMemoStatus? status,
    EmotionAnalysis? analysis,
    String? message,
  }) {
    return EmotionMemoState(
      status: status ?? this.status,
      analysis: analysis ?? this.analysis,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, analysis, message];
}

class EmotionMemoCubit extends Cubit<EmotionMemoState> {
  final EmotionRepository repository;

  EmotionMemoCubit({
    required this.repository,
    required EmotionAnalysis analysis,
  }) : super(EmotionMemoState(analysis: analysis));

  Future<bool> save(String memo) async {
    if (state.status == EmotionMemoStatus.saving) return false;
    emit(state.copyWith(status: EmotionMemoStatus.saving));
    final result = await repository.updateAnalysisMemo(
      analysisId: state.analysis.id,
      memo: memo,
    );
    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: EmotionMemoStatus.failure,
            message: failure.message,
          ),
        );
        return false;
      },
      (analysis) {
        emit(
          state.copyWith(
            status: EmotionMemoStatus.success,
            analysis: analysis,
            message: '메모를 저장했어요',
          ),
        );
        return true;
      },
    );
  }
}
