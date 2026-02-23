/// 해시태그 추출 및 처리 유틸리티
class HashtagUtils {
  /// 텍스트에서 해시태그 추출
  ///
  /// 예시:
  /// - "#강아지 #귀여워 우리집 강아지" → ["강아지", "귀여워"]
  /// - "오늘은 #고양이 날! #냥냥" → ["고양이", "냥냥"]
  static List<String> extractHashtags(String text) {
    if (text.isEmpty) return [];

    // 한글, 영문, 숫자를 포함한 해시태그 추출
    // #으로 시작하고, 이후 한글/영문/숫자/_가 1개 이상 이어지는 패턴
    final RegExp hashtagPattern = RegExp(r'#([가-힣a-zA-Z0-9_]+)');

    final matches = hashtagPattern.allMatches(text);

    final hashtags = matches
        .map((match) => match.group(1)!) // # 제외한 태그 텍스트만
        .where((tag) => tag.isNotEmpty)
        .toSet() // 중복 제거
        .toList();

    return hashtags;
  }

  /// 텍스트에서 해시태그를 클릭 가능한 형태로 변환
  ///
  /// 반환값: List<TextSpan> 형태로 일반 텍스트와 해시태그 구분
  static List<Map<String, dynamic>> parseTextWithHashtags(String text) {
    if (text.isEmpty) return [];

    final RegExp hashtagPattern = RegExp(r'#([가-힣a-zA-Z0-9_]+)');
    final List<Map<String, dynamic>> segments = [];

    int lastEnd = 0;

    for (final match in hashtagPattern.allMatches(text)) {
      // 해시태그 이전의 일반 텍스트
      if (match.start > lastEnd) {
        segments.add({
          'text': text.substring(lastEnd, match.start),
          'isHashtag': false,
        });
      }

      // 해시태그
      segments.add({
        'text': match.group(0)!, // # 포함
        'hashtag': match.group(1)!, // # 제외
        'isHashtag': true,
      });

      lastEnd = match.end;
    }

    // 마지막 해시태그 이후의 일반 텍스트
    if (lastEnd < text.length) {
      segments.add({
        'text': text.substring(lastEnd),
        'isHashtag': false,
      });
    }

    return segments;
  }

  /// 해시태그 유효성 검사
  ///
  /// 규칙:
  /// - 1자 이상 50자 이하
  /// - 한글, 영문, 숫자, _ 만 허용
  /// - 공백 불가
  static bool isValidHashtag(String hashtag) {
    if (hashtag.isEmpty || hashtag.length > 50) {
      return false;
    }

    final RegExp validPattern = RegExp(r'^[가-힣a-zA-Z0-9_]+$');
    return validPattern.hasMatch(hashtag);
  }

  /// 해시태그 정규화
  ///
  /// - 앞뒤 공백 제거
  /// - # 기호 제거
  /// - 소문자 변환 (영문만)
  static String normalizeHashtag(String hashtag) {
    String normalized = hashtag.trim();

    // # 기호 제거
    if (normalized.startsWith('#')) {
      normalized = normalized.substring(1);
    }

    return normalized;
  }

  /// 해시태그 검색 쿼리 정규화
  ///
  /// 사용자 입력을 검색 가능한 형태로 변환
  static String normalizeSearchQuery(String query) {
    String normalized = query.trim();

    // # 기호 제거
    if (normalized.startsWith('#')) {
      normalized = normalized.substring(1);
    }

    // 영문은 소문자로 (한글은 그대로)
    return normalized.toLowerCase();
  }

  /// 인기 해시태그 필터링
  ///
  /// 게시물 목록에서 가장 많이 사용된 해시태그 추출
  static List<String> getTopHashtags(
    List<List<String>> allHashtags, {
    int limit = 10,
  }) {
    if (allHashtags.isEmpty) return [];

    // 해시태그별 사용 횟수 카운트
    final Map<String, int> hashtagCounts = {};

    for (final hashtags in allHashtags) {
      for (final tag in hashtags) {
        hashtagCounts[tag] = (hashtagCounts[tag] ?? 0) + 1;
      }
    }

    // 사용 횟수 기준 내림차순 정렬
    final sortedEntries = hashtagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 상위 N개 반환
    return sortedEntries
        .take(limit)
        .map((entry) => entry.key)
        .toList();
  }

  /// 해시태그 추천
  ///
  /// 입력된 텍스트를 기반으로 관련 해시태그 추천
  static List<String> suggestHashtags(
    String text,
    List<String> popularHashtags,
  ) {
    if (text.isEmpty) return [];

    final suggestions = <String>[];
    final lowerText = text.toLowerCase();

    // 인기 해시태그 중 텍스트에 포함된 단어와 매칭되는 것 추천
    for (final tag in popularHashtags) {
      final lowerTag = tag.toLowerCase();

      if (lowerText.contains(lowerTag)) {
        suggestions.add(tag);
      }
    }

    return suggestions;
  }

  /// 해시태그 포맷팅 (표시용)
  ///
  /// "강아지" → "#강아지"
  static String formatHashtag(String hashtag) {
    if (hashtag.startsWith('#')) {
      return hashtag;
    }
    return '#$hashtag';
  }

  /// 해시태그 리스트를 문자열로 변환
  ///
  /// ["강아지", "귀여워"] → "#강아지 #귀여워"
  static String hashtagsToString(List<String> hashtags) {
    return hashtags.map((tag) => formatHashtag(tag)).join(' ');
  }
}
