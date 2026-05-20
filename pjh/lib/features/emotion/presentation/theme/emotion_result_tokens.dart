import 'package:flutter/material.dart';

/// 감정 분석 결과 페이지 전용 디자인 토큰.
///
/// 감정별 컬러는 정의하지 않는다 — `AppTheme.getEmotionColor`를 단일 출처로 사용한다.
/// 이 파일은 페이지 레이아웃·키 컬러(베이지/코랄/네이비/앰버/그레이) 토큰만 담당한다.
class EmotionResultTokens {
  EmotionResultTokens._();

  // ============ 배경 ============
  static const Color background = Color(0xFFFFF8E8);      // 베이지
  static const Color cardSurface = Colors.white;
  static const Color dividerLight = Color(0xFFF2EAD3);

  // ============ 코랄 (즉시 행동) ============
  static const Color coral = Color(0xFFD85A30);
  static const Color coralDark = Color(0xFF993C1D);
  static const Color coralLight = Color(0xFFFDF1ED);
  static const Color coralMid = Color(0xFFFAECE7);
  static const Color coralBorder = Color(0xFFFAD6C6);

  // ============ 네이비 (정보·안내) ============
  static const Color navy = Color(0xFF0C447C);
  static const Color navyLight = Color(0xFFE6F1FB);

  // ============ 앰버 (경계·중간 강조) ============
  static const Color amber = Color(0xFFBA7517);
  static const Color amberDark = Color(0xFF854F0B);
  static const Color amberLight = Color(0xFFFDF5E3);
  static const Color amberMid = Color(0xFFFAE3B1);
  static const Color amberSoft = Color(0xFFFAEEDA);

  // ============ 그레이 (보조 정보) ============
  static const Color grayInactive = Color(0xFFDCD7D0);  // 0% 감정 도트
  static const Color grayText = Color(0xFF888780);
  static const Color grayDark = Color(0xFF5F5E5A);
  static const Color grayBar = Color(0xFFF4F2EC);       // 막대 그래프 배경

  // ============ 텍스트 ============
  static const Color textPrimary = Color(0xFF2C2C2A);
  static const Color textSecondary = Color(0xFF5F5E5A);
  static const Color textTertiary = Color(0xFF888780);

  // ============ 라운드/패딩 ============
  static const double radiusCard = 14.0;
  static const double radiusInner = 10.0;
  static const double radiusChip = 6.0;
  static const double radiusPill = 12.0;
  static const EdgeInsets paddingCard = EdgeInsets.all(14);
  static const EdgeInsets paddingSection =
      EdgeInsets.symmetric(horizontal: 14, vertical: 12);

  // ============ 카드 사이 간격 ============
  static const double cardGap = 12.0;
  static const double pageHorizontalPadding = 14.0;
}
