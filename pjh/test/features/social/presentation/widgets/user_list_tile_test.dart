import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/features/social/presentation/widgets/user_list_tile.dart';

void main() {
  Future<void> pumpTile(
    WidgetTester tester, {
    required VoidCallback onTap,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: UserListTile(
              userId: 'user-1',
              userName: 'Mina',
              subtitle: '@mina',
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uses a stable avatar fallback and exposes username',
      (tester) async {
    var tapped = false;
    await pumpTile(tester, onTap: () => tapped = true);

    expect(find.text('M'), findsOneWidget);
    expect(find.text('@mina'), findsOneWidget);
    expect(
        tester.getSize(find.byType(ListTile)).height, greaterThanOrEqualTo(64));

    await tester.tap(find.byType(ListTile));
    expect(tapped, isTrue);
  });
}
