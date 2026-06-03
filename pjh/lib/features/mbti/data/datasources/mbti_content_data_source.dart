import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/entities/mbti_content.dart';
import '../../domain/entities/pet_mbti_result.dart';

/// 앱 번들 JSON 콘텐츠 로더.
///
/// 문항/유형/궁합은 외부 호출 없이 `assets/data/pet_mbti_content_v{N}.json`
/// 에서 로드한다. 채점·복기는 항상 **저장된 content_version 에 해당하는 문항
/// 세트** 로 해석해야 하므로, 로더는 버전을 명시적으로 다룬다.
abstract class MbtiContentDataSource {
  /// 지정 버전 콘텐츠를 로드(버전당 1회 파싱 후 캐시). 기본은 현재 버전.
  Future<MbtiContent> loadContent({int version = MbtiContentDataSource.currentVersion});

  /// 현재 앱이 사용하는 최신 콘텐츠 버전.
  static const int currentVersion = 1;
}

class MbtiContentDataSourceImpl implements MbtiContentDataSource {
  /// 버전별 캐시 (불필요한 재파싱 방지).
  final Map<int, MbtiContent> _cache = {};

  String _assetPath(int version) =>
      'assets/data/pet_mbti_content_v$version.json';

  @override
  Future<MbtiContent> loadContent(
      {int version = MbtiContentDataSource.currentVersion}) async {
    final cached = _cache[version];
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_assetPath(version));
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final content = _parseContent(json);

    // 로드한 콘텐츠의 version 이 요청 버전과 일치하는지 명시적으로 검증.
    if (content.version != version) {
      throw StateError(
        'MBTI 콘텐츠 버전 불일치: 요청 v$version, 파일 v${content.version} '
        '($_assetPath)',
      );
    }

    _cache[version] = content;
    return content;
  }

  // ── 파싱 ────────────────────────────────────────────────

  MbtiContent _parseContent(Map<String, dynamic> json) {
    final meta = (json['meta'] as Map?)?.cast<String, dynamic>() ?? const {};

    return MbtiContent(
      version: (json['version'] as num?)?.toInt() ?? 0,
      disclaimer: meta['disclaimer'] as String? ?? '',
      questionsPerAxis: (meta['questions_per_axis'] as num?)?.toInt() ?? 5,
      axes: _parseAxes(json['axes']),
      groups: _parseGroups(json['groups']),
      questions: _parseQuestions(json['questions']),
      types: _parseTypes(json['types']),
      compatibility: _parseCompatibility(json['compatibility']),
    );
  }

  Map<String, MbtiAxis> _parseAxes(dynamic raw) {
    final out = <String, MbtiAxis>{};
    if (raw is! Map) return out;
    raw.forEach((key, value) {
      final m = (value as Map).cast<String, dynamic>();
      final pos = (m['pos'] as Map).cast<String, dynamic>();
      final neg = (m['neg'] as Map).cast<String, dynamic>();
      out[key as String] = MbtiAxis(
        key: key,
        name: m['name'] as String? ?? '',
        posCode: pos['code'] as String,
        posLabel: pos['label'] as String? ?? '',
        negCode: neg['code'] as String,
        negLabel: neg['label'] as String? ?? '',
      );
    });
    return out;
  }

  Map<String, MbtiGroup> _parseGroups(dynamic raw) {
    final out = <String, MbtiGroup>{};
    if (raw is! Map) return out;
    raw.forEach((key, value) {
      final m = (value as Map).cast<String, dynamic>();
      out[key as String] = MbtiGroup(
        name: key,
        axesKey: m['axesKey'] as String? ?? '',
        color: m['color'] as String? ?? '',
      );
    });
    return out;
  }

  Map<MbtiSpecies, List<MbtiQuestion>> _parseQuestions(dynamic raw) {
    final out = <MbtiSpecies, List<MbtiQuestion>>{};
    if (raw is! Map) return out;
    raw.forEach((speciesKey, list) {
      final species = MbtiSpeciesX.fromKey(speciesKey as String);
      out[species] = (list as List)
          .map((q) => _parseQuestion((q as Map).cast<String, dynamic>()))
          .toList();
    });
    return out;
  }

  MbtiQuestion _parseQuestion(Map<String, dynamic> m) {
    final a = (m['A'] as Map).cast<String, dynamic>();
    final b = (m['B'] as Map).cast<String, dynamic>();
    return MbtiQuestion(
      id: m['id'] as String,
      axis: m['axis'] as String,
      text: m['text'] as String? ?? '',
      optionA: MbtiOption(
          label: a['label'] as String? ?? '', pole: a['pole'] as String),
      optionB: MbtiOption(
          label: b['label'] as String? ?? '', pole: b['pole'] as String),
    );
  }

  Map<String, MbtiTypeInfo> _parseTypes(dynamic raw) {
    final out = <String, MbtiTypeInfo>{};
    if (raw is! Map) return out;
    raw.forEach((code, value) {
      final m = (value as Map).cast<String, dynamic>();
      final details = <MbtiSpecies, MbtiTypeDetail>{};
      for (final species in MbtiSpecies.values) {
        final d = m[species.key];
        if (d is Map) {
          details[species] = _parseTypeDetail(d.cast<String, dynamic>());
        }
      }
      out[code as String] = MbtiTypeInfo(
        code: code,
        group: m['group'] as String? ?? '',
        details: details,
      );
    });
    return out;
  }

  MbtiTypeDetail _parseTypeDetail(Map<String, dynamic> m) {
    return MbtiTypeDetail(
      nickname: m['nickname'] as String? ?? '',
      summary: m['summary'] as String? ?? '',
      desc: m['desc'] as String? ?? '',
      strength: m['strength'] as String? ?? '',
      caution: m['caution'] as String? ?? '',
      activity: m['activity'] as String? ?? '',
    );
  }

  Map<String, MbtiCompatibility> _parseCompatibility(dynamic raw) {
    final out = <String, MbtiCompatibility>{};
    if (raw is! Map) return out;
    raw.forEach((code, value) {
      final m = (value as Map).cast<String, dynamic>();
      out[code as String] = MbtiCompatibility(
        dog: _parseMatch((m['dog'] as Map).cast<String, dynamic>()),
        cat: _parseMatch((m['cat'] as Map).cast<String, dynamic>()),
      );
    });
    return out;
  }

  MbtiMatch _parseMatch(Map<String, dynamic> m) {
    return MbtiMatch(
      type: m['type'] as String,
      reason: m['reason'] as String? ?? '',
    );
  }
}
