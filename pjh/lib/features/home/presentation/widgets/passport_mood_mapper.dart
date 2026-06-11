import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../../shared/themes/app_theme.dart';
import 'pet_passport_card.dart';

/// 감정분석 결과 → 여권 카드 "오늘의 기분" 변환(순수 로직).
///
/// ⚠️ 핵심 원칙: percent 는 감정 **분포 비율**(dominant / 8감정 합 × 100)이며
/// **신뢰도(confidence) 점수가 절대 아니다.** confidence 는 여기서 읽지 않는다.
class PassportMoodMapper {
  const PassportMoodMapper._();

  /// 분포 1위 감정 + 비율을 PassportMood 로 변환. 합이 0이면 null.
  static PassportMood? fromScores(EmotionScores scores) {
    final total = scores.total;
    if (total <= 0) return null;

    final dominant = scores.dominantEmotion;
    final value = _valueOf(scores, dominant);
    final percent = ((value / total) * 100).round();

    return PassportMood(
      label: AppTheme.getEmotionLabel(dominant),
      percent: percent,
      emoji: AppTheme.getEmotionEmoji(dominant),
    );
  }

  static double _valueOf(EmotionScores s, String key) {
    switch (key) {
      case 'happiness':
        return s.happiness;
      case 'calm':
        return s.calm;
      case 'excitement':
        return s.excitement;
      case 'curiosity':
        return s.curiosity;
      case 'anxiety':
        return s.anxiety;
      case 'fear':
        return s.fear;
      case 'sadness':
        return s.sadness;
      case 'discomfort':
        return s.discomfort;
      default:
        return 0;
    }
  }
}
