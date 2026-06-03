import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/entities/mbti_content.dart';
import '../../domain/entities/pet_mbti_result.dart';
import '../mbti_badge_resolver.dart';
import '../theme/mbti_theme.dart';

/// 공유용 카드. 오프스크린에서 고정 크기로 렌더해 이미지로 캡처한다.
/// 구성: (사진 or 기본 발바닥) + 유형 별명 + 4축 요약 + petspace 로고 워터마크.
///
/// 결과 화면과 동일 톤·그룹색. 빨강 미사용. ScreenUtil 대신 고정 px(캡처 일관성).
class MbtiShareCard extends StatelessWidget {
  final PetMbtiResult result;
  final MbtiContent content;
  final String? petName;

  /// 사진 포함 시 표시할 펫 사진 바이트(미리 받아 전달). null 이면 기본 일러스트.
  final Uint8List? photoBytes;

  /// 사진 포함 여부(기본 OFF). false 면 photoBytes 가 있어도 기본 일러스트.
  final bool includePhoto;

  const MbtiShareCard({
    super.key,
    required this.result,
    required this.content,
    this.petName,
    this.photoBytes,
    this.includePhoto = false,
  });

  static const double width = 340;

  @override
  Widget build(BuildContext context) {
    final typeInfo = content.typeInfo(result.typeCode);
    final detail = typeInfo?.detailFor(result.species);
    final badge = resolveMbtiBadge(
      typeCode: result.typeCode,
      species: result.species,
      content: content,
    );
    final groupColor = badge?.groupColor ?? MbtiTheme.navy;
    final nickname = detail?.nickname ?? result.typeCode;
    final summary = detail?.summary ?? '';
    final name = (petName != null && petName!.trim().isNotEmpty)
        ? petName!.trim()
        : MbtiTheme.speciesLabel(result.species);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 그룹색 헤더 + 아바타
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [groupColor, groupColor.withValues(alpha: 0.82)],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  _avatar(groupColor),
                  const SizedBox(height: 14),
                  // 유형코드 칩
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${result.typeCode}  ·  ${typeInfo?.group ?? ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$name 은(는)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nickname,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      summary,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 4축 요약
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
              child: Column(
                children: [
                  for (final axisKey in const ['EI', 'SN', 'TF', 'JP'])
                    if (content.axes[axisKey] != null &&
                        result.axisScores[axisKey] != null)
                      _axisRow(
                        content.axes[axisKey]!,
                        result.axisScores[axisKey]!,
                        groupColor,
                      ),
                ],
              ),
            ),
            // 워터마크 (유입 유도)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🐾', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'petspace 에서 우리 아이 성격 알아보기',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MbtiTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(Color groupColor) {
    const size = 84.0;
    final showPhoto = includePhoto && photoBytes != null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
      ),
      child: ClipOval(
        child: showPhoto
            ? Image.memory(photoBytes!, width: size, height: size,
                fit: BoxFit.cover)
            : const Center(
                child: Text('🐾', style: TextStyle(fontSize: 40)),
              ),
      ),
    );
  }

  Widget _axisRow(MbtiAxis axis, AxisScore score, Color groupColor) {
    final dominant = score.dominantPole;
    final percent = score.dominantPercent;
    final posDominant = dominant == axis.posCode;
    final domLabel = posDominant ? axis.posLabel : axis.negLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '$dominant $domLabel',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: groupColor,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Stack(
                children: [
                  Container(
                    height: 8,
                    color: groupColor.withValues(alpha: 0.10),
                  ),
                  Align(
                    alignment: posDominant
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: (percent / 100).clamp(0.0, 1.0),
                      child: Container(height: 8, color: groupColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: groupColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
