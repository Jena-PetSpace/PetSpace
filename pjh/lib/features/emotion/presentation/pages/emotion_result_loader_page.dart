import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/emotion_analysis.dart';
import '../../domain/repositories/emotion_repository.dart';
import 'emotion_result_page.dart';

/// analysisId로 분석 결과를 로드한 후 EmotionResultPage를 표시하는 래퍼 페이지
class EmotionResultLoaderPage extends StatefulWidget {
  final String analysisId;

  const EmotionResultLoaderPage({super.key, required this.analysisId});

  @override
  State<EmotionResultLoaderPage> createState() => _EmotionResultLoaderPageState();
}

class _EmotionResultLoaderPageState extends State<EmotionResultLoaderPage> {
  EmotionAnalysis? _analysis;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    final repository = sl<EmotionRepository>();
    final result = await repository.getAnalysisById(widget.analysisId);

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _loading = false;
      }),
      (analysis) => setState(() {
        _analysis = analysis;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            '감정분석 결과',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _analysis == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            '감정분석 결과',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48.w, color: Colors.grey[400]),
              SizedBox(height: 12.h),
              Text(
                _error ?? '분석 결과를 불러올 수 없습니다',
                style: TextStyle(fontSize: 14.sp, color: AppTheme.secondaryTextColor),
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: () {
                  setState(() { _loading = true; _error = null; });
                  _loadAnalysis();
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return EmotionResultPage(analysis: _analysis!);
  }
}
