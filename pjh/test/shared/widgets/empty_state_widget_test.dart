import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/shared/themes/app_theme.dart';
import 'package:meong_nyang_diary/shared/widgets/empty_state_widget.dart';

void main() {
  testWidgets('빈 상태는 장식 아이콘 없이 제목·설명·주요 행동만 표시한다', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.grid_on_outlined,
              title: '아직 게시글이 없어요',
              subtitle: '첫 게시글을 작성해보세요.',
              actionLabel: '게시글 작성',
              onAction: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.grid_on_outlined), findsNothing);
    expect(find.text('아직 게시글이 없어요'), findsOneWidget);
    expect(find.text('첫 게시글을 작성해보세요.'), findsOneWidget);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '게시글 작성'),
    );
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppTheme.actionBase,
    );
    expect(
      button.style?.foregroundColor?.resolve(<WidgetState>{}),
      Colors.white,
    );
  });
}
