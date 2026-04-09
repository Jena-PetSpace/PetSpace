part of '../../pages/emotion_result_page.dart';

// ── 헬퍼 메서드 ────────────────────────────────────────────
extension _EmotionResultHelpers on _EmotionResultPageState {
  // ── 헬퍼 ──

  String _formatDateTime(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  double _getEmotionValue(String emotion) {
    final e = widget.analysis.emotions;
    switch (emotion) {
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

  // AppTheme 중앙화 — 직접 호출
  String _getEmotionName(String emotion) => AppTheme.getEmotionLabel(emotion);

  IconData _getEmotionIcon(String emotion) {
    switch (emotion) {
      case 'happiness':  return Icons.sentiment_very_satisfied;
      case 'calm':       return Icons.self_improvement;
      case 'excitement': return Icons.celebration;
      case 'curiosity':  return Icons.explore;
      case 'anxiety':    return Icons.psychology_alt;
      case 'fear':       return Icons.warning_amber_outlined;
      case 'sadness':    return Icons.sentiment_very_dissatisfied;
      case 'discomfort': return Icons.sick_outlined;
      default:           return Icons.pets;
    }
  }

  String _getShortDescription(String emotion) {
    switch (emotion) {
      case 'happiness':  return '지금 이 순간, 아이가 행복해 보여요!';
      case 'calm':       return '편안하게 이완된 상태예요. 좋은 환경이에요.';
      case 'excitement': return '에너지가 넘치는 흥분 상태예요!';
      case 'curiosity':  return '무언가에 호기심이 가득한 눈빛이에요!';
      case 'anxiety':    return '살짝 긴장하고 있어요. 안심시켜 주세요.';
      case 'fear':       return '무언가를 무서워하고 있어요. 안전한 환경을 만들어주세요.';
      case 'sadness':    return '오늘은 조금 기운이 없어 보이네요.';
      case 'discomfort': return '불편한 것이 있어 보여요. 몸 상태를 확인해주세요.';
      default:           return '오늘 아이의 상태를 확인했어요.';
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
      case 'calm':
        return _Recommendation(
          icon: Icons.weekend,
          title: '편안한 환경을 유지해주세요',
          body: '지금 환경이 아이에게 잘 맞아요. 조용하고 안정적인 분위기를 유지해주세요.',
        );
      case 'excitement':
        return _Recommendation(
          icon: Icons.directions_run,
          title: '에너지를 발산시켜주세요',
          body: '산책이나 활동적인 놀이로 넘치는 에너지를 건강하게 해소시켜주세요.',
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
      case 'fear':
        return _Recommendation(
          icon: Icons.shield_outlined,
          title: '안전한 공간을 만들어주세요',
          body: '원인 자극을 제거하고 켄넬이나 담요 같은 안전한 은신처를 제공해주세요.',
        );
      case 'sadness':
        return _Recommendation(
          icon: Icons.favorite,
          title: '따뜻한 스킨십이 필요해요',
          body: '좋아하는 간식이나 장난감으로 기분 전환을 도와주세요.',
        );
      case 'discomfort':
        return _Recommendation(
          icon: Icons.medical_services_outlined,
          title: '몸 상태를 확인해주세요',
          body: '피부, 귀, 발바닥 등 신체 부위를 점검하고 이상이 지속되면 수의사 방문을 권장해요.',
        );
      default:
        return _Recommendation(
          icon: Icons.pets,
          title: '오늘도 잘 보살펴주세요',
          body: '반려동물의 상태를 꾸준히 관찰하고 기록하면 건강 변화를 빠르게 파악할 수 있어요.',
        );
    }
  }

  // ── 이론 출처 ──
  Widget _buildTheoryAttribution() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
      child: Text(
        '감정 분류: Russell(1980) 감정 원형 모델 · Panksepp(1998) 정동 신경과학 · Ekman(1992) 기본 감정 이론 기반',
        style: TextStyle(
          fontSize: 9.sp,
          color: Colors.grey[400],
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
