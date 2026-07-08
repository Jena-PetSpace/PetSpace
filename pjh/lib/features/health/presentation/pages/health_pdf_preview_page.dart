import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:printing/printing.dart';

import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../domain/entities/health_record.dart';
import '../widgets/health_pdf_generator.dart';

/// 건강 요약서 PDF 미리보기. 저장·공유는 PdfPreview 내장 액션 사용.
class HealthPdfPreviewPage extends StatelessWidget {
  final Pet pet;
  final String ownerName;
  final List<HealthRecord> records;
  final EmotionAnalysis? latestAnalysis;

  const HealthPdfPreviewPage({
    super.key,
    required this.pet,
    required this.ownerName,
    required this.records,
    this.latestAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '건강 리포트 미리보기',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
      ),
      body: PdfPreview(
        build: (_) => HealthPdfGenerator.buildPdfBytes(
          pet: pet,
          ownerName: ownerName,
          records: records,
          latestAnalysis: latestAnalysis,
        ),
        pdfFileName: '${pet.name}_건강요약서.pdf',
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        onError: (context, error) => Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Text(
              'PDF 생성에 실패했습니다: $error',
              style: TextStyle(fontSize: 13.sp),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
