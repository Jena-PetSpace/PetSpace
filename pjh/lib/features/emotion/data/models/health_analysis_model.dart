import 'dart:developer';
import '../../domain/entities/health_analysis.dart';

class HealthFindingModel extends HealthFinding {
  const HealthFindingModel({
    required super.item,
    required super.result,
    required super.detail,
    required super.severity,
  });

  factory HealthFindingModel.fromJson(Map<String, dynamic> j) => HealthFindingModel(
        item: j['item'] as String? ?? '',
        result: j['result'] as String? ?? '확인불가',
        detail: j['detail'] as String? ?? '',
        severity: j['severity'] as String? ?? 'normal',
      );
}

class HealthAnalysisModel extends HealthAnalysis {
  const HealthAnalysisModel({
    required super.id,
    required super.userId,
    super.petId,
    super.petName,
    required super.area,
    required super.imageUrls,
    required super.overallScore,
    required super.status,
    required super.findings,
    required super.riskAlert,
    super.riskReason,
    required super.recommendations,
    required super.confidence,
    required super.summary,
    super.additionalContext,
    required super.analyzedAt,
  });

  factory HealthAnalysisModel.fromGeminiJson({
    required String userId,
    String? petId,
    String? petName,
    required HealthArea area,
    required List<String> imageUrls,
    required Map<String, dynamic> json,
    String? additionalContext,
  }) {
    log('건강분석 파싱: area=${area.displayName} score=${json['overall_score']}',
        name: 'HealthModel');

    final findings = (json['findings'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => HealthFindingModel.fromJson(e))
        .toList();

    final recs = List<String>.from(json['recommendations'] as List? ?? []);

    return HealthAnalysisModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      petId: petId,
      petName: petName,
      area: area,
      imageUrls: imageUrls,
      overallScore: (json['overall_score'] as num?)?.toInt().clamp(0, 100) ?? 50,
      status: json['status'] as String? ?? '확인불가',
      findings: findings,
      riskAlert: json['risk_alert'] as bool? ?? false,
      riskReason: json['risk_reason'] as String?,
      recommendations: recs,
      confidence:
          (json['confidence'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.5,
      summary: json['summary'] as String? ?? '',
      additionalContext: additionalContext,
      analyzedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabaseJson() => {
        'user_id': userId,
        'pet_id': petId,
        'pet_name': petName,
        'area': area.displayName,
        'image_urls': imageUrls,
        'overall_score': overallScore,
        'status': status,
        'findings': findings.map((f) => f.toJson()).toList(),
        'risk_alert': riskAlert,
        'risk_reason': riskReason,
        'recommendations': recommendations,
        'confidence': confidence,
        'summary': summary,
        'additional_context': additionalContext,
      };

  factory HealthAnalysisModel.fromSupabaseRow(Map<String, dynamic> row) {
    final areaName = row['area'] as String? ?? '';
    final area = HealthArea.values.firstWhere(
      (a) => a.displayName == areaName,
      orElse: () => HealthArea.overall,
    );

    final findings = (row['findings'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((e) => HealthFindingModel.fromJson(e))
        .toList();

    final recs = List<String>.from(row['recommendations'] as List? ?? []);
    final imageUrls = List<String>.from(row['image_urls'] as List? ?? []);

    return HealthAnalysisModel(
      id: row['id']?.toString() ?? '',
      userId: row['user_id'] as String? ?? '',
      petId: row['pet_id'] as String?,
      petName: row['pet_name'] as String?,
      area: area,
      imageUrls: imageUrls,
      overallScore: (row['overall_score'] as num?)?.toInt().clamp(0, 100) ?? 50,
      status: row['status'] as String? ?? '확인불가',
      findings: findings,
      riskAlert: row['risk_alert'] as bool? ?? false,
      riskReason: row['risk_reason'] as String?,
      recommendations: recs,
      confidence: (row['confidence'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 0.5,
      summary: row['summary'] as String? ?? '',
      additionalContext: row['additional_context'] as String?,
      analyzedAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
    );
  }
}
