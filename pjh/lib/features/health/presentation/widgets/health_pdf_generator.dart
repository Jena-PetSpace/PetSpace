import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../domain/entities/health_record.dart';
import 'health_pdf_data.dart';

/// 건강 요약서 PDF 바이트를 온디바이스에서 생성한다.
/// 서버 미경유(건강 개인정보 보호). 한글은 Pretendard 폰트 임베드.
/// 저장·공유는 미리보기 화면(PdfPreview)의 내장 액션이 담당.
class HealthPdfGenerator {
  /// 최근 AI 감정 분석 1건 요약(선택) — 펫페이스 차별점. 읽기 전용 데이터.
  static Future<Uint8List> buildPdfBytes({
    required Pet pet,
    required String ownerName,
    required List<HealthRecord> records,
    EmotionAnalysis? latestAnalysis,
    DateTime? now,
  }) async {
    final data = buildHealthPdfData(records);
    final emotionSummary = buildHealthPdfEmotionSummary(latestAnalysis);
    final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Pretendard-Bold.ttf'));
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final created = now ?? DateTime.now();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _header(pet, ownerName, created),
          pw.SizedBox(height: 16),
          if (data.weights.isNotEmpty) ...[
            _weightSection(data),
            pw.SizedBox(height: 14),
          ],
          if (data.vaccinations.isNotEmpty) ...[
            _vaccinationSection(data),
            pw.SizedBox(height: 14),
          ],
          if (data.medications.isNotEmpty) ...[
            _medicationSection(data),
            pw.SizedBox(height: 14),
          ],
          if (data.exams.isNotEmpty) ...[
            _examSection(data),
            pw.SizedBox(height: 14),
          ],
          if (emotionSummary != null) ...[
            _analysisSection(emotionSummary),
            pw.SizedBox(height: 14),
          ],
          if (!data.hasAny)
            pw.Text('아직 건강 기록이 없습니다.', style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 18),
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            '이 문서는 보호자가 입력한 건강 기록을 정리한 참고 자료이며 의료 진단이나 수의사의 판단을 대신하지 않습니다.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  static String _fmtKg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  static pw.Widget _header(Pet pet, String owner, DateTime created) {
    final typeKo = pet.type == PetType.dog ? '강아지' : '고양이';
    final genderKo =
        pet.gender == null ? '-' : (pet.gender == PetGender.male ? '수컷' : '암컷');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('건강 요약서',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('${pet.name} · $typeKo'
            '${pet.breed != null && pet.breed!.isNotEmpty ? ' · ${pet.breed}' : ''}'
            ' · ${pet.displayAge} · $genderKo'),
        pw.Text('보호자: $owner'),
        pw.Text('생성일: ${_fmtDate(created)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _sectionTitle(String t) => pw.Text(t,
      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold));

  static pw.Widget _weightSection(HealthPdfData d) {
    final latest = d.weights.last;
    final deltaStr = d.weightDelta == null
        ? ''
        : (d.weightDelta!.isFlat
            ? ' (변화 없음)'
            : ' (${d.weightDelta!.isIncrease ? '+' : '-'}'
                '${_fmtKg(d.weightDelta!.deltaKg.abs())}kg, '
                '${d.weightDelta!.percent.abs().toStringAsFixed(1)}%)');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('체중 추이'),
        pw.SizedBox(height: 4),
        pw.Text('현재 체중: ${_fmtKg(latest.weightKg)}kg$deltaStr'),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['날짜', '체중(kg)', 'BCS'],
          data: d.weights.reversed
              .map((p) => [
                    _fmtDate(p.recordDate),
                    _fmtKg(p.weightKg),
                    p.bcs?.toString() ?? '-',
                  ])
              .toList(),
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    );
  }

  static pw.Widget _vaccinationSection(HealthPdfData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('예방접종 이력'),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['백신', '접종일', '다음 예정일'],
          data: d.vaccinations
              .map((v) => [v['vaccine_type']!, v['date']!, v['next']!])
              .toList(),
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    );
  }

  static pw.Widget _medicationSection(HealthPdfData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('투약 현황'),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['약명', '용량', '주기', '기간'],
          data: d.medications
              .map((m) => [
                    m['med_name']!,
                    m['dosage']!.isEmpty ? '-' : m['dosage']!,
                    m['frequency']!.isEmpty ? '-' : m['frequency']!,
                    m['period']!,
                  ])
              .toList(),
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    );
  }

  static pw.Widget _examSection(HealthPdfData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('검진 · 수술 이력'),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['구분', '날짜', '병원', '내용'],
          data: d.exams
              .map((e) => [
                    e['kind']!,
                    e['date']!,
                    e['hospital']!.isEmpty ? '-' : e['hospital']!,
                    e['detail']!,
                  ])
              .toList(),
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    );
  }

  static pw.Widget _analysisSection(HealthPdfEmotionSummary summary) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('최근 AI 감정 분석'),
        pw.SizedBox(height: 4),
        pw.Text('분석일: ${_fmtDate(summary.analyzedAt)}'),
        pw.Text('대표 감정: ${summary.dominantEmotion}'),
      ],
    );
  }
}
