import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../mbti/domain/entities/pet_mbti_result.dart'
    show MbtiSpecies, MbtiSpeciesX;
import '../../domain/entities/fortune_content.dart';

/// 앱 번들 운세 콘텐츠 로더.
///
/// 종합운·항목 문구·럭키 풀은 외부 호출 없이
/// `assets/data/pet_fortune_content_v{N}.json` 에서 로드한다(버전당 1회 파싱 후 캐시).
abstract class FortuneContentDataSource {
  Future<FortuneContent> loadContent(
      {int version = FortuneContentDataSource.currentVersion});

  /// 현재 앱이 사용하는 최신 운세 콘텐츠 버전.
  static const int currentVersion = 1;
}

class FortuneContentDataSourceImpl implements FortuneContentDataSource {
  final Map<int, FortuneContent> _cache = {};

  String _assetPath(int version) =>
      'assets/data/pet_fortune_content_v$version.json';

  @override
  Future<FortuneContent> loadContent(
      {int version = FortuneContentDataSource.currentVersion}) async {
    final cached = _cache[version];
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_assetPath(version));
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final content = _parseContent(json);

    if (content.version != version) {
      throw StateError(
        '운세 콘텐츠 버전 불일치: 요청 v$version, 파일 v${content.version} '
        '(${_assetPath(version)})',
      );
    }

    _cache[version] = content;
    return content;
  }

  // ── 파싱 ────────────────────────────────────────────────

  FortuneContent _parseContent(Map<String, dynamic> json) {
    final meta = (json['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    return FortuneContent(
      version: (json['version'] as num?)?.toInt() ?? 0,
      disclaimer: meta['disclaimer'] as String? ?? '',
      items: _parseItems(json['items']),
      overall: _parseOverall(json['overall']),
      itemPhrases: _parseItemPhrases(json['itemPhrases']),
      luckyTreat: _parseLucky(json['lucky'], 'treat'),
      luckyPlace: _parseLucky(json['lucky'], 'place'),
    );
  }

  Map<MbtiSpecies, List<FortuneItem>> _parseItems(dynamic raw) {
    final out = <MbtiSpecies, List<FortuneItem>>{};
    if (raw is! Map) return out;
    raw.forEach((speciesKey, list) {
      final species = MbtiSpeciesX.fromKey(speciesKey as String);
      out[species] = (list as List)
          .whereType<Map>()
          .map((m) => FortuneItem(
                key: m['key'] as String? ?? '',
                label: m['label'] as String? ?? '',
              ))
          .toList();
    });
    return out;
  }

  Map<MbtiSpecies, Map<String, List<String>>> _parseOverall(dynamic raw) {
    final out = <MbtiSpecies, Map<String, List<String>>>{};
    if (raw is! Map) return out;
    raw.forEach((speciesKey, byGroup) {
      final species = MbtiSpeciesX.fromKey(speciesKey as String);
      final groups = <String, List<String>>{};
      if (byGroup is Map) {
        byGroup.forEach((group, phrases) {
          groups[group as String] = _stringList(phrases);
        });
      }
      out[species] = groups;
    });
    return out;
  }

  Map<String, Map<int, List<String>>> _parseItemPhrases(dynamic raw) {
    final out = <String, Map<int, List<String>>>{};
    if (raw is! Map) return out;
    raw.forEach((itemKey, byStar) {
      final stars = <int, List<String>>{};
      if (byStar is Map) {
        byStar.forEach((star, phrases) {
          final s = int.tryParse(star as String);
          if (s != null) stars[s] = _stringList(phrases);
        });
      }
      out[itemKey as String] = stars;
    });
    return out;
  }

  Map<MbtiSpecies, List<String>> _parseLucky(dynamic luckyRaw, String category) {
    final out = <MbtiSpecies, List<String>>{};
    if (luckyRaw is! Map) return out;
    final cat = luckyRaw[category];
    if (cat is! Map) return out;
    cat.forEach((speciesKey, list) {
      out[MbtiSpeciesX.fromKey(speciesKey as String)] = _stringList(list);
    });
    return out;
  }

  List<String> _stringList(dynamic raw) =>
      (raw is List) ? raw.whereType<String>().toList() : const [];
}
