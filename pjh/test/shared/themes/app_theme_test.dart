import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/shared/themes/app_theme.dart';

void main() {
  test('라이트 테마는 기존 중립 캔버스와 식별 가능한 카드·버튼 경계를 사용한다', () {
    final theme = AppTheme.lightTheme;
    final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
    final outlinedStyle = theme.outlinedButtonTheme.style!;
    final elevatedStyle = theme.elevatedButtonTheme.style!;

    expect(AppTheme.backgroundColor, const Color(0xFFF7F8FA));
    expect(theme.scaffoldBackgroundColor, AppTheme.backgroundColor);
    expect(cardShape.side.color, AppTheme.border);
    expect(
      outlinedStyle.side!.resolve(<WidgetState>{})!.color,
      AppTheme.border,
    );
    expect(
      outlinedStyle.minimumSize!.resolve(<WidgetState>{}),
      const Size(0, 48),
    );
    expect(
      elevatedStyle.minimumSize!.resolve(<WidgetState>{}),
      const Size(0, 48),
    );
  });

  test('B0 라이트·다크 토큰은 승인된 정본 값과 같다', () {
    expect(AppTheme.actionBase, const Color(0xFF2F6399));
    expect(AppTheme.actionPressed, const Color(0xFF244E79));
    expect(AppTheme.onAction, Colors.white);
    expect(AppTheme.actionDisabled, const Color(0xFFD6DEE8));
    expect(AppTheme.onActionDisabled, const Color(0xFF6B7788));
    expect(AppTheme.border, const Color(0xFFE5E8EC));

    expect(AppTheme.darkBackground, const Color(0xFF0F1724));
    expect(AppTheme.darkSurface, const Color(0xFF182232));
    expect(AppTheme.darkBorder, const Color(0xFF344054));
    expect(AppTheme.darkText, const Color(0xFFF4F7FB));
    expect(AppTheme.darkSecondaryText, const Color(0xFFB8C2CF));
    expect(AppTheme.darkBrandAccent, const Color(0xFFA9C7E8));
    expect(AppTheme.darkAction, const Color(0xFF86B7E7));
    expect(AppTheme.darkOnAction, const Color(0xFF10243A));
    expect(AppTheme.darkActionPressed, const Color(0xFFA5CAED));
    expect(AppTheme.darkActionDisabled, const Color(0xFF344054));
    expect(AppTheme.darkOnActionDisabled, const Color(0xFF8E9AAA));
  });

  test('CTA·본문·포커스 토큰은 정본 대비 임계값을 충족한다', () {
    double contrast(Color foreground, Color background) {
      final high = foreground.computeLuminance() > background.computeLuminance()
          ? foreground.computeLuminance()
          : background.computeLuminance();
      final low = foreground.computeLuminance() > background.computeLuminance()
          ? background.computeLuminance()
          : foreground.computeLuminance();
      return (high + 0.05) / (low + 0.05);
    }

    expect(contrast(AppTheme.onAction, AppTheme.actionBase), greaterThan(6.2));
    expect(
      contrast(AppTheme.primaryTextColor, AppTheme.surfaceColor),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(AppTheme.lightFocus, AppTheme.surfaceColor),
      greaterThanOrEqualTo(3),
    );
    expect(
      contrast(AppTheme.darkText, AppTheme.darkSurface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(AppTheme.darkSecondaryText, AppTheme.darkSurface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(AppTheme.darkOnAction, AppTheme.darkAction),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(AppTheme.darkFocus, AppTheme.darkBackground),
      greaterThanOrEqualTo(3),
    );
  });

  test('버튼 pressed·disabled 상태가 라이트와 다크 토큰을 사용한다', () {
    final lightStyle = AppTheme.lightTheme.filledButtonTheme.style!;
    final darkStyle = AppTheme.darkTheme.filledButtonTheme.style!;

    expect(
      lightStyle.backgroundColor!.resolve({WidgetState.pressed}),
      AppTheme.actionPressed,
    );
    expect(
      lightStyle.backgroundColor!.resolve({WidgetState.disabled}),
      AppTheme.actionDisabled,
    );
    expect(
      lightStyle.foregroundColor!.resolve({WidgetState.disabled}),
      AppTheme.onActionDisabled,
    );
    expect(
      darkStyle.backgroundColor!.resolve({WidgetState.pressed}),
      AppTheme.darkActionPressed,
    );
    expect(
      darkStyle.backgroundColor!.resolve({WidgetState.disabled}),
      AppTheme.darkActionDisabled,
    );
    expect(
      darkStyle.foregroundColor!.resolve({WidgetState.disabled}),
      AppTheme.darkOnActionDisabled,
    );
  });
}
