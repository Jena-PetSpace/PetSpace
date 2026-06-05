import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/pet_mbti_result.dart';

/// 검사 중간 진행 상태(임시저장 스냅샷). 재진입 시 "이어하기"에 사용.
class MbtiDraft {
  final String petId;
  final MbtiSpecies species;
  final int contentVersion;
  final List<MbtiAnswer> answers;

  /// 마지막으로 보고 있던 문항 인덱스(0-based). 이어하기 진입 위치.
  final int currentIndex;

  const MbtiDraft({
    required this.petId,
    required this.species,
    required this.contentVersion,
    required this.answers,
    required this.currentIndex,
  });

  Map<String, dynamic> toJson() => {
        'pet_id': petId,
        'species': species.key,
        'content_version': contentVersion,
        'current_index': currentIndex,
        'answers': answers
            .map((a) => {
                  'q_id': a.questionId,
                  'option_index': a.optionIndex,
                })
            .toList(),
      };

  factory MbtiDraft.fromJson(Map<String, dynamic> json) {
    return MbtiDraft(
      petId: json['pet_id'] as String,
      species: MbtiSpeciesX.fromKey(json['species'] as String?),
      contentVersion: (json['content_version'] as num?)?.toInt() ?? 0,
      currentIndex: (json['current_index'] as num?)?.toInt() ?? 0,
      answers: ((json['answers'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => MbtiAnswer(
                questionId: m['q_id'] as String? ?? '',
                optionIndex: (m['option_index'] as num?)?.toInt() ?? -1,
              ))
          .where((a) => a.questionId.isNotEmpty && a.optionIndex >= 0)
          .toList(),
    );
  }
}

/// 검사 임시저장 로컬 저장소 (shared_preferences).
///
/// - pet 단위 키(`mbti_draft_<petId>`)로 다견·다묘 진행 상태를 분리.
/// - 스냅샷에 content_version 을 포함해, 이어하기 시점에 콘텐츠 버전이 바뀌면
///   (저장된 응답의 q_id 가 안 맞으므로) 이어하기를 버리고 새로 시작.
/// - 결과 저장 완료 또는 "처음부터 다시" 시 스냅샷을 삭제(엉뚱한 이어하기 방지).
abstract class MbtiDraftLocalDataSource {
  Future<void> saveDraft(MbtiDraft draft);

  /// 해당 pet 의 저장된 스냅샷. [expectedContentVersion] 과 버전이 다르면
  /// 손상/구버전으로 보고 자동 삭제 후 null 반환(이어하기 폐기).
  Future<MbtiDraft?> loadDraft(
    String petId, {
    required int expectedContentVersion,
  });

  Future<void> clearDraft(String petId);
}

class MbtiDraftLocalDataSourceImpl implements MbtiDraftLocalDataSource {
  final SharedPreferences prefs;

  MbtiDraftLocalDataSourceImpl({required this.prefs});

  static const String _keyPrefix = 'mbti_draft_';

  String _key(String petId) => '$_keyPrefix$petId';

  @override
  Future<void> saveDraft(MbtiDraft draft) async {
    await prefs.setString(_key(draft.petId), jsonEncode(draft.toJson()));
  }

  @override
  Future<MbtiDraft?> loadDraft(
    String petId, {
    required int expectedContentVersion,
  }) async {
    final raw = prefs.getString(_key(petId));
    if (raw == null) return null;

    MbtiDraft draft;
    try {
      draft = MbtiDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 파싱 불가(손상) → 폐기.
      await clearDraft(petId);
      return null;
    }

    // 콘텐츠 버전 불일치 → 저장된 응답의 q_id 가 현재 문항과 안 맞으므로 폐기.
    if (draft.contentVersion != expectedContentVersion) {
      await clearDraft(petId);
      return null;
    }

    return draft;
  }

  @override
  Future<void> clearDraft(String petId) async {
    await prefs.remove(_key(petId));
  }
}
