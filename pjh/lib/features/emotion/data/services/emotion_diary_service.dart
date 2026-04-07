import '../../domain/entities/emotion_analysis.dart';
import 'gemini_ai_service.dart';

class EmotionDiaryService {
  final GeminiAIService _geminiService;

  EmotionDiaryService({GeminiAIService? geminiService})
      : _geminiService = geminiService ?? GeminiAIService();

  Future<String?> generateDiary(List<EmotionAnalysis> recentHistory) async {
    if (recentHistory.isEmpty) return null;

    final summaryLines = <String>[];
    for (final a in recentHistory.take(7)) {
      final e = a.emotions;
      final date = '${a.analyzedAt.month}/${a.analyzedAt.day}';
      final dominant = e.dominantEmotion;
      summaryLines.add(
        '$date: $dominant(기쁨${(e.happiness*100).toInt()}/편안${(e.calm*100).toInt()}/흥분${(e.excitement*100).toInt()}/호기심${(e.curiosity*100).toInt()}/불안${(e.anxiety*100).toInt()}/공포${(e.fear*100).toInt()}/슬픔${(e.sadness*100).toInt()}/불편${(e.discomfort*100).toInt()}) 스트레스:${e.stressLevel}',
      );
    }

    final prompt = '''
아래는 반려동물의 최근 감정 분석 기록입니다.
각 줄: 날짜: 주감정(기쁨/편안/흥분/호기심/불안/공포/슬픔/불편 %) 스트레스:수치

${summaryLines.join('\n')}

위 데이터를 바탕으로 반려동물 보호자가 읽을 "AI 감정 일기"를 작성해주세요.
- 3~5문장의 따뜻하고 자연스러운 한국어
- 감정 변화 트렌드를 반영
- 보호자에게 도움이 될 조언 1개 포함
- 날짜나 숫자를 직접 언급하지 말고 자연스럽게 요약
''';

    return await _geminiService.generateText(prompt);
  }
}
