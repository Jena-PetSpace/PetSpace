import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meong_nyang_diary/features/emotion/data/models/emotion_analysis_model.dart';
import 'package:meong_nyang_diary/features/emotion/data/models/health_analysis_model.dart';
import 'package:meong_nyang_diary/features/emotion/domain/entities/ai_history.dart';
import 'package:meong_nyang_diary/features/emotion/domain/entities/emotion_analysis.dart';
import 'package:meong_nyang_diary/features/emotion/domain/entities/health_analysis.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/models/ai_history_presentation.dart';
import 'package:meong_nyang_diary/features/emotion/presentation/widgets/history/ai_history_record_card.dart';

void main() {
  EmotionAnalysis analysis({
    required String id,
    required DateTime at,
    double happiness = 0,
    double calm = 0,
  }) {
    return EmotionAnalysis(
      id: id,
      userId: 'user',
      petId: 'pet',
      imageUrl: '',
      localImagePath: '',
      emotions: EmotionScores(
        happiness: happiness,
        calm: calm,
        excitement: 0,
        curiosity: 0,
        anxiety: 0,
        fear: 0,
        sadness: 0,
        discomfort: 0,
      ),
      confidence: 0,
      analyzedAt: at,
      tags: const [],
    );
  }

  test('같은 로컬 날짜의 여러 감정 기록을 하루 신호 하나로 합친다', () {
    final values = [
      analysis(
        id: 'a',
        at: DateTime(2026, 7, 29, 8),
        happiness: 0.8,
        calm: 0.2,
      ),
      analysis(
        id: 'b',
        at: DateTime(2026, 7, 29, 20),
        happiness: 0.6,
        calm: 0.4,
      ),
      analysis(
        id: 'c',
        at: DateTime(2026, 7, 28, 20),
        happiness: 0.1,
        calm: 0.9,
      ),
    ];

    final result = AiHistoryPresentation.buildDailySignals(values);

    expect(result, hasLength(2));
    expect(result.first.day, DateTime(2026, 7, 29));
    expect(result.first.analysisCount, 2);
    expect(result.first.dominantEmotion, 'happiness');
    expect(result.last.dominantEmotion, 'calm');
  });

  test('상위 두 신호 차이가 0.05 미만이면 여러 신호 함께로 표시한다', () {
    final result = AiHistoryPresentation.buildDailySignals([
      analysis(
        id: 'a',
        at: DateTime(2026, 7, 29),
        happiness: 0.51,
        calm: 0.49,
      ),
    ]);

    expect(result.single.hasMixedSignals, isTrue);
  });

  test('미상 건강 부위와 위험 상태를 종합·양호로 약화하지 않는다', () {
    final health = HealthAnalysisModel(
      id: '1',
      userId: 'user',
      area: HealthArea.overall,
      sourceAreaName: '발바닥',
      imageUrls: const [],
      overallScore: 90,
      status: '양호',
      findings: const [],
      riskAlert: true,
      recommendations: const [],
      confidence: 0,
      summary: '',
      analyzedAt: DateTime(2026, 7, 29),
    );

    expect(AiHistoryPresentation.healthAreaLabel(health), '기타 부위');
    expect(
      AiHistoryPresentation.healthState(health),
      HealthObservationState.needsAttention,
    );
    expect(
      AiHistoryPresentation.healthStateLabel(health),
      '확인 필요',
    );
  });

  test('선택 모드용 표시 이름을 모델 copyWith가 보존한다', () {
    final model = EmotionAnalysisModel.fromJson(const {
      'id': 'analysis-1',
      'user_id': 'user-1',
      'pet_id': 'pet-1',
      'image_url': 'https://example.com/image.jpg',
      'emotion_analysis': {'calm': 1.0},
      'created_at': '2026-07-29T00:00:00Z',
    }).copyWith(petName: '봄이');

    expect(model.petName, '봄이');
    expect(EmotionAnalysisModel.fromEntity(model).petName, '봄이');
  });

  testWidgets('기록 카드 시맨틱스가 버튼 역할과 탭 액션을 함께 제공한다', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final record = AiHistoryRecord.emotion(
      analysis(
        id: 'semantics-record',
        at: DateTime(2026, 7, 29, 10, 30),
        happiness: 1,
      ),
    );

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(360, 800),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: AiHistoryRecordCard(
              record: record,
              petLabel: '봄이',
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.byType(AiHistoryRecordCard));
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    semanticsHandle.dispose();
  });
}
