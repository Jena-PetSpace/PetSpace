part of 'package:meong_nyang_diary/features/emotion/presentation/pages/emotion_result_page.dart';

// ── 헬퍼 메서드 ────────────────────────────────────────────
extension _EmotionResultHelpers on _EmotionResultPageState {
  // ── 헬퍼 ──

  String _formatDateTime(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  double _getEmotionValue(String emotion) {
    switch (emotion) {
      case 'happiness':
        return widget.analysis.emotions.happiness;
      case 'sadness':
        return widget.analysis.emotions.sadness;
      case 'anxiety':
        return widget.analysis.emotions.anxiety;
      case 'sleepiness':
        return widget.analysis.emotions.sleepiness;
      case 'curiosity':
        return widget.analysis.emotions.curiosity;
      default:
        return 0.0;
    }
  }

  String _getEmotionName(String emotion) {
    switch (emotion) {
      case 'happiness':
        return '기쁨';
      case 'sadness':
        return '슬픔';
      case 'anxiety':
        return '불안';
      case 'sleepiness':
        return '졸림';
      case 'curiosity':
        return '호기심';
      default:
        return '알 수 없음';
    }
  }

  IconData _getEmotionIcon(String emotion) {
    switch (emotion) {
      case 'happiness':
        return Icons.sentiment_very_satisfied;
      case 'sadness':
        return Icons.sentiment_very_dissatisfied;
      case 'anxiety':
        return Icons.psychology_alt;
      case 'sleepiness':
        return Icons.bedtime;
      case 'curiosity':
        return Icons.explore;
      default:
        return Icons.pets;
    }
  }

  String _getShortDescription(String emotion) {
    switch (emotion) {
      case 'happiness':
        return '지금 이 순간, 아이가 행복해 보여요!';
      case 'sadness':
        return '오늘은 조금 기운이 없어 보이네요.';
      case 'anxiety':
        return '살짝 긴장하고 있는 것 같아요. 안심시켜 주세요.';
      case 'sleepiness':
        return '스르르 졸음이 오고 있어요. 편히 쉬게 해주세요.';
      case 'curiosity':
        return '무언가에 호기심이 가득한 눈빛이에요!';
      default:
        return '오늘 아이의 상태를 확인했어요';
    }
  }

  _Recommendation _getSingleRecommendation(String emotion) {
    switch (emotion) {
      case 'happiness':
        return _Recommendation(
          icon: Icons.sports_tennis,
          title: '함께 놀아주세요',
          body: '지금이 함께 산책하거나 좋아하는 놀이를 즐기기에 가장 좋은 타이밍이에요!',
        );
      case 'curiosity':
        return _Recommendation(
          icon: Icons.extension,
          title: '탐색 시간을 주세요',
          body: '새로운 장난감이나 안전한 공간을 탐색하게 해주면 자연스러운 호기심을 충족할 수 있어요.',
        );
      case 'anxiety':
        return _Recommendation(
          icon: Icons.spa,
          title: '조용히 곁에 있어주세요',
          body: '부드러운 목소리와 가벼운 스킨십으로 안심감을 전달해 주세요.',
        );
      case 'sadness':
        return _Recommendation(
          icon: Icons.favorite,
          title: '따뜻한 스킨십이 필요해요',
          body: '좋아하는 간식이나 장난감으로 기분 전환을 도와주세요.',
        );
      case 'sleepiness':
        return _Recommendation(
          icon: Icons.hotel,
          title: '편안한 잠자리를 만들어주세요',
          body: '따뜻하고 조용한 공간에서 충분히 쉬게 해주세요.',
        );
      default:
        return _Recommendation(
          icon: Icons.pets,
          title: '오늘도 잘 보살펴주세요',
          body: '반려동물의 상태를 꾸준히 관찰하고 기록하면 건강 변화를 빠르게 파악할 수 있어요.',
        );
    }
  }

}
