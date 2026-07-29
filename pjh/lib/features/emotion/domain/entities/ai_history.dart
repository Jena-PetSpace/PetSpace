import 'package:equatable/equatable.dart';

import 'emotion_analysis.dart';
import 'health_analysis.dart';

enum AiHistoryKind { emotion, health }

enum AiHistoryTypeFilter { all, emotion, health }

enum AiHistoryDateRange { all, last7Days, last30Days, last90Days }

enum AiHistoryPetScopeKind { all, registered, unlinked }

class AiHistoryPetScope extends Equatable {
  final AiHistoryPetScopeKind kind;
  final String? petId;

  const AiHistoryPetScope._(this.kind, this.petId);

  const AiHistoryPetScope.all() : this._(AiHistoryPetScopeKind.all, null);

  const AiHistoryPetScope.unlinked()
      : this._(AiHistoryPetScopeKind.unlinked, null);

  const AiHistoryPetScope.registered(String petId)
      : this._(AiHistoryPetScopeKind.registered, petId);

  @override
  List<Object?> get props => [kind, petId];
}

class AiHistoryCursor extends Equatable {
  final DateTime? emotionBefore;
  final DateTime? healthBefore;
  final bool emotionExhausted;
  final bool healthExhausted;

  const AiHistoryCursor({
    this.emotionBefore,
    this.healthBefore,
    this.emotionExhausted = false,
    this.healthExhausted = false,
  });

  const AiHistoryCursor.initial() : this();

  @override
  List<Object?> get props => [
        emotionBefore,
        healthBefore,
        emotionExhausted,
        healthExhausted,
      ];
}

class AiHistoryRecord extends Equatable {
  final AiHistoryKind kind;
  final String id;
  final String? petId;
  final String? petName;
  final String? imageUrl;
  final DateTime analyzedAt;
  final EmotionAnalysis? emotion;
  final HealthAnalysis? health;

  const AiHistoryRecord({
    required this.kind,
    required this.id,
    required this.petId,
    required this.petName,
    required this.imageUrl,
    required this.analyzedAt,
    this.emotion,
    this.health,
  });

  factory AiHistoryRecord.emotion(EmotionAnalysis analysis, {String? petName}) {
    return AiHistoryRecord(
      kind: AiHistoryKind.emotion,
      id: analysis.id,
      petId: analysis.petId,
      petName: petName ?? analysis.petName,
      imageUrl: analysis.imageUrl.isEmpty ? null : analysis.imageUrl,
      analyzedAt: analysis.analyzedAt,
      emotion: analysis,
    );
  }

  factory AiHistoryRecord.health(HealthAnalysis analysis) {
    return AiHistoryRecord(
      kind: AiHistoryKind.health,
      id: analysis.id,
      petId: analysis.petId,
      petName: analysis.petName,
      imageUrl: analysis.imageUrls.isEmpty ? null : analysis.imageUrls.first,
      analyzedAt: analysis.analyzedAt,
      health: analysis,
    );
  }

  @override
  List<Object?> get props => [
        kind,
        id,
        petId,
        petName,
        imageUrl,
        analyzedAt,
        emotion,
        health,
      ];
}

class AiHistoryPageBatch extends Equatable {
  final List<AiHistoryRecord> records;
  final AiHistoryCursor nextCursor;
  final bool hasMore;
  final bool reachedUnlinkedScanLimit;

  const AiHistoryPageBatch({
    required this.records,
    required this.nextCursor,
    required this.hasMore,
    this.reachedUnlinkedScanLimit = false,
  });

  @override
  List<Object?> get props => [
        records,
        nextCursor,
        hasMore,
        reachedUnlinkedScanLimit,
      ];
}

class AiHistoryDaySignal extends Equatable {
  final DateTime day;
  final String dominantEmotion;
  final bool hasMixedSignals;
  final int analysisCount;

  const AiHistoryDaySignal({
    required this.day,
    required this.dominantEmotion,
    required this.hasMixedSignals,
    required this.analysisCount,
  });

  @override
  List<Object?> get props => [
        day,
        dominantEmotion,
        hasMixedSignals,
        analysisCount,
      ];
}
