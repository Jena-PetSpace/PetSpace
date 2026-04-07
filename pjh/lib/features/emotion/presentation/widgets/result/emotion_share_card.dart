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


  const EmotionShareCard({
    super.key,
    required this.analysis,
    this.petName,
  });

  @override
  Widget build(BuildContext context) {
    final dominant = analysis.emotions.dominantEmotion;
    final emoji = AppTheme.getEmotionEmoji(dominant);
    final name = AppTheme.getEmotionLabel(dominant);
    final color = AppTheme.getEmotionColor(dominant);
    final e = analysis.emotions;
    double getVal(String key) {
      switch (key) {
        case 'happiness':  return e.happiness;
        case 'calm':       return e.calm;
        case 'excitement': return e.excitement;
        case 'curiosity':  return e.curiosity;
        case 'anxiety':    return e.anxiety;
        case 'fear':       return e.fear;
        case 'sadness':    return e.sadness;
        case 'discomfort': return e.discomfort;
        default:           return 0.0;
      }
    }
    final dominantPct = (getVal(dominant) * 100).round();
    final emotions = AppTheme.emotionOrder
        .map((key) => (AppTheme.getEmotionEmoji(key), AppTheme.getEmotionLabel(key), getVal(key)))
        .toList();

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
                      '$dominantPct%',
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
