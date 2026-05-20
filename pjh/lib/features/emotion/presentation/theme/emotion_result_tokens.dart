import 'package:flutter/material.dart';

import '../../domain/entities/health_analysis.dart' show HealthArea;

/// 감정·건강 분석 결과 페이지 전용 디자인 토큰.
///
/// 감정별 컬러는 정의하지 않는다 — `AppTheme.getEmotionColor`를 단일 출처로 사용한다.
/// 이 파일은 페이지 레이아웃·키 컬러(베이지/코랄/네이비/앰버/그린/그레이) 토큰 +
/// 건강 페이지용 severity / status / area 매핑 헬퍼를 담당한다.
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

  // ============ 그린 (건강 페이지 정상 신호) ============
  static const Color green = Color(0xFF639922);
  static const Color greenLight = Color(0xFFEAF3DE);
  static const Color greenMid = Color(0xFFC0DD97);
  static const Color greenDark = Color(0xFF27500A);

  // 건강 페이지에서 명확하게 부르기 위한 별칭 (코드 가독성용).
  static const Color signalAmber = amber;
  static const Color signalAmberLight = amberLight;
  static const Color signalAmberMid = amberMid;
  static const Color signalAmberDark = amberDark;

  static const Color signalRed = Color(0xFFE24B4A);
  static const Color signalRedLight = Color(0xFFFCEBEB);
  static const Color signalRedMid = Color(0xFFF6C7C6);
  static const Color signalRedDark = Color(0xFF791F1F);

  // ============ 카드 사이 간격 ============
  static const double cardGap = 12.0;
  static const double pageHorizontalPadding = 14.0;

  // ============ 건강 페이지 헬퍼 ============

  /// 종합 점수(0~100) → 강조 색상.
  ///   - 90 이상: 그린
  ///   - 70 이상: 앰버
  ///   - 그 외:   레드
  static Color scoreSignalColor(int score) {
    if (score >= 90) return green;
    if (score >= 70) return signalAmber;
    return signalRed;
  }

  /// 종합 점수(0~100) → 카드 배경 (light tone).
  static Color scoreSignalBg(int score) {
    if (score >= 90) return greenLight;
    if (score >= 70) return signalAmberLight;
    return signalRedLight;
  }

  /// 종합 점수(0~100) → 칩/배지 텍스트 색 (dark tone).
  static Color scoreSignalDark(int score) {
    if (score >= 90) return greenDark;
    if (score >= 70) return signalAmberDark;
    return signalRedDark;
  }

  /// 종합 점수(0~100) → 상태 한국어 라벨.
  static String scoreStatusLabel(int score) {
    if (score >= 90) return '양호';
    if (score >= 70) return '주의';
    return '위험';
  }

  /// HealthFinding.severity 문자열 → 강조 색상.
  ///   - 'normal'  → 그린
  ///   - 'caution' → 앰버
  ///   - 'warning' → 레드
  ///   - 그 외:     그레이 (확인불가)
  static Color severityColor(String severity) {
    switch (severity) {
      case 'normal':
        return green;
      case 'caution':
        return signalAmber;
      case 'warning':
        return signalRed;
      default:
        return grayText;
    }
  }

  /// HealthFinding.severity → 배경 (light tone).
  static Color severityBg(String severity) {
    switch (severity) {
      case 'normal':
        return greenLight;
      case 'caution':
        return signalAmberLight;
      case 'warning':
        return signalRedLight;
      default:
        return grayBar;
    }
  }

  /// HealthFinding.severity → 진하게 강조한 색 (텍스트/칩용).
  static Color severityDark(String severity) {
    switch (severity) {
      case 'normal':
        return greenDark;
      case 'caution':
        return signalAmberDark;
      case 'warning':
        return signalRedDark;
      default:
        return grayDark;
    }
  }

  /// HealthFinding.severity → 한국어 라벨.
  static String severityLabel(String severity) {
    switch (severity) {
      case 'normal':
        return '정상';
      case 'caution':
        return '주의';
      case 'warning':
        return '이상';
      default:
        return '확인 필요';
    }
  }

  /// HealthArea → HeroCard에 쓰는 짧은 한국어 라벨.
  /// `area.displayName`이 "종합(전체)"으로 길어 HeroCard에선 "종합 진단"으로 축약.
  static String areaHeroLabel(HealthArea area) {
    switch (area) {
      case HealthArea.overall:
        return '종합 진단';
      case HealthArea.eyes:
        return '눈·귀';
      case HealthArea.nose:
        return '코·입';
      case HealthArea.skin:
        return '피부·털';
      case HealthArea.body:
        return '체형(BCS)';
      case HealthArea.posture:
        return '자세·체형';
    }
  }
}
