import 'package:flutter/material.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../domain/entities/pet_mbti_result.dart';

/// MBTI 화면 공통 톤·색상 헬퍼.
///
/// 브랜드 규칙: 흰/연회색 배경 + 네이비 + 코랄. 빨강 금지.
/// 16유형 그룹 색상(분석가 purple / 외교관 coral / 관리자 navy / 탐험가 teal)은
/// 결과 화면(작업 4)에서 사용하며, 여기서 단일 소스로 관리한다.
class MbtiTheme {
  MbtiTheme._();

  // 기본 브랜드 토큰 (AppTheme 재사용)
  static const Color navy = AppTheme.primaryColor; // 0xFF1E3A5F
  static const Color coral = AppTheme.highlightColor; // 0xFFFF6F61
  static const Color bg = AppTheme.backgroundColor; // 0xFFF8F9FA 연회색
  static const Color surface = Colors.white;
  static const Color textPrimary = AppTheme.primaryTextColor;
  static const Color textSecondary = AppTheme.secondaryTextColor;

  // 16유형 그룹 색상 (JSON groups.color 키 ↔ 실제 Color)
  static const Color groupPurple = AppTheme.fearColor; // 분석가(NT) — 딥 퍼플, AppTheme.fearAppTheme.fearColor
  static const Color groupCoral = coral; // 외교관(NF)
  static const Color groupNavy = navy; // 관리자(SJ)
  static const Color groupTeal = AppTheme.calmColor; // 탐험가(SP) — 틸 그린, AppTheme.calmAppTheme.calmColor

  /// JSON groups.color 문자열 → Color.
  static Color colorFromKey(String? key) {
    switch (key) {
      case 'purple':
        return groupPurple;
      case 'coral':
        return groupCoral;
      case 'navy':
        return groupNavy;
      case 'teal':
        return groupTeal;
      default:
        return navy;
    }
  }

  /// 종 한국어 라벨.
  static String speciesLabel(MbtiSpecies species) {
    switch (species) {
      case MbtiSpecies.dog:
        return '강아지';
      case MbtiSpecies.cat:
        return '고양이';
      case MbtiSpecies.etc:
        return '우리 아이';
    }
  }
}
