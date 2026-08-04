import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ══ AppTheme v2 토큰 (2026-07-09, 딥블루+스틸블루 포트폴리오 — 황정훈 확정) ══
  // 원칙: 화면 면적의 ~90% 뉴트럴. 딥블루 도면적 채움 금지. 원빨강 전면 금지.
  static const Color brandDeep =
      Color(0xFF1E3A5F); // 헤딩 텍스트·브랜드 워딩·선택 칩 채움·하단 탭 활성
  static const Color actionBase =
      Color(0xFF2F6399); // 버튼 채움·링크·활성 인디케이터·FAB·스위치 on
  static const Color actionPressed = Color(0xFF244E79); // actionBase 눌림
  static const Color onAction = Color(0xFFFFFFFF);
  static const Color actionDisabled = Color(0xFFD6DEE8);
  static const Color onActionDisabled = Color(0xFF6B7788);
  static const Color actionContainer =
      Color(0xFFE8F0F8); // 액션 연한 배경 (선택 배경·정보 칩 배경)
  static const Color textBody = Color(0xFF283746); // 본문
  static const Color textMuted = Color(0xFF687789); // 보조·시간·카운트
  static const Color border = Color(0xFFE5E8EC); // 카드 보더 1px
  static const Color infoSky = Color(0xFF5BC0EB); // 정보성 상태 뱃지만 (도면적·버튼 금지)

  // 브랜드 컬러 (기존 토큰명 유지 — v2 값/alias)
  static const Color primaryColor = brandDeep;

  /// @deprecated v2에서 actionBase로 통합. 신규 사용 금지.
  static const Color secondaryColor = actionBase;

  /// @deprecated v2에서 actionBase로 통합. 신규 사용 금지.
  static const Color accentColor = actionBase;
  static const Color highlightColor =
      Color(0xFFFF6F61); // 좋아요 하트·오류/부정 표시·알림 뱃지 (CTA 금지)
  /// @deprecated v2에서 infoSky로 개명. 신규 사용 금지.
  static const Color subColor = infoSky;

  // 배경 컬러
  static const Color backgroundColor = Color(0xFFF7F8FA); // 기존 중립 화면 배경
  static const Color surfaceColor = Colors.white; // 카드·시트
  static const Color cardColor = Colors.white;
  static const Color brandPanelSurface = Color(0xFFF7F8FA); // 홈 하단과 같은 MY 정보 패널

  // 다크 모드 정본 토큰 (B0)
  static const Color darkBackground = Color(0xFF0F1724);
  static const Color darkSurface = Color(0xFF182232);
  static const Color darkBorder = Color(0xFF344054);
  static const Color darkText = Color(0xFFF4F7FB);
  static const Color darkSecondaryText = Color(0xFFB8C2CF);
  static const Color darkBrandAccent = Color(0xFFA9C7E8);
  static const Color darkAction = Color(0xFF86B7E7);
  static const Color darkOnAction = Color(0xFF10243A);
  static const Color darkActionPressed = Color(0xFFA5CAED);
  static const Color darkActionDisabled = Color(0xFF344054);
  static const Color darkOnActionDisabled = Color(0xFF8E9AAA);
  static const Color lightFocus = actionBase;
  static const Color darkFocus = darkBrandAccent;
  static const Color lightError = Color(0xFFB42318);
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color lightSuccess = Color(0xFF2E7D32);
  static const Color darkSuccess = Color(0xFFA6D8A8);
  static const Color lightScrim = Color(0x99000000);
  static const Color darkScrim = Color(0xB3000000);

  // 텍스트 컬러
  static const Color primaryTextColor = textBody;
  static const Color secondaryTextColor = textMuted;
  static const Color lightTextColor = Color(0xFFBDBDBD);

  // Neutral 스케일 — Material `Colors.grey[*]`와 동일한 값.
  // 화면 곳곳의 `Colors.grey[N]` 하드코딩을 토큰으로 치환하기 위한 ramp.
  // (값이 동일하므로 치환 시 시각 변화 0. STEP 2)
  static const Color neutral50 = Color(0xFFFAFAFA);
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral200 = Color(0xFFEEEEEE);
  static const Color neutral300 = Color(0xFFE0E0E0);
  static const Color neutral400 = Color(0xFFBDBDBD);
  static const Color neutral500 = Color(0xFF9E9E9E);
  static const Color neutral600 = Color(0xFF757575);
  static const Color neutral700 = Color(0xFF616161);
  static const Color neutral800 = Color(0xFF424242);
  static const Color neutral900 = Color(0xFF212121);

  // 감정별 컬러 (JENA 브랜드 컬러 기반)
  static const Color happinessColor = Color(0xFF5BC0EB); // 하늘색 (기쁨)
  static const Color sadnessColor = Color(0xFF2C4482); // 인디고 (슬픔)
  static const Color anxietyColor = Color(0xFFFF6F61); // 코랄 레드 (불안)
  /// @deprecated Use physiologicalColor. 생리지표용으로 의미 분리됨.
  static const Color sleepinessColor =
      Color(0xFF1E3A5F); // 딥 블루 (졸림 → deprecated)
  static const Color curiosityColor = Color(0xFF0077B6); // 브라이트 블루 (호기심)

  // 신규 감정 컬러 (8종 확장 — JENA 팔레트 기반)
  static const Color physiologicalColor =
      Color(0xFF1E3A5F); // 생리지표 (sleepinessColor 동일값)
  static const Color calmColor = Color(0xFF2E7D6B); // 틸 그린 (편안함)
  static const Color excitementColor = Color(0xFFE8A838); // 따뜻한 앰버 (흥분)
  static const Color fearColor = Color(0xFF6B3FA0); // 딥 퍼플 (공포)
  static const Color discomfortColor = Color(0xFFD4511E); // 딥 오렌지 (불편함)

  // 감정 정렬 순서 상수 (긍정 → 중립 → 부정)
  static const List<String> emotionOrder = [
    'happiness',
    'calm',
    'excitement',
    'curiosity',
    'anxiety',
    'fear',
    'sadness',
    'discomfort',
  ];

  // 감정 컬러 헬퍼 (8종 + 하위 호환)
  static Color getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happiness':
        return happinessColor;
      case 'calm':
        return calmColor;
      case 'excitement':
        return excitementColor;
      case 'curiosity':
        return curiosityColor;
      case 'anxiety':
        return anxietyColor;
      case 'fear':
        return fearColor;
      case 'sadness':
        return sadnessColor;
      case 'discomfort':
        return discomfortColor;
      case 'sleepiness':
        return physiologicalColor; // 하위 호환
      default:
        return primaryColor;
    }
  }

  // 감정 한국어 라벨 헬퍼
  static String getEmotionLabel(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happiness':
        return '기쁨';
      case 'calm':
        return '편안함';
      case 'excitement':
        return '흥분';
      case 'curiosity':
        return '호기심';
      case 'anxiety':
        return '불안';
      case 'fear':
        return '공포';
      case 'sadness':
        return '슬픔';
      case 'discomfort':
        return '불편함';
      case 'sleepiness':
        return '졸림';
      default:
        return emotion;
    }
  }

  // 감정 아이콘 헬퍼 — v2: UI 이모지 제거, 임시 아이콘 체계
  // (감정 일러스트 8종 자산 제작 시 교체 예정)
  static IconData getEmotionIcon(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happiness':
        return Icons.mood;
      case 'calm':
        return Icons.self_improvement;
      case 'excitement':
        return Icons.celebration;
      case 'curiosity':
        return Icons.psychology;
      case 'anxiety':
        return Icons.warning_amber_rounded;
      case 'fear':
        return Icons.warning_amber_outlined;
      case 'sadness':
        return Icons.mood_bad;
      case 'discomfort':
        return Icons.sick_outlined;
      case 'sleepiness':
        return Icons.bedtime; // 하위 호환
      default:
        return Icons.pets;
    }
  }

  // 감정 이모지 헬퍼 — v2: 인앱 UI 사용 금지(외부 공유 카드 전용 잔존)
  static String getEmotionEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happiness':
        return '😊';
      case 'calm':
        return '😌';
      case 'excitement':
        return '🤩';
      case 'curiosity':
        return '🧐';
      case 'anxiety':
        return '😰';
      case 'fear':
        return '😨';
      case 'sadness':
        return '😢';
      case 'discomfort':
        return '😣';
      case 'sleepiness':
        return '😴';
      default:
        return '🐾';
    }
  }

  // 감정 그룹 헬퍼 (UI 그룹핑용)
  static String getEmotionGroup(String emotion) {
    const positive = ['happiness', 'calm', 'excitement'];
    const neutral = ['curiosity'];
    if (positive.contains(emotion)) return 'positive';
    if (neutral.contains(emotion)) return 'neutral';
    return 'negative';
  }

  // 시맨틱 컬러 — 상태/피드백 (v2: 원빨강 금지 → 에러는 highlight 코랄)
  static const Color successColor = lightSuccess; // 성공·완료
  static const Color errorColor = lightError; // 에러·삭제
  static const Color warningColor = Color(0xFFFF9800); // 경고 (주황)
  static const Color infoColor = actionBase; // 정보

  // === Semantic Tokens ===
  static const Color success = lightSuccess;
  static const Color warning = Color(0xFFFF9800);
  static const Color danger = highlightColor;
  static const Color info = actionBase;

  static const Color featureEmotion = Color(0xFFFF6F61);
  static const Color featureHealth = Color(0xFF1E3A5F);
  static const Color featurePlay = Color(0xFF7E57C2);
  static const Color featureFortune = Color(0xFFFFB300);
  static const Color featureQuiz = Color(0xFF0077B6);
  static const Color featureWalk = Color(0xFF26A69A);

  static const Color surfaceWarm = Color(0xFFFFF8E8);
  static const Color surfaceCool = Color(0xFFF8F9FA);

  // 파스텔 타일/뱃지 배경 팔레트 (settings·my 타일 색 승격 — 2026-06-12 확정)
  static const Color tilePastelBlue = Color(0xFFE6F1FB);
  static const Color tilePastelGreen = Color(0xFFEAF3DE);
  static const Color tilePastelPeach = Color(0xFFFAECE7);
  static const Color tilePastelSand = Color(0xFFF1EFE8);
  static const Color tilePastelPink = Color(0xFFFBEAF0);
  static const Color tilePastelRose = Color(0xFFFCEBEB);
  static const Color tilePastelMint = Color(0xFFE1F5EE);
  static const Color tilePastelLavender = Color(0xFFEEEDFE);
  static const Color tilePastelPurple = Color(0xFFE9E3F5);

  // 중간 회색 계열 토큰 (v2: divider는 구분선 전용, 보더는 border 토큰)
  static const Color dividerColor = Color(0xFFF1F3F6);
  static const Color disabledColor = Color(0xFFBDBDBD);
  static const Color hintColor = Color(0xFF9E9E9E);
  static const Color subtleBackground = Color(0xFFF7F8FA);

  // 간격
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  // 라운딩 — v2 3단: 20(대형 카드) / 14(일반 카드·버튼) / 8(칩·입력)
  static const double radiusSm = 8;
  static const double radiusMd = 14;
  static const double radiusLg = 14;
  static const double radiusXl = 20;

  // 타이포 스케일 — v2 4단 + 캡션 (w600은 fontTitle·fontHeading만, 본문 bold 금지)
  static const double fontTitle = 22;
  static const double fontHeading = 17;
  static const double fontBody = 15;
  static const double fontCaption = 13;
  static const double fontMicro = 11;

  // 카드 데코레이션 — v2: elevation 절제, 보더 + 미세 단일 그림자(alpha ≤6%)
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: border, width: 1),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      );

  // 그라데이션
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, actionBase],
  );

  // 그림자 — v2: alpha ≤6% 단일 그림자
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Pretendard',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: actionBase,
        onPrimary: onAction,
        surface: surfaceColor,
        onSurface: primaryTextColor,
        outline: border,
        error: lightError,
        onError: Colors.white,
      ).copyWith(
        scrim: lightScrim,
      ),
      primaryColor: primaryColor,
      focusColor: lightFocus,
      scaffoldBackgroundColor: backgroundColor,

      // AppBar 테마
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: primaryTextColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontSize: fontHeading,
          fontWeight: FontWeight.w600,
          color: brandDeep,
        ),
      ),

      // Card 테마
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),

      // Elevated Button 테마 — v2: 버튼 채움 actionBase, elevation 절제
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: onAction,
          disabledForegroundColor: onActionDisabled,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: fontBody,
            fontWeight: FontWeight.w500,
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return actionDisabled;
            if (states.contains(WidgetState.pressed)) return actionPressed;
            return actionBase;
          }),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: onAction,
          disabledForegroundColor: onActionDisabled,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: fontBody,
            fontWeight: FontWeight.w600,
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return actionDisabled;
            if (states.contains(WidgetState.pressed)) return actionPressed;
            return actionBase;
          }),
        ),
      ),

      // Text Button 테마 — v2: 링크 actionBase
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: actionBase,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: actionBase,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: fontBody,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input Decoration 테마 — v2: 입력 radius 8, 보더 border 토큰
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: lightFocus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: highlightColor),
        ),
        labelStyle: const TextStyle(color: secondaryTextColor),
        hintStyle: const TextStyle(color: textMuted),
      ),

      // Bottom Navigation Bar 테마
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: lightTextColor,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Text 테마 — v2 스케일 4단: 22(타이틀)/17(헤딩)/15(본문)/13(보조) + 11(캡션)
      // w600은 22·17만, 본문 bold 금지.
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: fontTitle,
          fontWeight: FontWeight.w600,
          color: brandDeep,
        ),
        headlineMedium: TextStyle(
          fontSize: fontTitle,
          fontWeight: FontWeight.w600,
          color: brandDeep,
        ),
        headlineSmall: TextStyle(
          fontSize: fontHeading,
          fontWeight: FontWeight.w600,
          color: brandDeep,
        ),
        titleLarge: TextStyle(
          fontSize: fontHeading,
          fontWeight: FontWeight.w600,
          color: brandDeep,
        ),
        titleMedium: TextStyle(
          fontSize: fontBody,
          fontWeight: FontWeight.w500,
          color: primaryTextColor,
        ),
        titleSmall: TextStyle(
          fontSize: fontCaption,
          fontWeight: FontWeight.w500,
          color: primaryTextColor,
        ),
        bodyLarge: TextStyle(
          fontSize: fontBody,
          fontWeight: FontWeight.normal,
          color: primaryTextColor,
        ),
        bodyMedium: TextStyle(
          fontSize: fontBody,
          fontWeight: FontWeight.normal,
          color: primaryTextColor,
        ),
        bodySmall: TextStyle(
          fontSize: fontCaption,
          fontWeight: FontWeight.normal,
          color: secondaryTextColor,
        ),
        labelSmall: TextStyle(
          fontSize: fontMicro,
          fontWeight: FontWeight.normal,
          color: secondaryTextColor,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Pretendard',
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkAction,
        brightness: Brightness.dark,
        surface: darkSurface,
        primary: darkAction,
        onPrimary: darkOnAction,
        secondary: darkBrandAccent,
        onSurface: darkText,
        outline: darkBorder,
        error: darkError,
        onError: darkOnAction,
      ).copyWith(
        surfaceContainerHighest: darkSurface,
        onSurfaceVariant: darkSecondaryText,
        outlineVariant: darkBorder,
        scrim: darkScrim,
      ),
      primaryColor: darkBrandAccent,
      focusColor: darkFocus,
      scaffoldBackgroundColor: darkBackground,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: darkSurface,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: darkSurface,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: darkText,
          fontFamily: 'Pretendard',
        ),
        iconTheme: IconThemeData(color: darkText),
      ),

      // Card
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shadowColor: Colors.black54,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder),
        ),
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: darkBrandAccent,
        unselectedItemColor: darkSecondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // TabBar
      tabBarTheme: const TabBarThemeData(
        labelColor: darkBrandAccent,
        unselectedLabelColor: darkSecondaryText,
        indicatorColor: darkBrandAccent,
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: darkOnAction,
          disabledForegroundColor: darkOnActionDisabled,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Pretendard',
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return darkActionDisabled;
            }
            if (states.contains(WidgetState.pressed)) {
              return darkActionPressed;
            }
            return darkAction;
          }),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: darkOnAction,
          disabledForegroundColor: darkOnActionDisabled,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: fontBody,
            fontWeight: FontWeight.w600,
            fontFamily: 'Pretendard',
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return darkActionDisabled;
            }
            if (states.contains(WidgetState.pressed)) {
              return darkActionPressed;
            }
            return darkAction;
          }),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkAction,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Pretendard',
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkAction,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: darkBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkAction,
        foregroundColor: darkOnAction,
      ),

      // InputDecoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        hintStyle: const TextStyle(color: darkSecondaryText),
        labelStyle: const TextStyle(color: darkSecondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkFocus, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: darkSurface,
        selectedColor: darkAction,
        labelStyle: const TextStyle(color: darkText, fontFamily: 'Pretendard'),
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // Icon
      iconTheme: const IconThemeData(color: darkText),

      // Text
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: darkText, fontFamily: 'Pretendard'),
        displayMedium: TextStyle(color: darkText, fontFamily: 'Pretendard'),
        headlineLarge: TextStyle(color: darkText, fontFamily: 'Pretendard'),
        headlineMedium: TextStyle(color: darkText, fontFamily: 'Pretendard'),
        headlineSmall: TextStyle(color: darkText, fontFamily: 'Pretendard'),
        titleLarge: TextStyle(color: darkText, fontFamily: 'Pretendard'),
        titleMedium: TextStyle(color: darkText, fontFamily: 'Pretendard'),
        titleSmall: TextStyle(color: darkText, fontFamily: 'Pretendard'),
        bodyLarge: TextStyle(color: darkText, fontFamily: 'Pretendard'),
        bodyMedium: TextStyle(color: darkText, fontFamily: 'Pretendard'),
        bodySmall:
            TextStyle(color: darkSecondaryText, fontFamily: 'Pretendard'),
        labelMedium: TextStyle(color: darkText, fontFamily: 'Pretendard'),
        labelSmall:
            TextStyle(color: darkSecondaryText, fontFamily: 'Pretendard'),
        labelLarge: TextStyle(
            color: darkText,
            fontWeight: FontWeight.w600,
            fontFamily: 'Pretendard'),
      ),

      // SnackBar
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: darkSurface,
        contentTextStyle: TextStyle(color: darkText, fontFamily: 'Pretendard'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      // Dialog
      dialogTheme: const DialogThemeData(
        backgroundColor: darkSurface,
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Pretendard',
        ),
        contentTextStyle: TextStyle(
          color: darkSecondaryText,
          fontSize: 14,
          fontFamily: 'Pretendard',
        ),
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: darkText,
        iconColor: darkSecondaryText,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? darkAction
              : darkSecondaryText,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? darkAction.withValues(alpha: 0.4)
              : darkBorder,
        ),
      ),
    );
  }
}
