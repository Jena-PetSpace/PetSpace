import 'package:flutter/material.dart';

import '../../../../shared/themes/app_theme.dart';

/// O/X 퀴즈 화면 공통 톤·색상.
///
/// 브랜드 규칙: 흰/연회색 배경 + 네이비 + 코랄. **빨강 금지** — 오답도 코랄로,
/// 정답은 틸 그린으로 구분하고 색에만 의존하지 않게 항상 아이콘+텍스트를 병기한다.
class QuizTheme {
  QuizTheme._();

  static const Color navy = AppTheme.primaryColor; // 0xFF1E3A5F
  static const Color coral = AppTheme.highlightColor; // 0xFFFF6F61
  static const Color bg = AppTheme.backgroundColor; // 0xFFF8F9FA 연회색
  static const Color surface = Colors.white;
  static const Color textPrimary = AppTheme.primaryTextColor;
  static const Color textSecondary = AppTheme.secondaryTextColor;
  static const Color divider = Color(0xFFE0E0E0);

  /// 정답 강조색(틸 그린 — 초록 계열이라 색각 이상에서도 코랄과 대비, 빨강 아님).
  static const Color correct = Color(0xFF2E7D6B);

  /// 오답 강조색(코랄 — 빨강 금지 규칙 준수).
  static const Color incorrect = coral;

  /// 종 태그 이모지(🐶/🐱/🐾).
  static String speciesEmoji(String species) {
    switch (species) {
      case 'dog':
        return '🐶';
      case 'cat':
        return '🐱';
      default:
        return '🐾'; // common
    }
  }

  /// 종 한국어 라벨.
  static String speciesLabel(String species) {
    switch (species) {
      case 'dog':
        return '강아지';
      case 'cat':
        return '고양이';
      default:
        return '공통';
    }
  }
}
