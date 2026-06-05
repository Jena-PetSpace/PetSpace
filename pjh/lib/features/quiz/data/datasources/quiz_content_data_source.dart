import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/entities/quiz_content.dart';

/// 앱 번들 O/X 퀴즈 콘텐츠 로더.
///
/// 270문항·메타는 외부 호출 없이 `assets/data/pet_quiz_content_v{N}.json` 에서
/// 로드한다(버전당 1회 파싱 후 캐시). 운세 콘텐츠 로더와 동일 패턴.
abstract class QuizContentDataSource {
  Future<QuizContent> loadContent(
      {int version = QuizContentDataSource.currentVersion});

  /// 이미 로드(캐시)된 콘텐츠를 동기 반환. 아직 로드 전이면 null.
  /// (홈 카드처럼 동기 렌더가 필요한 곳에서 사용 — 없으면 loadContent 선행.)
  QuizContent? tryCached({int version = QuizContentDataSource.currentVersion});

  /// 현재 앱이 사용하는 최신 퀴즈 콘텐츠 버전.
  static const int currentVersion = 1;
}

class QuizContentDataSourceImpl implements QuizContentDataSource {
  final Map<int, QuizContent> _cache = {};

  String _assetPath(int version) =>
      'assets/data/pet_quiz_content_v$version.json';

  @override
  Future<QuizContent> loadContent(
      {int version = QuizContentDataSource.currentVersion}) async {
    final cached = _cache[version];
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_assetPath(version));
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final content = _parseContent(json);

    if (content.version != version) {
      throw StateError(
        '퀴즈 콘텐츠 버전 불일치: 요청 v$version, 파일 v${content.version} '
        '(${_assetPath(version)})',
      );
    }

    _cache[version] = content;
    return content;
  }

  @override
  QuizContent? tryCached(
          {int version = QuizContentDataSource.currentVersion}) =>
      _cache[version];

  // ── 파싱 ────────────────────────────────────────────────

  QuizContent _parseContent(Map<String, dynamic> json) {
    final meta = (json['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    return QuizContent(
      version: (json['version'] as num?)?.toInt() ?? 0,
      dailyCount: (meta['dailyCount'] as num?)?.toInt() ?? 4,
      disclaimer: meta['disclaimer'] as String? ?? '',
      categories: _parseCategories(meta['categories']),
      questions: _parseQuestions(json['questions']),
    );
  }

  List<QuizCategory> _parseCategories(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => QuizCategory(
              key: m['key'] as String? ?? '',
              label: m['label'] as String? ?? '',
            ))
        .toList();
  }

  List<QuizQuestion> _parseQuestions(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => QuizQuestion(
              id: m['id'] as String? ?? '',
              category: m['category'] as String? ?? '',
              species: m['species'] as String? ?? 'common',
              statement: m['statement'] as String? ?? '',
              answer: m['answer'] as String? ?? '',
              explain: m['explain'] as String? ?? '',
            ))
        .toList();
  }
}
