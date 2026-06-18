/// MY 탭 "내 펫 라이프 요약" 카드의 표시 데이터(포맷팅·빈 상태 결정).
///
/// emotion/health/pet 3개 도메인의 읽기 결과를 위젯이 추출한 primitive로 받아
/// 라벨 문자열·빈 상태를 계산한다. 분석 횟수 집계·최근 1건·건강 요약 선택은
/// 위젯에서 추출(.length / dominantEmotion / .first), 포맷팅 책임만 분리.
class PetLifeSummary {
  final int analysisCount;

  /// 가장 최근 분석의 dominantEmotion(영문 키). 없으면 null.
  final String? latestDominantEmotion;

  /// 최근 건강 기록 제목(예: '체중 5.2kg'). 없으면 null.
  final String? healthTitle;

  /// 최근 건강 기록 시각. 없으면 null.
  final DateTime? healthDate;

  const PetLifeSummary({
    required this.analysisCount,
    required this.latestDominantEmotion,
    required this.healthTitle,
    required this.healthDate,
  });

  bool get hasAnalysis => analysisCount > 0;
  bool get hasHealth => healthTitle != null && healthDate != null;

  String get analysisLabel {
    if (!hasAnalysis) return '아직 분석 기록이 없어요';
    final emotion = dominantEmotionLabel(latestDominantEmotion ?? '');
    if (emotion.isEmpty) return '분석 $analysisCount회';
    return '분석 $analysisCount회 · 최근 $emotion';
  }

  /// 건강 라벨. [now]는 상대 시각 계산 기준(테스트 주입 가능).
  String healthLabelAt(DateTime now) {
    if (!hasHealth) return '';
    return '$healthTitle · ${_relativeTime(healthDate!, now)}';
  }

  static String _relativeTime(DateTime dt, DateTime now) {
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }

  /// 8감정 영문 키 → 한글 라벨. 미상은 빈 문자열.
  static String dominantEmotionLabel(String key) {
    switch (key) {
      case 'happiness':
        return '기쁨';
      case 'calm':
        return '편안';
      case 'excitement':
        return '흥분';
      case 'curiosity':
        return '호기심';
      case 'anxiety':
        return '불안';
      case 'fear':
        return '공포';
      case 'sadness':
        return '슬픔';
      case 'discomfort':
        return '불편';
      default:
        return '';
    }
  }
}
