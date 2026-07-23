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
}
