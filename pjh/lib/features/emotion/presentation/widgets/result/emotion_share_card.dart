import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../shared/themes/app_theme.dart';
import '../../../domain/entities/emotion_analysis.dart';

/// 감정 결과를 이미지 카드로 생성하여 SNS 공유
class EmotionShareHelper {
  static final GlobalKey _shareKey = GlobalKey();

  /// 공유 카드 이미지 생성 후 시트 표시
  static Future<void> shareAsCard(
    BuildContext context, {
    required EmotionAnalysis analysis,
    String? petName,
  }) async {
    // 1. 공유 카드를 오버레이로 렌더링
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -1000, // 화면 밖에 배치
        top: 0,
        child: RepaintBoundary(
          key: _shareKey,
          child: EmotionShareCard(
            analysis: analysis,
            petName: petName,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // 2. 이미지로 변환
      final boundary =
          _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      // 3. 임시 파일 저장
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/petspace_emotion_result.png');
      await file.writeAsBytes(bytes);

      // 4. 공유
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '#펫스페이스 #반려동물감정분석 #AI감정분석\n우리 아이의 오늘 감정을 분석했어요! 🐾',
        subject: '반려동물 AI 감정 분석 결과',
      );
    } finally {
      overlay.remove();
    }
  }
}

class EmotionShareCard extends StatelessWidget {
  final EmotionAnalysis analysis;
  final String? petName;

  static const _emotionEmoji = {
    'happiness': '😊',
    'sadness': '😢',
    'anxiety': '😰',
    'sleepiness': '😴',
    'curiosity': '🧐',
  };

  static const _emotionName = {
    'happiness': '행복',
    'sadness': '슬픔',
    'anxiety': '불안',
    'sleepiness': '졸림',
    'curiosity': '호기심',
  };

  static const _emotionColor = {
    'happiness': Color(0xFF5BC0EB),
    'sadness': Color(0xFF2C4482),
    'anxiety': Color(0xFFFF6F61),
    'sleepiness': Color(0xFF1E3A5F),
    'curiosity': Color(0xFF0077B6),
  };

  const EmotionShareCard({
    super.key,
    required this.analysis,
    this.petName,
  });

  @override
  Widget build(BuildContext context) {
    final dominant = analysis.emotions.dominantEmotion;
    final emoji = _emotionEmoji[dominant] ?? '🐾';
    final name = _emotionName[dominant] ?? '';
    final color = _emotionColor[dominant] ?? AppTheme.primaryColor;
    final emotions = [
      ('😊', '행복', analysis.emotions.happiness),
      ('😢', '슬픔', analysis.emotions.sadness),
      ('😰', '불안', analysis.emotions.anxiety),
      ('😴', '졸림', analysis.emotions.sleepiness),
      ('🧐', '호기심', analysis.emotions.curiosity),
    ];

    return SizedBox(
      width: 320,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryColor, color],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더: PetSpace 로고
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppTheme.highlightColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pets, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text(
                  'PetSpace',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 반려동물 이름
            Text(
              '${petName ?? '반려동물'}의 오늘 감정',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 6),

            // 주감정 크게
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 48)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${(analysis.emotions.happiness * 100).round()}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 감정 바
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: emotions.map((e) {
                  final pct = (e.$3 * 100).round();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(e.$1, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 50,
                          child: Text(e.$2,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white)),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: e.$3,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$pct%',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // 날짜 + watermark
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${analysis.analyzedAt.year}.${analysis.analyzedAt.month.toString().padLeft(2, '0')}.${analysis.analyzedAt.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  'petspace.app',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
