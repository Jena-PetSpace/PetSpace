/// MBTI 유형코드(4글자) → 운세 종합운 그룹 키 순수 계산.
///
/// MBTI 콘텐츠 JSON 을 로드하지 않고 코드 글자만으로 그룹을 도출한다(결합도↓).
/// 표준 MBTI 그룹핑과 일치 — 16유형 전수 대조 검증됨:
///  - 분석가(NT): _NT_   · 외교관(NF): _NF_
///  - 관리자(SJ): _S_J   · 탐험가(SP): _S_P
///
/// 캐시(pets.current_mbti_type) 가 null·빈값·형식 불일치면 null 반환 →
/// 호출부에서 'default' 종합운으로 폴백.
String? mbtiGroupOf(String? typeCode) {
  if (typeCode == null) return null;
  final code = typeCode.trim().toUpperCase();
  if (code.length != 4) return null;

  final n = code[1]; // S/N
  final t = code[2]; // T/F
  final j = code[3]; // J/P

  if (n == 'N' && t == 'T') return '분석가';
  if (n == 'N' && t == 'F') return '외교관';
  if (n == 'S' && j == 'J') return '관리자';
  if (n == 'S' && j == 'P') return '탐험가';
  return null; // 알 수 없는 형식 → default 폴백
}
