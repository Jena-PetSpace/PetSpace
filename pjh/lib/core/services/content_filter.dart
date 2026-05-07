/// 게시글 / 댓글 / 닉네임 등 사용자 작성 텍스트의
/// 비속어 / 혐오 / 성적 표현을 1차 차단하는 클라이언트측 필터.
///
/// - 완벽한 모더레이션이 아닌 1차 방어선. 서버측 검토와 신고 시스템과 병행.
/// - 한국어 / 영어 단어 위주.
/// - 자/모 분리(ㅈ.같) 또는 특수문자 삽입(시*발) 일부도 정규식으로 잡되,
///   정상 단어 오탐을 막기 위해 보수적으로 작성.
class ContentFilter {
  ContentFilter._();

  /// 차단 대상 키워드 (소문자, 띄어쓰기 제거 비교).
  static const List<String> _denyList = [
    // 한국어 욕설
    '시발', '씨발', '시팔', '쒸발', 'ㅅㅂ', 'ㅆㅂ',
    '병신', '븅신', 'ㅂㅅ',
    '개새끼', '개세끼', '개색기', '개색끼',
    '좆', '좇', '존나', '졸라',
    '지랄', '지랖',
    '미친놈', '미친년',
    '닥쳐', '닥치',
    '뒤져', '뒤진다',
    '꺼져', '꺼져라',
    '엿먹어',
    // 한국어 혐오 표현 (성별/지역/장애 비하 일부)
    '한남충', '김치녀', '맘충', '꼴페미', '메갈',
    '틀딱', '급식충', '급식충새끼',
    '병신새끼', '장애새끼',
    // 성적 표현 (직설)
    '섹스', '성관계', '자위',
    'fuck', 'shit', 'bitch', 'asshole', 'dick', 'pussy',
    // 인종/국적 비하
    'nigger', 'chink', 'jap',
  ];

  /// 텍스트에 차단 키워드가 포함되어 있는지 검사.
  ///
  /// 반환값: 발견된 첫 키워드. 없으면 null.
  static String? findBannedKeyword(String text) {
    if (text.isEmpty) return null;
    final normalized = _normalize(text);
    for (final word in _denyList) {
      final n = _normalize(word);
      if (n.isEmpty) continue;
      if (normalized.contains(n)) return word;
    }
    return null;
  }

  /// 차단 키워드 포함 여부 (boolean).
  static bool hasBannedKeyword(String text) =>
      findBannedKeyword(text) != null;

  /// 비교용 정규화: 공백/특수문자/구두점 제거 + 소문자.
  static String _normalize(String s) {
    final lowered = s.toLowerCase();
    // 영어/한글/숫자만 남김 (특수문자, 구두점 모두 제거)
    return lowered.replaceAll(RegExp(r'[^a-z0-9가-힣ㄱ-ㅎㅏ-ㅣ]'), '');
  }
}
