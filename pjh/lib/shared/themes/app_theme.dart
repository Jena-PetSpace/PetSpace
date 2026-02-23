import 'package:flutter/material.dart';

class AppTheme {
  // JENA 브랜드 컬러 팔레트
  static const Color primaryColor = Color(0xFF1E3A5F); // Primary Deep Blue - 신뢰와 전문성
  static const Color secondaryColor = Color(0xFF2C4482); // JENA Signature Indigo - 리더십과 혁신
  static const Color accentColor = Color(0xFF0077B6); // Accent Bright Blue - 미래지향적 기술
  static const Color highlightColor = Color(0xFFFF6F61); // Highlight Coral Red - 고객 중심적 사고
  static const Color subColor = Color(0xFF5BC0EB); // Sub Sky Blue - 투명한 네트워크

  // 배경 컬러
  static const Color backgroundColor = Color(0xFFF8F9FA); // 연한 회색 배경
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;

  // 텍스트 컬러
  static const Color primaryTextColor = Color(0xFF2D2D2D);
  static const Color secondaryTextColor = Color(0xFF757575);
  static const Color lightTextColor = Color(0xFFBDBDBD);

  // 감정별 컬러 (JENA 브랜드 컬러 기반)
  static const Color happinessColor = Color(0xFF5BC0EB); // 하늘색 (기쁨)
  static const Color sadnessColor = Color(0xFF2C4482); // 인디고 (슬픔)
  static const Color anxietyColor = Color(0xFFFF6F61); // 코랄 레드 (불안)
  static const Color sleepinessColor = Color(0xFF1E3A5F); // 딥 블루 (졸림)
  static const Color curiosityColor = Color(0xFF0077B6); // 브라이트 블루 (호기심)

  // 그림자
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        surface: surfaceColor,
      ),
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,

      // AppBar 테마
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: primaryTextColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
      ),

      // Card 테마
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Elevated Button 테마
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text Button 테마
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input Decoration 테마
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        labelStyle: const TextStyle(color: secondaryTextColor),
        hintStyle: const TextStyle(color: lightTextColor),
      ),

      // Bottom Navigation Bar 테마
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: lightTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Text 테마
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: primaryTextColor,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: primaryTextColor,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: primaryTextColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: primaryTextColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: primaryTextColor,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: secondaryTextColor,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ),
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFF121212),
      fontFamily: 'Pretendard',
    );
  }

  // 감정별 컬러를 가져오는 헬퍼 메서드
  static Color getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happiness':
        return happinessColor;
      case 'sadness':
        return sadnessColor;
      case 'anxiety':
        return anxietyColor;
      case 'sleepiness':
        return sleepinessColor;
      case 'curiosity':
        return curiosityColor;
      default:
        return primaryColor;
    }
  }
}