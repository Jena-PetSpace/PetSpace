import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/entities/mbti_content.dart';
import '../../domain/entities/pet_mbti_result.dart';
import '../theme/mbti_theme.dart';

/// 궁합 섹션: 잘 맞는 강아지 1 + 고양이 1.
///
/// 각 매칭은 상대 유형코드 + 별명 + 이유를 보여준다. 별명은 종 기준을 명확히:
/// 강아지 궁합 → dog 별명, 고양이 궁합 → cat 별명.
class MbtiCompatibilityCard extends StatelessWidget {
  final MbtiCompatibility compatibility;
  final MbtiContent content;
  final Color groupColor;

  const MbtiCompatibilityCard({
    super.key,
    required this.compatibility,
    required this.content,
    required this.groupColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _matchRow(
          emoji: '🐶',
          speciesLabel: '잘 맞는 강아지',
          match: compatibility.dog,
          nickname: _nicknameFor(compatibility.dog.type, MbtiSpecies.dog),
        ),
        SizedBox(height: 12.h),
        _matchRow(
          emoji: '🐱',
          speciesLabel: '잘 맞는 고양이',
          match: compatibility.cat,
          nickname: _nicknameFor(compatibility.cat.type, MbtiSpecies.cat),
        ),
      ],
    );
  }

  /// 상대 유형코드의 종별 별명. 강아지 궁합이면 dog, 고양이면 cat 별명.
  String _nicknameFor(String typeCode, MbtiSpecies species) {
    final info = content.typeInfo(typeCode);
    if (info == null) return '';
    return info.detailFor(species).nickname;
  }

  Widget _matchRow({
    required String emoji,
    required String speciesLabel,
    required MbtiMatch match,
    required String nickname,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: groupColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: groupColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: TextStyle(fontSize: 22.sp)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  speciesLabel,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: MbtiTheme.textSecondary,
                  ),
                ),
                SizedBox(height: 3.h),
                // 유형코드 · 별명 (예: ISFJ · 포근한 보디가드)
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: match.type,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: groupColor,
                        ),
                      ),
                      if (nickname.isNotEmpty)
                        TextSpan(
                          text: ' · $nickname',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: MbtiTheme.textPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  match.reason,
                  style: TextStyle(
                    fontSize: 12.sp,
                    height: 1.4,
                    color: MbtiTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
