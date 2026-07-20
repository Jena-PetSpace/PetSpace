import '../../domain/entities/health_record.dart';
import '../../../emotion/domain/entities/emotion_analysis.dart';
import 'weight_trend.dart';

/// PDF 건강 요약서의 섹션별 데이터(순수 변환, 테스트 대상).
/// 기록 리스트를 타입별로 분류하고, 빈 섹션은 포함 여부 플래그로 표시한다.
class HealthPdfData {
  /// 체중 추이 포인트(날짜 오름차순). 표로 렌더.
  final List<WeightTrendPoint> weights;

  /// 현재 체중 증감(2건+일 때만).
  final WeightDelta? weightDelta;

  /// 예방접종: 각 {vaccine_type, date, nextDate}
  final List<Map<String, String>> vaccinations;

  /// 투약: 각 {med_name, dosage, frequency, period}
  final List<Map<String, String>> medications;

  /// 검진/수술 이력: 각 {date, hospital, detail, kind}
  final List<Map<String, String>> exams;

  const HealthPdfData({
    required this.weights,
    required this.weightDelta,
    required this.vaccinations,
    required this.medications,
    required this.exams,
  });

  bool get hasAny =>
      weights.isNotEmpty ||
      vaccinations.isNotEmpty ||
      medications.isNotEmpty ||
      exams.isNotEmpty;
}

class HealthPdfEmotionSummary {
  final DateTime analyzedAt;
  final String dominantEmotion;

  const HealthPdfEmotionSummary({
    required this.analyzedAt,
    required this.dominantEmotion,
  });
}

const _healthEmotionLabelsKo = <String, String>{
  'happiness': '행복',
  'calm': '편안',
  'excitement': '신남',
  'curiosity': '호기심',
  'anxiety': '불안',
  'fear': '두려움',
  'sadness': '슬픔',
  'discomfort': '불편',
};

String healthEmotionLabelKo(String value) =>
    _healthEmotionLabelsKo[value] ?? '분석 결과';

HealthPdfEmotionSummary? buildHealthPdfEmotionSummary(
  EmotionAnalysis? analysis,
) {
  if (analysis == null) return null;
  return HealthPdfEmotionSummary(
    analyzedAt: analysis.analyzedAt,
    dominantEmotion: healthEmotionLabelKo(
      analysis.emotions.dominantEmotion,
    ),
  );
}

String _fmtDate(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

String _s(dynamic v) => v is String ? v : (v?.toString() ?? '');

/// 건강기록 리스트 → PDF 섹션 데이터.
HealthPdfData buildHealthPdfData(List<HealthRecord> records) {
  final weights = buildWeightTrendPoints(records);
  final weightDelta = computeWeightDelta(weights);

  final vaccinations = <Map<String, String>>[];
  final medications = <Map<String, String>>[];
  final exams = <Map<String, String>>[];

  // 최신순 정렬(이력은 최근 위로)
  final sorted = [...records]
    ..sort((a, b) => b.recordDate.compareTo(a.recordDate));

  for (final r in sorted) {
    final d = r.data;
    switch (r.recordType) {
      case HealthRecordType.vaccination:
        vaccinations.add({
          'vaccine_type': _s(d['vaccine_type']).isNotEmpty
              ? _s(d['vaccine_type'])
              : r.title,
          'date': _fmtDate(r.recordDate),
          'next': r.nextDate != null ? _fmtDate(r.nextDate!) : '-',
        });
        break;
      case HealthRecordType.medication:
        final period = r.nextDate != null
            ? '${_fmtDate(r.recordDate)} ~ ${_fmtDate(r.nextDate!)}'
            : _fmtDate(r.recordDate);
        medications.add({
          'med_name':
              _s(d['med_name']).isNotEmpty ? _s(d['med_name']) : r.title,
          'dosage': _s(d['dosage']),
          'frequency': _s(d['frequency']),
          'period': period,
        });
        break;
      case HealthRecordType.checkup:
        exams.add({
          'date': _fmtDate(r.recordDate),
          'hospital': _s(d['hospital']),
          'detail': _s(d['result']).isNotEmpty ? _s(d['result']) : r.title,
          'kind': '검진',
        });
        break;
      case HealthRecordType.surgery:
        exams.add({
          'date': _fmtDate(r.recordDate),
          'hospital': _s(d['hospital']),
          'detail': _s(d['surgery_name']).isNotEmpty
              ? _s(d['surgery_name'])
              : r.title,
          'kind': '수술',
        });
        break;
      case HealthRecordType.weight:
        break; // 체중은 weights로 별도 처리
    }
  }

  return HealthPdfData(
    weights: weights,
    weightDelta: weightDelta,
    vaccinations: vaccinations,
    medications: medications,
    exams: exams,
  );
}
