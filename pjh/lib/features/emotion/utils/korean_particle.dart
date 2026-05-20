/// 한국어 주격 조사 헬퍼.
///
/// 받침 있는 이름 뒤에는 '이', 없는 이름 뒤에는 '가'를 붙인다.
/// 한글 음절(가-힣) 범위가 아닌 글자(영문·숫자·기호)는 받침 없음으로 간주.
/// name이 null/빈 문자열이면 '아이'로 fallback.
///
/// 예시:
/// - subjectParticle('토토')  → '가'   ("토토가")
/// - subjectParticle('공이')  → '가'   ("공이가" — '이'는 받침 없음)
/// - subjectParticle('보리') → '가'    ("보리가")
/// - subjectParticle('초롱') → '이'   ("초롱이")
/// - subjectParticle('Coco') → '가'   ("Coco가")
/// - subjectParticle(null)   → '가'   ("아이가" — withName 사용 권장)
String subjectParticle(String? name) {
  if (name == null || name.isEmpty) return '가';
  final lastChar = name.runes.last;
  // 한글 음절 범위 (가-힣): 0xAC00 ~ 0xD7A3
  if (lastChar < 0xAC00 || lastChar > 0xD7A3) return '가';
  final hasJongseong = (lastChar - 0xAC00) % 28 != 0;
  return hasJongseong ? '이' : '가';
}

/// 펫 이름 + 주격 조사를 합쳐 반환한다.
/// name이 null/빈 문자열이면 '아이가'.
///
/// 예시:
/// - withSubject('토토')  → '토토가'
/// - withSubject('초롱') → '초롱이'
/// - withSubject(null)   → '아이가'
String withSubject(String? name) {
  if (name == null || name.isEmpty) return '아이가';
  return '$name${subjectParticle(name)}';
}
