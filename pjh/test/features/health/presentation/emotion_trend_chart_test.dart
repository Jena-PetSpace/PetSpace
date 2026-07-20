import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/emotion/domain/entities/emotion_analysis.dart';
import 'package:meong_nyang_diary/features/health/presentation/controllers/health_emotion_loader.dart';
import 'package:meong_nyang_diary/features/health/presentation/widgets/emotion_trend_mini_chart.dart';

EmotionScores _scores({
  double happiness = 0,
  double calm = 0,
  double excitement = 0,
  double curiosity = 0,
  double anxiety = 0,
  double fear = 0,
  double sadness = 0,
  double discomfort = 0,
}) =>
    EmotionScores(
      happiness: happiness,
      calm: calm,
      excitement: excitement,
      curiosity: curiosity,
      anxiety: anxiety,
      fear: fear,
      sadness: sadness,
      discomfort: discomfort,
    );

EmotionAnalysis _analysis(DateTime when, EmotionScores s) => EmotionAnalysis(
      id: when.toIso8601String(),
      userId: 'u',
      petId: 'p',
      imageUrl: 'img-${when.day}',
      localImagePath: '',
      emotions: s,
      confidence: 1,
      analyzedAt: when,
      tags: const [],
    );

class _QueueEmotionLoader implements HealthEmotionLoader {
  final List<HealthEmotionHistoryResult> results;
  int calls = 0;

  _QueueEmotionLoader(this.results);

  @override
  Future<HealthEmotionHistoryResult> loadHistory({
    required String userId,
    required String petId,
    int limit = 30,
  }) async {
    final index = calls < results.length ? calls : results.length - 1;
    calls++;
    return results[index];
  }

  @override
  Future<EmotionAnalysis?> loadLatest({
    required String userId,
    required String petId,
  }) async {
    return null;
  }
}

Widget _wrapChart(HealthEmotionLoader loader) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(
      home: Scaffold(
        body: EmotionTrendMiniChart(
          userId: 'user-1',
          petId: 'pet-1',
          loader: loader,
        ),
      ),
    ),
  );
}

void main() {
  // ── 긍정도 계산 ────────────────────────────────────────────────────────────
  group('EmotionScores.positiveRatio', () {
    test('긍정 감정만 → 1.0', () {
      expect(_scores(happiness: 0.5, calm: 0.5).positiveRatio, 1.0);
    });

    test('부정 감정만 → 0.0', () {
      expect(_scores(anxiety: 0.5, sadness: 0.5).positiveRatio, 0.0);
    });

    test('반반 → 0.5', () {
      expect(_scores(happiness: 0.5, anxiety: 0.5).positiveRatio, 0.5);
    });

    test('긍정 3 : 부정 1 → 0.75', () {
      expect(
        _scores(happiness: 0.3, anxiety: 0.1).positiveRatio,
        closeTo(0.75, 1e-9),
      );
    });

    test('total 0 → 중립 0.5 (NaN 방지)', () {
      expect(_scores().positiveRatio, 0.5);
    });
  });

  // ── 분석 리스트 → 차트 포인트 변환 ───────────────────────────────────────
  group('buildEmotionTrendPoints', () {
    test('빈 리스트 → 빈 포인트', () {
      expect(buildEmotionTrendPoints(const []), isEmpty);
    });

    test('단일 → 포인트 1개', () {
      final pts = buildEmotionTrendPoints([
        _analysis(DateTime(2026, 6, 10), _scores(happiness: 1)),
      ]);
      expect(pts.length, 1);
      expect(pts.first.positiveRatio, 1.0);
      expect(pts.first.dominantEmotion, 'happiness');
    });

    test('다건 → analyzedAt 오름차순 정렬', () {
      final pts = buildEmotionTrendPoints([
        _analysis(DateTime(2026, 6, 12), _scores(happiness: 1)),
        _analysis(DateTime(2026, 6, 10), _scores(anxiety: 1)),
        _analysis(DateTime(2026, 6, 11), _scores(calm: 1)),
      ]);
      expect(pts.map((p) => p.analyzedAt.day), [10, 11, 12]);
    });

    test('maxPoints 초과 → 최근 N건만(가장 오래된 것 절삭)', () {
      final analyses = [
        for (var d = 1; d <= 15; d++)
          _analysis(DateTime(2026, 6, d), _scores(happiness: 1)),
      ];
      final pts = buildEmotionTrendPoints(analyses, maxPoints: 10);
      expect(pts.length, 10);
      // 최근 10건 = 6/6 ~ 6/15
      expect(pts.first.analyzedAt.day, 6);
      expect(pts.last.analyzedAt.day, 15);
    });

    test('포인트 y값은 각 분석의 긍정도', () {
      final pts = buildEmotionTrendPoints([
        _analysis(DateTime(2026, 6, 10), _scores(happiness: 0.3, anxiety: 0.1)),
      ]);
      expect(pts.first.positiveRatio, closeTo(0.75, 1e-9));
    });
  });

  testWidgets('failure and successful empty states stay distinct with retry',
      (tester) async {
    final loader = _QueueEmotionLoader([
      const HealthEmotionHistoryResult.failure(),
      const HealthEmotionHistoryResult.success([]),
    ]);
    await tester.pumpWidget(_wrapChart(loader));
    await tester.pumpAndSettle();

    expect(find.text('건강 변화를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('아직 분석 기록이 없어요'), findsNothing);

    await tester.tap(find.byKey(const Key('health_emotion_retry')));
    await tester.pumpAndSettle();

    expect(find.text('건강 변화를 불러오지 못했어요'), findsNothing);
    expect(find.text('아직 분석 기록이 없어요'), findsOneWidget);
    expect(loader.calls, 2);
  });
}
