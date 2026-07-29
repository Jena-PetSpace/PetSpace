import 'package:equatable/equatable.dart';

enum HealthArea {
  eyes,
  nose,
  skin,
  body,
  posture,
  overall;

  String get displayName => const {
        HealthArea.eyes: '눈·귀',
        HealthArea.nose: '코·입',
        HealthArea.skin: '피부·털',
        HealthArea.body: '체형(BCS)',
        HealthArea.posture: '자세·체형 대칭',
        HealthArea.overall: '종합(전체)',
      }[this]!;

  static HealthArea fromDisplayName(String name) =>
      HealthArea.values.firstWhere(
        (e) => e.displayName == name,
        orElse: () => HealthArea.overall,
      );
}

enum HealthObservationState { stable, watch, needsAttention, unknown }

class HealthFinding extends Equatable {
  final String item;
  final String result; // '정상' | '이상' | '확인불가'
  final String detail;
  final String severity; // 'normal' | 'caution' | 'warning'

  const HealthFinding({
    required this.item,
    required this.result,
    required this.detail,
    required this.severity,
  });

  Map<String, dynamic> toJson() => {
        'item': item,
        'result': result,
        'detail': detail,
        'severity': severity,
      };

  @override
  List<Object?> get props => [item, result, severity];
}

class HealthAnalysis extends Equatable {
  final String id;
  final String userId;
  final String? petId;
  final String? petName;
  final HealthArea area;

  /// 저장된 원본 부위명. 과거/미상 값을 `overall`로 오분류하지 않기 위해 보존한다.
  final String? sourceAreaName;
  final List<String> imageUrls;
  final int overallScore;
  final String status; // '양호' | '주의' | '위험' | '확인불가'
  final List<HealthFinding> findings;
  final bool riskAlert;
  final String? riskReason;
  final List<String> recommendations;
  final double confidence;
  final String summary;
  final String? additionalContext;
  final DateTime analyzedAt;

  const HealthAnalysis({
    required this.id,
    required this.userId,
    this.petId,
    this.petName,
    required this.area,
    this.sourceAreaName,
    required this.imageUrls,
    required this.overallScore,
    required this.status,
    required this.findings,
    required this.riskAlert,
    this.riskReason,
    required this.recommendations,
    required this.confidence,
    required this.summary,
    this.additionalContext,
    required this.analyzedAt,
  });

  bool get hasKnownArea =>
      sourceAreaName == null ||
      HealthArea.values.any((area) => area.displayName == sourceAreaName);

  HealthObservationState get observationState {
    if (riskAlert) return HealthObservationState.needsAttention;
    return switch (status.trim().toLowerCase()) {
      '양호' || 'normal' || 'good' || 'stable' => HealthObservationState.stable,
      '주의' || 'caution' || 'watch' => HealthObservationState.watch,
      '위험' ||
      'warning' ||
      'danger' ||
      'critical' =>
        HealthObservationState.needsAttention,
      _ => HealthObservationState.unknown,
    };
  }

  bool get requiresReview => observationState != HealthObservationState.stable;

  @override
  List<Object?> get props => [
        id,
        userId,
        area,
        sourceAreaName,
        overallScore,
        riskAlert,
        analyzedAt,
      ];
}
