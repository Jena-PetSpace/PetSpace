import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/petspace_state_view.dart';
import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../domain/entities/health_record.dart';
import '../widgets/health_pdf_generator.dart';

typedef HealthPdfPreviewFactory = Widget Function({
  required Key key,
  required LayoutCallback build,
  required String fileName,
  required Widget Function(BuildContext, Object) onError,
  required void Function(BuildContext) onPrinted,
  required void Function(BuildContext, Object) onPrintError,
  required void Function(BuildContext) onShared,
  required void Function(BuildContext, Object) onShareError,
});

/// 건강 요약서 PDF 미리보기. 저장·공유 결과는 화면에서 안전하게 안내한다.
class HealthPdfPreviewPage extends StatefulWidget {
  final Pet pet;
  final String ownerName;
  final List<HealthRecord> records;
  final EmotionAnalysis? latestAnalysis;
  final LayoutCallback? buildPdf;
  final HealthPdfPreviewFactory? previewFactory;

  const HealthPdfPreviewPage({
    super.key,
    required this.pet,
    required this.ownerName,
    required this.records,
    this.latestAnalysis,
    this.buildPdf,
    this.previewFactory,
  });

  @override
  State<HealthPdfPreviewPage> createState() => _HealthPdfPreviewPageState();
}

class _HealthPdfPreviewPageState extends State<HealthPdfPreviewPage> {
  int _generation = 0;

  void _showActionFeedback(String message, {required bool isError}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: Key(
            isError
                ? 'health_pdf_action_error_snackbar'
                : 'health_pdf_action_success_snackbar',
          ),
          behavior: SnackBarBehavior.floating,
          content: Text(message),
          backgroundColor: isError ? AppTheme.errorColor : null,
        ),
      );
  }

  void _onPrinted(BuildContext _) {
    _showActionFeedback('건강 리포트의 저장·인쇄 요청을 완료했어요.', isError: false);
  }

  void _onPrintError(BuildContext _, Object __) {
    _showActionFeedback(
      '저장·인쇄를 완료하지 못했어요. 기기 설정을 확인한 뒤 다시 시도해주세요.',
      isError: true,
    );
  }

  void _onShared(BuildContext _) {
    _showActionFeedback('건강 리포트 공유를 완료했어요.', isError: false);
  }

  void _onShareError(BuildContext _, Object __) {
    _showActionFeedback(
      '공유가 완료되지 않았어요. 기기 공유 기능을 확인한 뒤 다시 시도해주세요.',
      isError: true,
    );
  }

  Widget _defaultPreview({
    required Key key,
    required LayoutCallback build,
    required String fileName,
    required Widget Function(BuildContext, Object) onError,
    required void Function(BuildContext) onPrinted,
    required void Function(BuildContext, Object) onPrintError,
    required void Function(BuildContext) onShared,
    required void Function(BuildContext, Object) onShareError,
  }) {
    return PdfPreview(
      key: key,
      build: build,
      pdfFileName: fileName,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      useActions: false,
      actions: [
        PdfPrintAction(
          icon: const Tooltip(
            message: '저장 또는 인쇄',
            child: Icon(Icons.print_outlined),
          ),
          jobName: fileName,
          onPrinted: () => onPrinted(context),
          onPrintError: (error) => onPrintError(context, error),
        ),
        _HealthPdfShareAction(
          fileName: fileName,
          onShared: () => onShared(context),
          onShareError: (error) => onShareError(context, error),
        ),
      ],
      onError: onError,
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewFactory = widget.previewFactory ?? _defaultPreview;
    final buildPdf = widget.buildPdf ??
        (_) => HealthPdfGenerator.buildPdfBytes(
              pet: widget.pet,
              ownerName: widget.ownerName,
              records: widget.records,
              latestAnalysis: widget.latestAnalysis,
            );
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
      body: Column(
        children: [
          Container(
            key: const Key('health_pdf_scope_notice'),
            width: double.infinity,
            margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppTheme.actionContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm.r),
            ),
            child: Text(
              '기록을 확인한 뒤 상단 기능으로 저장하거나 공유할 수 있어요. '
              '완료되지 않으면 기기 설정을 확인한 뒤 다시 시도해주세요. '
              '이 요약서는 의료 진단을 대신하지 않습니다.',
              style: TextStyle(
                fontSize: AppTheme.fontCaption.sp,
                height: 1.45,
                color: AppTheme.brandDeep,
              ),
            ),
          ),
          Expanded(
            child: previewFactory(
              key: ValueKey('health-pdf-${widget.pet.id}-$_generation'),
              build: buildPdf,
              fileName: 'petspace_health_report.pdf',
              onError: (context, _) => PetSpaceStateView.error(
                icon: Icons.description_outlined,
                title: '건강 리포트를 만들지 못했어요',
                message: '기록은 그대로 유지됩니다. 잠시 후 다시 시도해주세요.',
                actionLabel: '다시 생성',
                onAction: () => setState(() => _generation++),
              ),
              onPrinted: _onPrinted,
              onPrintError: _onPrintError,
              onShared: _onShared,
              onShareError: _onShareError,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthPdfShareAction extends StatelessWidget
    with PdfPreviewActionBounds {
  final String fileName;
  final VoidCallback onShared;
  final ValueChanged<Object> onShareError;

  _HealthPdfShareAction({
    required this.fileName,
    required this.onShared,
    required this.onShareError,
  });

  @override
  Widget build(BuildContext context) {
    return PdfPreviewAction(
      key: childKey,
      icon: const Tooltip(
        message: '공유',
        child: Icon(Icons.share_outlined),
      ),
      onPressed: _share,
    );
  }

  Future<void> _share(
    BuildContext context,
    LayoutCallback build,
    PdfPageFormat pageFormat,
  ) async {
    try {
      final bytes = await build(pageFormat);
      final completed = await Printing.sharePdf(
        bytes: bytes,
        bounds: bounds,
        filename: fileName,
      );
      if (completed) {
        onShared();
      } else {
        onShareError(StateError('share-not-completed'));
      }
    } catch (error) {
      onShareError(error);
    }
  }
}
