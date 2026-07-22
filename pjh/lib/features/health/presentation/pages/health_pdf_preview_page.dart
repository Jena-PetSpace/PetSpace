import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:printing/printing.dart';

import '../../../../shared/widgets/petspace_state_view.dart';
import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../domain/entities/health_record.dart';
import '../widgets/health_pdf_generator.dart';

/// 건강 요약서 PDF 미리보기. 저장·공유는 PdfPreview 내장 액션 사용.
class HealthPdfPreviewPage extends StatefulWidget {
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
  State<HealthPdfPreviewPage> createState() => _HealthPdfPreviewPageState();
}

class _HealthPdfPreviewPageState extends State<HealthPdfPreviewPage> {
  int _generation = 0;

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
        key: ValueKey('health-pdf-${widget.pet.id}-$_generation'),
        build: (_) => HealthPdfGenerator.buildPdfBytes(
          pet: widget.pet,
          ownerName: widget.ownerName,
          records: widget.records,
          latestAnalysis: widget.latestAnalysis,
        ),
        pdfFileName: '${widget.pet.name}_건강요약서.pdf',
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        onError: (context, _) => PetSpaceStateView.error(
          icon: Icons.description_outlined,
          title: '건강 리포트를 만들지 못했어요',
          message: '잠시 후 다시 시도해주세요.',
          actionLabel: '다시 생성',
          onAction: () => setState(() => _generation++),
        ),
      ),
    );
  }
}
