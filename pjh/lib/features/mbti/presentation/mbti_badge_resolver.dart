import 'dart:ui';

import '../domain/entities/mbti_content.dart';
import '../domain/entities/pet_mbti_result.dart';
import 'theme/mbti_theme.dart';

/// 홈 카드·MY 뱃지에서 쓰는 간결 표시 정보(별명 + 그룹색).
class MbtiBadgeInfo {
  final String typeCode;
  final String nickname;
  final String group;
  final Color groupColor;

  const MbtiBadgeInfo({
    required this.typeCode,
    required this.nickname,
    required this.group,
    required this.groupColor,
  });
}

/// 캐시된 type_code + 콘텐츠 + 종 → 뱃지 표시 정보.
///
/// 캐시(type_code)가 있을 때만 호출한다. 유형을 못 찾으면 null(표시 생략).
MbtiBadgeInfo? resolveMbtiBadge({
  required String? typeCode,
  required MbtiSpecies species,
  required MbtiContent content,
}) {
  if (typeCode == null || typeCode.isEmpty) return null;
  final info = content.typeInfo(typeCode);
  if (info == null) return null;
  return MbtiBadgeInfo(
    typeCode: typeCode,
    nickname: info.detailFor(species).nickname,
    group: info.group,
    groupColor: MbtiTheme.colorFromKey(content.colorForGroup(info.group)),
  );
}
